const Payment = require('./payment.model');

async function listAdminPayments({ status, workerId, customerId, from, to, minAmount, maxAmount, page = 1, limit = 20 }) {
  const q = {};
  if (status && status !== 'all') q.status = status;
  if (customerId) q.user = customerId;
  if (workerId) q.worker = workerId;
  if (from || to) q.createdAt = {};
  if (from) q.createdAt.$gte = new Date(from);
  if (to)   q.createdAt.$lte = new Date(to);
  if (minAmount || maxAmount) q.amount = {};
  if (minAmount) q.amount.$gte = Number(minAmount);
  if (maxAmount) q.amount.$lte = Number(maxAmount);

  const _limit = Math.min(Number(limit) || 20, 100);
  const _page  = Math.max(Number(page) || 1, 1);

  const [items, total] = await Promise.all([
    Payment.find(q)
      .populate({ path: 'booking', populate: [
        { path: 'user', select: 'name email' },
        { path: 'worker', select: 'name email' },
        { path: 'service', select: 'title' },
      ] })
      .sort({ createdAt: -1 })
      .skip((_page - 1) * _limit)
      .limit(_limit),
    Payment.countDocuments(q),
  ]);
  return { items, page: _page, limit: _limit, total };
}

async function statsAdmin() {
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const [heldAgg, releasedTodayAgg, pendingReview, disputed, refundsToday, avgRelease] = await Promise.all([
    Payment.aggregate([{ $match: { status: 'held' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]),
    Payment.aggregate([{ $match: { status: 'released', releasedAt: { $gte: today } } }, { $group: { _id: null, total: { $sum: '$amount' } } }]),
    Payment.countDocuments({ status: 'held' }),
    Payment.countDocuments({ status: 'disputed' }),
    Payment.countDocuments({ status: { $in: ['refunded', 'partially_refunded'] }, refundedAt: { $gte: today } }),
    Payment.aggregate([
      { $match: { status: 'released', releasedAt: { $exists: true }, heldAt: { $exists: true } } },
      { $project: { hours: { $divide: [{ $subtract: ['$releasedAt', '$heldAt'] }, 3600 * 1000] } } },
      { $group: { _id: null, avg: { $avg: '$hours' } } },
    ]),
  ]);
  return {
    heldTotal:          heldAgg[0]?.total || 0,
    releasedTodayTotal: releasedTodayAgg[0]?.total || 0,
    pendingReviewCount: pendingReview,
    disputedCount:      disputed,
    refundsTodayCount:  refundsToday,
    avgReleaseHours:    Math.round((avgRelease[0]?.avg || 0) * 10) / 10,
  };
}

module.exports = { listAdminPayments, statsAdmin };
