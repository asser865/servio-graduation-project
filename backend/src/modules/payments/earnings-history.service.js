const { StatusCodes } = require('http-status-codes');
const ApiError = require('../../utils/ApiError');
const CashDebt = require('./cash-debt.model');
const Payment = require('./payment.model');
const PayoutRequest = require('./payout-request.model');

const CATEGORIES = new Set(['withdrawals', 'releases', 'fees']);
const STATUS_BY_CATEGORY = {
  withdrawals: new Set(['pending', 'approved', 'paid', 'rejected']),
  releases: new Set(['waiting_for_release', 'released', 'needs_review']),
  fees: new Set(['paid']),
};

function parsePositiveInteger(value, fallback, max) {
  const number = Number(value ?? fallback);
  if (!Number.isInteger(number) || number < 1 || number > max) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Expected an integer between 1 and ${max}.`);
  }
  return number;
}

function parseDate(value, field, endOfDay = false) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `${field} must be a valid date.`);
  }
  if (endOfDay && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
    date.setUTCHours(23, 59, 59, 999);
  }
  return date;
}

function buildDateRange(from, to) {
  const start = parseDate(from, 'from');
  const end = parseDate(to, 'to', true);
  if (start && end && start > end) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'from must be before to.');
  }
  if (!start && !end) return null;
  return {
    ...(start ? { $gte: start } : {}),
    ...(end ? { $lte: end } : {}),
  };
}

function bookingLabel(booking) {
  return booking?.serviceName || booking?.serviceCategory || 'Service job';
}

function normalizeWithdrawal(item) {
  return {
    id: item._id,
    amount: item.amount,
    method: item.payoutMethod,
    status: item.status,
    requestedAt: item.requestedAt || item.createdAt,
    processedAt: item.processedAt,
    receipt: item.transactionRef || null,
  };
}

function normalizeRelease(item) {
  const displayStatus = item.status === 'released'
    ? 'released'
    : item.status === 'disputed'
      ? 'needs_review'
      : 'waiting_for_release';

  return {
    id: item._id,
    bookingId: item.booking?._id || item.booking,
    job: bookingLabel(item.booking),
    amount: item.workerEarning,
    status: displayStatus,
    waitingSince: item.heldAt || item.createdAt,
    releasedAt: item.releasedAt || null,
  };
}

function normalizeFee(item) {
  return {
    id: item._id,
    bookingId: item.booking?._id || item.booking,
    job: bookingLabel(item.booking),
    amount: item.paidAmount || item.amount,
    method: item.settlementMethod || item.paidBy || 'recorded_payment',
    status: 'paid',
    paidAt: item.paidAt || item.updatedAt,
  };
}

async function listWorkerHistory(workerId, params = {}) {
  const category = params.category || 'withdrawals';
  if (!CATEGORIES.has(category)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'category must be withdrawals, releases, or fees.');
  }

  const page = parsePositiveInteger(params.page, 1, 100000);
  const limit = parsePositiveInteger(params.limit, 10, 50);
  const dateRange = buildDateRange(params.from, params.to);
  const status = params.status || '';

  if (status && !STATUS_BY_CATEGORY[category].has(status)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Unsupported ${category} status.`);
  }

  const skip = (page - 1) * limit;
  let query;
  let sort;
  let normalize;
  let Model;

  if (category === 'withdrawals') {
    Model = PayoutRequest;
    query = {
      worker: workerId,
      ...(status ? { status } : {}),
      ...(dateRange ? { requestedAt: dateRange } : {}),
    };
    sort = { requestedAt: -1, createdAt: -1 };
    normalize = normalizeWithdrawal;
  } else if (category === 'releases') {
    Model = Payment;
    const releaseStatus = {
      waiting_for_release: 'held',
      released: 'released',
      needs_review: 'disputed',
    }[status];
    query = {
      worker: workerId,
      status: releaseStatus || { $in: ['held', 'released', 'disputed'] },
      ...(dateRange ? { createdAt: dateRange } : {}),
    };
    sort = { createdAt: -1 };
    normalize = normalizeRelease;
  } else {
    Model = CashDebt;
    query = {
      worker: workerId,
      status: 'paid',
      ...(dateRange ? { paidAt: dateRange } : {}),
    };
    sort = { paidAt: -1, updatedAt: -1 };
    normalize = normalizeFee;
  }

  let itemsQuery = Model.find(query).sort(sort).skip(skip).limit(limit);
  if (category === 'releases' || category === 'fees') {
    itemsQuery = itemsQuery.populate('booking', 'serviceName serviceCategory');
  }

  const [items, total] = await Promise.all([
    itemsQuery.lean(),
    Model.countDocuments(query),
  ]);

  return {
    category,
    items: items.map(normalize),
    meta: { page, limit, total },
  };
}

module.exports = { listWorkerHistory };
