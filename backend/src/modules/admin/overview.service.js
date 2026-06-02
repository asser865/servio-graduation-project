const User = require('../users/user.model');
const Booking = require('../bookings/booking.model');
const Payment = require('../payments/payment.model');
const Dispute = require('../payments/dispute.model');
const AuditLog = require('./audit.model');

const ACTIVE_DISPUTE_STATUSES = ['open', 'reviewing', 'awaiting_evidence', 'escalated'];
const IN_PROGRESS_BOOKING_STATUSES = [
  'accepted',
  'en_route',
  'arrived',
  'in_progress',
  'awaiting_customer_confirmation',
  'pending_admin_review',
];
const SCHEDULED_BOOKING_STATUSES = ['pending', 're_pooling'];
const CANCELLED_BOOKING_STATUSES = [
  'cancelled',
  'rejected',
  'cancelled_no_show',
  'customer_no_show',
  'worker_no_show',
];

function startOfDay(value) {
  const date = new Date(value);
  date.setHours(0, 0, 0, 0);
  return date;
}

function addDays(value, amount) {
  const date = new Date(value);
  date.setDate(date.getDate() + amount);
  return date;
}

function dayKey(value) {
  const date = new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function sum(values) {
  return values.reduce((total, value) => total + (Number(value) || 0), 0);
}

function countStatuses(statuses, allowed) {
  return allowed.reduce((total, status) => total + (statuses[status] || 0), 0);
}

function initials(name) {
  return String(name || '')
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join('')
    .toUpperCase();
}

function shortId(id) {
  const value = String(id || '');
  return value ? `#S-${value.slice(-4).toUpperCase()}` : '';
}

function paymentDate(payment) {
  return payment.releasedAt || payment.createdAt;
}

function buildRevenueSeries(payments, today) {
  const currentStart = addDays(today, -6);
  const previousStart = addDays(today, -13);
  const dailyTotals = new Map();

  payments.forEach((payment) => {
    const key = dayKey(paymentDate(payment));
    dailyTotals.set(key, (dailyTotals.get(key) || 0) + (Number(payment.platformFee) || 0));
  });

  const dailyRevenue = Array.from({ length: 7 }, (_, index) => {
    const date = addDays(currentStart, index);
    const key = dayKey(date);
    return { date: key, revenue: dailyTotals.get(key) || 0 };
  });
  const previousWeekRevenue = Array.from({ length: 7 }, (_, index) => {
    const date = addDays(previousStart, index);
    return dailyTotals.get(dayKey(date)) || 0;
  });
  const currentTotal = sum(dailyRevenue.map((entry) => entry.revenue));
  const previousTotal = sum(previousWeekRevenue);

  return {
    dailyRevenue,
    currentWeekRevenue: currentTotal,
    previousWeekRevenue: previousTotal,
    comparisonPercent: previousTotal > 0
      ? Math.round(((currentTotal - previousTotal) / previousTotal) * 1000) / 10
      : null,
  };
}

function buildBookingStats(groupedStatuses, newLast24Hours) {
  const statuses = groupedStatuses.reduce((acc, item) => {
    acc[item._id] = item.count;
    return acc;
  }, {});
  const completed = statuses.completed || 0;
  const inProgress = countStatuses(statuses, IN_PROGRESS_BOOKING_STATUSES);
  const scheduled = countStatuses(statuses, SCHEDULED_BOOKING_STATUSES);
  const cancelled = countStatuses(statuses, CANCELLED_BOOKING_STATUSES);
  const disputed = statuses.disputed || 0;
  const total = sum(Object.values(statuses));
  const resolved = completed + cancelled + disputed;

  return {
    total,
    newLast24Hours,
    successRate: resolved > 0 ? Math.round((completed / resolved) * 1000) / 10 : 0,
    buckets: { completed, inProgress, scheduled, cancelled, disputed },
  };
}

async function buildTopTechnicians(monthStart) {
  const monthlyStats = await Booking.aggregate([
    { $match: { status: 'completed', completedAt: { $gte: monthStart } } },
    {
      $group: {
        _id: '$worker',
        jobs: { $sum: 1 },
        revenue: { $sum: { $ifNull: ['$totalPrice', 0] } },
      },
    },
    { $sort: { jobs: -1, revenue: -1 } },
    { $limit: 5 },
  ]);
  if (!monthlyStats.length) return [];

  const workers = await User.find({
    _id: { $in: monthlyStats.map((item) => item._id) },
    role: 'worker',
  }).select('name averageRating skills categories');
  const workerById = new Map(workers.map((worker) => [String(worker._id), worker]));

  return monthlyStats
    .map((stats) => {
      const worker = workerById.get(String(stats._id));
      if (!worker) return null;
      return {
        id: worker._id,
        name: worker.name,
        initials: initials(worker.name),
        specialty: worker.skills?.[0] || worker.categories?.[0] || 'General',
        rating: Number(worker.averageRating) || 0,
        jobs: stats.jobs,
        revenue: stats.revenue,
      };
    })
    .filter(Boolean);
}

function buildRecentActivity({ customers, workers, bookings, disputes, auditLogs }) {
  const activities = [];

  customers.forEach((user) => {
    activities.push({
      type: 'customer',
      text: 'New customer signup',
      subject: user.name || user.email,
      at: user.createdAt,
      targetTab: 'users',
    });
  });
  workers.forEach((worker) => {
    activities.push({
      type: 'technician',
      text: worker.isVerified ? 'Technician joined' : 'Technician pending review',
      subject: worker.name || worker.email,
      at: worker.createdAt,
      targetTab: 'technicians',
    });
  });
  bookings.forEach((booking) => {
    const workerName = booking.worker?.name || 'Unassigned technician';
    activities.push({
      type: booking.status === 'completed' ? 'booking_completed' : 'booking',
      text: booking.status === 'completed' ? 'Booking completed' : 'Booking created',
      subject: `${shortId(booking._id)} by ${workerName}`,
      at: booking.status === 'completed' ? (booking.completedAt || booking.updatedAt) : booking.createdAt,
      targetTab: 'bookings',
    });
  });
  disputes.forEach((dispute) => {
    activities.push({
      type: 'dispute',
      text: 'New dispute opened',
      subject: shortId(dispute.booking?._id || dispute.booking),
      at: dispute.createdAt,
      targetTab: 'disputes',
    });
  });
  auditLogs.forEach((log) => {
    activities.push({
      type: 'admin',
      text: log.action,
      subject: log.target || log.actor?.email || '',
      at: log.createdAt,
      targetTab: log.type === 'finance' ? 'finance' : 'audit',
    });
  });

  return activities
    .filter((activity) => activity.at)
    .sort((left, right) => new Date(right.at) - new Date(left.at))
    .slice(0, 7);
}

async function getOverview() {
  const now = new Date();
  const today = startOfDay(now);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const last24Hours = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const revenueQueryStart = new Date(Math.min(monthStart.getTime(), addDays(today, -13).getTime()));

  const [
    totalUsers,
    totalTechnicians,
    openDisputes,
    groupedBookingStatuses,
    newBookingsLast24Hours,
    releasedPayments,
    recentCustomers,
    recentWorkers,
    recentBookings,
    recentDisputes,
    auditLogs,
    topTechnicians,
  ] = await Promise.all([
    User.countDocuments({ role: 'user' }),
    User.countDocuments({ role: 'worker' }),
    Dispute.countDocuments({ status: { $in: ACTIVE_DISPUTE_STATUSES } }),
    Booking.aggregate([{ $group: { _id: '$status', count: { $sum: 1 } } }]),
    Booking.countDocuments({ createdAt: { $gte: last24Hours } }),
    Payment.find({
      status: 'released',
      $or: [
        { releasedAt: { $gte: revenueQueryStart } },
        { createdAt: { $gte: revenueQueryStart } },
      ],
    }).select('platformFee releasedAt createdAt'),
    User.find({ role: 'user' }).select('name email createdAt').sort({ createdAt: -1 }).limit(3),
    User.find({ role: 'worker' }).select('name email isVerified createdAt').sort({ createdAt: -1 }).limit(3),
    Booking.find({})
      .select('status worker createdAt updatedAt completedAt')
      .populate('worker', 'name')
      .sort({ createdAt: -1 })
      .limit(4),
    Dispute.find({}).select('booking createdAt').sort({ createdAt: -1 }).limit(3),
    AuditLog.find({}).select('action target type actor createdAt').sort({ createdAt: -1 }).limit(4),
    buildTopTechnicians(monthStart),
  ]);

  const revenue = buildRevenueSeries(releasedPayments, today);
  const revenueThisMonth = sum(
    releasedPayments
      .filter((payment) => paymentDate(payment) >= monthStart)
      .map((payment) => payment.platformFee)
  );

  return {
    generatedAt: now,
    kpis: { totalUsers, totalTechnicians, revenueThisMonth, openDisputes },
    revenue: {
      daily: revenue.dailyRevenue,
      currentWeek: revenue.currentWeekRevenue,
      previousWeek: revenue.previousWeekRevenue,
      comparisonPercent: revenue.comparisonPercent,
    },
    bookings: buildBookingStats(groupedBookingStatuses, newBookingsLast24Hours),
    recentActivity: buildRecentActivity({
      customers: recentCustomers,
      workers: recentWorkers,
      bookings: recentBookings,
      disputes: recentDisputes,
      auditLogs,
    }),
    topTechnicians,
  };
}

async function getRevenueHistory(days) {
  const n = Math.min(Math.max(parseInt(days, 10) || 7, 1), 365);
  const now = new Date();
  const today = startOfDay(now);
  const rangeStart = addDays(today, -(n - 1));
  const prevStart = addDays(today, -(n * 2 - 1));

  const payments = await Payment.find({
    status: 'released',
    $or: [
      { releasedAt: { $gte: prevStart } },
      { createdAt: { $gte: prevStart } },
    ],
  }).select('platformFee releasedAt createdAt');

  const dailyTotals = new Map();
  payments.forEach((payment) => {
    const key = dayKey(paymentDate(payment));
    dailyTotals.set(key, (dailyTotals.get(key) || 0) + (Number(payment.platformFee) || 0));
  });

  const daily = Array.from({ length: n }, (_, i) => {
    const date = addDays(rangeStart, i);
    const key = dayKey(date);
    return { date: key, revenue: dailyTotals.get(key) || 0 };
  });

  const prevDaily = Array.from({ length: n }, (_, i) => {
    const date = addDays(prevStart, i);
    return dailyTotals.get(dayKey(date)) || 0;
  });

  const currentTotal = sum(daily.map((e) => e.revenue));
  const previousTotal = sum(prevDaily);

  return {
    days: n,
    daily,
    currentTotal,
    previousTotal,
    comparisonPercent: previousTotal > 0
      ? Math.round(((currentTotal - previousTotal) / previousTotal) * 1000) / 10
      : null,
  };
}

module.exports = { getOverview, buildBookingStats, buildRevenueSeries, getRevenueHistory };
