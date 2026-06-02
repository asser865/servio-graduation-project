const { StatusCodes } = require('http-status-codes');
const paymentService  = require('./payment.service');
const cashDebtService = require('./cash-debt.service');
const disputeService  = require('./dispute.service');
const ApiResponse     = require('../../utils/ApiResponse');
const ApiError        = require('../../utils/ApiError');
const { logEvent }    = require('../admin/audit.service');
const { money: r2 }   = require('../../utils/rounding');

const holdPayment = async (req, res) => {
  const { bookingId } = req.params;
  const { savedCardId, useCredit } = req.body;
  const payment = await paymentService.holdPayment(bookingId, req.user.id, { savedCardId, useCredit: !!useCredit });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment held in escrow.', payment);
};

const confirmCompletion = async (req, res) => {
  const { bookingId } = req.params;
  const booking = await paymentService.requestReleaseByCustomer(bookingId, req.user.id);
  const message = booking.paymentMethod === 'cash' && booking.status === 'completed'
    ? 'Completion confirmed. Cash platform fee recorded for settlement.'
    : 'Completion confirmed. Pending admin review.';
  return ApiResponse.success(res, StatusCodes.OK, message, booking);
};

const adminApproveCompletion = async (req, res) => {
  const { bookingId } = req.params;
  const result = await paymentService.adminApproveCompletion(bookingId, req.user.id, {
    reasonCode: req.body?.reasonCode,
    note: req.body?.note,
  });
  logEvent({ req, type: 'finance', action: 'Admin approved payment release', target: bookingId });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking approved and payment processed.', result);
};

const adminRejectCash = async (req, res) => {
  const { bookingId } = req.params;
  const { reason } = req.body;
  if (!reason) throw new ApiError(StatusCodes.BAD_REQUEST, 'Rejection reason is required.');
  const result = await paymentService.adminRejectCash(bookingId, req.user.id, reason);
  logEvent({ req, type: 'finance', action: 'Admin rejected cash booking', target: bookingId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.OK, 'Cash booking rejected.', result);
};

const getPendingApprovals = async (req, res) => {
  const result = await paymentService.getPendingApprovals(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Pending approvals retrieved.', result);
};

const getCashDebts = async (req, res) => {
  const result = await cashDebtService.getAdminDebts(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Cash debts retrieved.', result);
};

const markCashDebtPaid = async (req, res) => {
  const { id } = req.params;
  const { amount, adminNote } = req.body;
  if (!amount) throw new ApiError(StatusCodes.BAD_REQUEST, 'amount is required.');
  const result = await cashDebtService.markCashDebtManuallyPaid(id, req.user.id, { amount: Number(amount), adminNote });
  logEvent({ req, type: 'finance', action: 'Admin marked cash debt paid', target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Cash debt payment recorded.', result);
};

const getMyDebts = async (req, res) => {
  const result = await cashDebtService.getWorkerDebts(req.user.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Your cash debts retrieved.', result);
};

const getMyPayment = async (req, res) => {
  const { bookingId } = req.params;
  const payment = await paymentService.getPaymentByBooking(bookingId, req.user.id, req.user.role);
  return ApiResponse.success(res, StatusCodes.OK, 'Payment retrieved.', payment);
};

const getWorkerEarnings = async (req, res) => {
  const result = await paymentService.getWorkerEarnings(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Earnings retrieved.', result);
};

const getWorkerEarningsHistory = async (req, res) => {
  const earningsHistoryService = require('./earnings-history.service');
  const result = await earningsHistoryService.listWorkerHistory(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Earnings history retrieved.', result);
};

const adminRefund = async (req, res) => {
  const { paymentId } = req.params;
  const { reason } = req.body;
  if (!reason) throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund reason is required.');
  const payment = await paymentService.refundPayment(paymentId, req.user.id, reason);
  logEvent({ req, type: 'finance', action: 'Admin refund issued', target: paymentId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment refunded successfully.', payment);
};

const openDispute = async (req, res) => {
  const { bookingId, reason, evidence, category } = req.body;
  if (!bookingId || !reason) throw new ApiError(StatusCodes.BAD_REQUEST, 'bookingId and reason are required.');
  const dispute = await disputeService.openDispute(bookingId, req.user.id, reason, evidence, category);
  logEvent({ req, type: 'finance', action: 'Dispute opened', target: bookingId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.CREATED, 'Dispute opened successfully.', dispute);
};

const resolveDispute = async (req, res) => {
  const { id } = req.params;
  const { resolution, decision, refundAmount, internalNote } = req.body;
  const dispute = await disputeService.resolveDispute(id, req.user.id, {
    resolution,
    decision,
    refundAmount,
    internalNote,
  });
  logEvent({
    req,
    type: 'finance',
    action: `Dispute resolved: ${decision}${refundAmount ? ` (refundAmount=${refundAmount})` : ''}`,
    target: id,
  });
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute resolved.', dispute);
};

const markDisputeReviewing = async (req, res) => {
  const { id } = req.params;
  const dispute = await disputeService.markDisputeReviewing(id, req.user.id);
  logEvent({ req, type: 'finance', action: 'Dispute marked reviewing', target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute marked as reviewing.', dispute);
};

const assignDisputeAdmin = async (req, res) => {
  const { id } = req.params;
  const { adminId } = req.body;
  const target = adminId || req.user.id;
  const dispute = await disputeService.assignAdmin(id, target);
  logEvent({ req, type: 'finance', action: 'Dispute admin assigned', target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute assigned.', dispute);
};

const addDisputeInternalNote = async (req, res) => {
  const { id } = req.params;
  const { note } = req.body;
  if (!note) throw new ApiError(StatusCodes.BAD_REQUEST, 'note is required.');
  const dispute = await disputeService.addInternalNote(id, req.user.id, note);
  logEvent({ req, type: 'finance', action: 'Dispute internal note added', target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Note added.', dispute);
};

const requestDisputeEvidence = async (req, res) => {
  const { id } = req.params;
  const { target, message } = req.body;
  const dispute = await disputeService.requestEvidence(id, req.user.id, target || 'both', message);
  logEvent({ req, type: 'finance', action: `Dispute evidence requested from ${target || 'both'}`, target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Evidence requested.', dispute);
};

const addDisputeEvidence = async (req, res) => {
  const { id } = req.params;
  const { files } = req.body;
  if (!Array.isArray(files) || !files.length) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'files array is required.');
  }
  const dispute = await disputeService.addEvidence(id, req.user.id, req.user.role, files);
  return ApiResponse.success(res, StatusCodes.OK, 'Evidence added.', dispute);
};

const appealDispute = async (req, res) => {
  const { id } = req.params;
  const { appealReason } = req.body;
  const dispute = await disputeService.appealDispute(id, req.user.id, req.user.role, appealReason);
  return ApiResponse.success(res, StatusCodes.OK, 'Appeal filed.', dispute);
};

const resolveDisputeAppeal = async (req, res) => {
  const { id } = req.params;
  const { outcome, note } = req.body;
  const dispute = await disputeService.resolveAppeal(id, req.user.id, outcome, note);
  logEvent({ req, type: 'finance', action: `Appeal ${outcome}`, target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Appeal resolved.', dispute);
};

const getDisputeById = async (req, res) => {
  const dispute = await disputeService.getDisputeById(req.params.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute retrieved.', dispute);
};

const getDisputes = async (req, res) => {
  const result = await disputeService.getDisputesByAdmin(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Disputes retrieved.', result);
};

const getMyDisputes = async (req, res) => {
  const result = await disputeService.getDisputesForCustomer(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Your disputes retrieved.', result);
};

const getMyWorkerDisputes = async (req, res) => {
  const result = await disputeService.getDisputesForWorker(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Your disputes retrieved.', result);
};

const getDisputeByIdForParty = async (req, res) => {
  const dispute = await disputeService.getDisputeByIdForParty(req.params.id, req.user.id, req.user.role);
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute retrieved.', dispute);
};

const updatePayoutSettings = async (req, res) => {
  const payload = req.body;

  if (!payload || typeof payload !== 'object' || Array.isArray(payload) || !Object.keys(payload).length) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'At least one payout setting is required.');
  }

  if (payload.payoutDetails && (typeof payload.payoutDetails !== 'object' || Array.isArray(payload.payoutDetails))) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'payoutDetails must be an object.');
  }

  const result = await paymentService.updateWorkerPayoutSettings(req.user.id, payload);
  return ApiResponse.success(res, StatusCodes.OK, 'Payout settings updated.', result);
};

const queries = require('./payment.queries');
const { paginated, single } = require('../../middleware/envelope.middleware');

const adminListPayments = async (req, res) => {
  const r = await queries.listAdminPayments(req.query);
  return paginated(res, r);
};

const adminPaymentDetail = async (req, res) => {
  const detail = await paymentService.getAdminPaymentDetail(req.params.id);
  return single(res, detail);
};

const adminPaymentsStats = async (req, res) => {
  const stats = await queries.statsAdmin();
  return single(res, stats);
};

const adminPartialRefund = async (req, res) => {
  const { bookingId } = req.params;
  const { refundAmount, deductFrom, reason, reasonCode } = req.body;
  const result = await paymentService.partialRefund({
    bookingId, adminId: req.user.id, refundAmount, deductFrom, reason, reasonCode, ipAddress: req.ip,
  });
  return ApiResponse.success(res, StatusCodes.OK, 'Partial refund processed.', result);
};

// ─── New endpoints (Plan 2) ────────────────────────────────────────────

const CashDebt = require('./cash-debt.model');
const DebtSettlement = require('./debt-settlement.model');
const payoutService = require('./payout-request.service');
const PayoutRequest = require('./payout-request.model');

const getMyDebtsV2 = async (req, res) => {
  const workerId = req.user.id;
  const summary = await cashDebtService.getWorkerDebtSummary(workerId);
  const debts = await CashDebt.find({ worker: workerId }).sort({ createdAt: -1 }).limit(100);
  const submittedSettlements = await DebtSettlement.find({ worker: workerId }).sort({ createdAt: -1 }).limit(20);
  return res.json({ data: { summary, debts, submittedSettlements } });
};

const settleMyDebt = async (req, res) => {
  const workerId = req.user.id;
  const { amount, method, reference, proofUrl } = req.body;
  if (method === 'wallet_balance') {
    const r = await cashDebtService.settleByWallet({ workerId, amount });
    return res.json({ data: r });
  }
  const settlement = await cashDebtService.submitManualSettlement({ workerId, amount, method, reference, proofUrl });
  return res.status(202).json({ data: { settlement } });
};

const getMySettlements = async (req, res) => {
  const settlements = await DebtSettlement.find({ worker: req.user.id }).sort({ createdAt: -1 });
  return res.json({ data: { settlements } });
};

const adminListSettlements = async (req, res) => {
  const { status, page = 1, limit = 20 } = req.query;
  const q = {};
  if (status) q.status = status;
  const skip = (Number(page) - 1) * Number(limit);
  const [items, total] = await Promise.all([
    DebtSettlement.find(q).populate('worker', 'name email').sort({ createdAt: -1 }).skip(skip).limit(Number(limit)),
    DebtSettlement.countDocuments(q),
  ]);
  return res.json({ data: items, meta: { page: Number(page), limit: Number(limit), total } });
};

const adminVerifySettlement = async (req, res) => {
  const { id } = req.params;
  const r = await cashDebtService.verifyManualSettlement({ settlementId: id, adminId: req.user.id, ipAddress: req.ip });
  return res.json({ data: r });
};

const adminRejectSettlement = async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;
  const r = await cashDebtService.rejectManualSettlement({ settlementId: id, adminId: req.user.id, reason });
  return res.json({ data: r });
};

const User = require('../users/user.model');

const adminListCashDebtsGrouped = async (req, res) => {
  const rows = await CashDebt.aggregate([
    { $match: { status: { $in: ['outstanding', 'partially_paid'] } } },
    { $group: {
        _id: '$worker',
        totalOwed: { $sum: '$remaining' },
        originalTotal: { $sum: '$amount' },
        amountRecovered: { $sum: '$paidAmount' },
        debtCount: { $sum: 1 },
        oldest: { $min: '$createdAt' },
        latest: { $max: '$createdAt' },
        statuses: { $addToSet: '$status' },
        debtTypes: { $addToSet: '$debtType' },
    }},
    { $sort: { totalOwed: -1 } },
  ]);
  const workerIds = rows.map(r => r._id);
  const [workers, pendingSettlements] = await Promise.all([
    User.find({ _id: { $in: workerIds } }).select('name email'),
    DebtSettlement.find({ worker: { $in: workerIds }, status: 'pending_verification' })
      .select('worker totalAmount method submittedAt'),
  ]);
  const wmap = Object.fromEntries(workers.map(w => [String(w._id), w]));
  const smap = {};
  pendingSettlements.forEach(settlement => {
    const workerId = String(settlement.worker);
    const summary = smap[workerId] || { count: 0, amount: 0, methods: new Set(), latestAt: null };
    summary.count += 1;
    summary.amount += settlement.totalAmount || 0;
    summary.methods.add(settlement.method);
    if (!summary.latestAt || settlement.submittedAt > summary.latestAt) summary.latestAt = settlement.submittedAt;
    smap[workerId] = summary;
  });
  const data = rows.map(r => ({
    workerId: r._id,
    worker: wmap[String(r._id)] || null,
    totalOwed: r2(r.totalOwed || 0),
    originalTotal: r2(r.originalTotal || 0),
    amountRecovered: r2(r.amountRecovered || 0),
    debtCount: r.debtCount,
    oldest: r.oldest,
    latest: r.latest,
    statusMix: r.statuses,
    debtTypes: r.debtTypes,
    pendingSettlementCount: smap[String(r._id)]?.count || 0,
    pendingSettlementAmount: r2(smap[String(r._id)]?.amount || 0),
    pendingSettlementMethods: [...(smap[String(r._id)]?.methods || [])],
    latestSettlementAt: smap[String(r._id)]?.latestAt || null,
  }));
  return res.json({ data });
};

const adminListWorkerDebts = async (req, res) => {
  const { workerId } = req.params;
  const debts = await CashDebt.find({ worker: workerId }).sort({ createdAt: -1 });
  const settlements = await DebtSettlement.find({ worker: workerId, status: 'pending_verification' }).sort({ createdAt: -1 });
  return res.json({ data: { debts, settlements } });
};

const { createNotification } = require('../notifications/notification.service');

const adminSendDebtReminder = async (req, res) => {
  const { workerId } = req.params;
  const worker = await User.findById(workerId).select('name email role');
  if (!worker) return res.status(404).json({ error: { message: 'Worker not found' } });

  const agg = await CashDebt.aggregate([
    { $match: { worker: worker._id, status: { $in: ['outstanding', 'partially_paid'] } } },
    { $group: { _id: null, total: { $sum: '$remaining' }, count: { $sum: 1 }, oldest: { $min: '$createdAt' } } },
  ]);
  const total = r2(agg[0]?.total || 0);
  const count = agg[0]?.count || 0;
  if (total <= 0 || count === 0) {
    return res.status(400).json({ error: { message: 'Worker has no outstanding debt' } });
  }

  await createNotification(
    worker._id,
    'system',
    'Outstanding platform fees',
    `You have ${count} unpaid cash-job fee${count === 1 ? '' : 's'} totalling ${total.toFixed(2)} EGP. Please settle to keep accepting larger jobs.`,
    null,
    './technician-dashboard.html#earnings'
  );

  try {
    logEvent({ req, type: 'finance', action: 'Admin sent debt reminder', target: String(worker._id) });
  } catch (_) { /* audit best-effort */ }

  return res.json({ data: { workerId: worker._id, total, count, sentAt: new Date() } });
};

const adminSettlementHistoryCsv = async (req, res) => {
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', 'attachment; filename="settlements.csv"');
  res.write('date,worker,method,amount,status,verifier,reference\n');
  const cursor = DebtSettlement.find({}).populate('worker verifiedBy', 'name').sort({ createdAt: -1 }).cursor();
  for await (const s of cursor) {
    const row = [
      s.createdAt.toISOString(),
      JSON.stringify(s.worker?.name || ''),
      s.method,
      s.totalAmount,
      s.status,
      JSON.stringify(s.verifiedBy?.name || ''),
      JSON.stringify(s.reference || ''),
    ].join(',');
    res.write(row + '\n');
  }
  res.end();
};

const createPayoutRequest = async (req, res) => {
  const { amount, method, details } = req.body;
  const payout = await payoutService.requestPayout({ workerId: req.user.id, amount, method, details });
  return res.status(201).json({ data: { payout } });
};

const myPayouts = async (req, res) => {
  const items = await payoutService.listMine(req.user.id);
  return res.json({ data: items });
};

const adminListPayouts = async (req, res) => {
  const { status, page = 1, limit = 20 } = req.query;
  const q = {};
  if (status) q.status = status;
  const skip = (Number(page) - 1) * Number(limit);
  const [items, total] = await Promise.all([
    PayoutRequest.find(q).populate('worker', 'name email').sort({ createdAt: -1 }).skip(skip).limit(Number(limit)),
    PayoutRequest.countDocuments(q),
  ]);
  return res.json({ data: items, meta: { page: Number(page), limit: Number(limit), total } });
};

const adminApprovePayout = async (req, res) => {
  const r = await payoutService.approvePayout({ payoutId: req.params.id, adminId: req.user.id, note: req.body.note, ipAddress: req.ip });
  return res.json({ data: r });
};

const adminMarkPayoutPaid = async (req, res) => {
  const r = await payoutService.markPayoutPaid({ payoutId: req.params.id, adminId: req.user.id, transactionRef: req.body.transactionRef, ipAddress: req.ip });
  return res.json({ data: r });
};

const adminRejectPayout = async (req, res) => {
  const r = await payoutService.rejectPayout({ payoutId: req.params.id, adminId: req.user.id, reason: req.body.reason, ipAddress: req.ip });
  return res.json({ data: r });
};

const Transaction    = require('./transaction.model');
const Wallet         = require('./wallet.model');
const CustomerCredit = require('./customer-credit.model');
const customerCreditService = require('./customer-credit.service');
const Payment        = require('./payment.model');
const Invoice        = require('./invoice.model');

const getCustomerHistory = async (req, res) => {
  const customer = req.user.id;
  const { type = 'all', from, to, limit = 20, page = 1 } = req.query;

  const dateFilter = {};
  if (from) dateFilter.$gte = new Date(from);
  if (to)   dateFilter.$lte = new Date(to);
  const hasDate = !!(from || to);

  const payments = (type === 'all' || type === 'payment' || type === 'refund')
    ? await Payment.find({ user: customer, ...(hasDate ? { createdAt: dateFilter } : {}) }).lean()
    : [];
  const credits = (type === 'all' || type === 'credit_issued')
    ? await CustomerCredit.find({ customer, ...(hasDate ? { createdAt: dateFilter } : {}) }).lean()
    : [];

  const items = [];
  if (type === 'all' || type === 'payment') {
    items.push(...payments.map(p => ({
      type: 'payment',
      at: p.createdAt,
      amount: p.amount,
      status: p.status,
      paymentId: p._id,
      booking: p.booking,
    })));
  }
  if (type === 'all' || type === 'refund') {
    items.push(...payments
      .filter(p => p.refundedAmount && p.refundedAmount > 0)
      .map(p => ({
        type: 'refund',
        at: p.refundedAt || p.updatedAt || p.createdAt,
        amount: p.refundedAmount,
        status: p.status,
        paymentId: p._id,
        booking: p.booking,
      }))
    );
  }
  if (type === 'all' || type === 'credit_issued') {
    items.push(...credits.map(c => ({
      type: 'credit_issued',
      at: c.createdAt,
      amount: c.amount,
      source: c.source,
      remaining: c.amount - c.consumed,
      creditId: c._id,
    })));
  }

  items.sort((a, b) => new Date(b.at) - new Date(a.at));
  const _limit = Math.min(Number(limit) || 20, 100);
  const _page  = Math.max(Number(page)  || 1,  1);
  const start  = (_page - 1) * _limit;
  const paged  = items.slice(start, start + _limit);

  return res.json({ data: paged, meta: { total: items.length, page: _page, limit: _limit } });
};

const getMyCustomerCredits = async (req, res) => {
  const credits = await customerCreditService.listForCustomer(req.user.id);
  const balance = await customerCreditService.balance(req.user.id);
  return res.json({ data: { credits, balance } });
};

const adminIssueCustomerCredit = async (req, res) => {
  const { customerId, amount, source = 'apology', reason, relatedBooking, expiresAt } = req.body;
  const credit = await customerCreditService.issueCredit({
    customer: customerId,
    amount: Number(amount),
    source,
    reason,
    relatedBooking,
    expiresAt: expiresAt ? new Date(expiresAt) : undefined,
    issuedBy: req.user.id,
    ipAddress: req.ip,
  });
  return res.status(201).json({ data: credit });
};

const getMyInvoices = async (req, res) => {
  const role = req.user.role;
  let invoices = [];
  if (role === 'worker') invoices = await Invoice.find({ worker: req.user.id }).sort({ createdAt: -1 });
  else invoices = await Invoice.find({ customer: req.user.id }).sort({ createdAt: -1 });
  return res.json({ data: { invoices } });
};

const getMyTransactions = async (req, res) => {
  const { type, from, to, page = 1, limit = 20 } = req.query;
  const wallet = await Wallet.findOne({ worker: req.user.id }).select('_id');
  if (!wallet) return res.json({ data: [], meta: { page: 1, limit: Number(limit) || 20, total: 0 } });

  const q = { wallet: wallet._id };
  if (type) q.type = type;
  if (from || to) q.createdAt = {};
  if (from) q.createdAt.$gte = new Date(from);
  if (to)   q.createdAt.$lte = new Date(to);

  const _limit = Math.min(Number(limit) || 20, 100);
  const _page  = Math.max(Number(page)  || 1,  1);
  const [items, total] = await Promise.all([
    Transaction.find(q)
      .populate({ path: 'payment', select: 'booking' })
      .sort({ createdAt: -1 })
      .skip((_page - 1) * _limit)
      .limit(_limit),
    Transaction.countDocuments(q),
  ]);
  return res.json({ data: items, meta: { page: _page, limit: _limit, total } });
};

const downloadReceipt = async (req, res) => {
  const fs = require('fs');
  const Payment = require('./payment.model');
  const Invoice = require('./invoice.model');
  const receiptSvc = require('./receipt.service');
  const payment = await Payment.findById(req.params.id);
  if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found');

  const uid = String(req.user.id);
  const isParty = [payment.user, payment.worker].some(x => String(x) === uid);
  const isAdmin = req.user.role === 'admin';
  if (!isParty && !isAdmin) throw new ApiError(StatusCodes.FORBIDDEN, 'Forbidden');

  let invoice = await Invoice.findOne({ payment: payment._id });
  if (!invoice) throw new ApiError(StatusCodes.NOT_FOUND, 'Receipt not available');
  if (!invoice.pdfPath || !fs.existsSync(invoice.pdfPath)) {
    try { await receiptSvc.generate(invoice); } catch (_) {}
    invoice = await Invoice.findById(invoice._id);
  }
  if (!invoice.pdfPath || !fs.existsSync(invoice.pdfPath)) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Receipt not ready');
  }
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="${invoice.number}.pdf"`);
  fs.createReadStream(invoice.pdfPath).pipe(res);
};

const adminForceRelease = async (req, res) => {
  const p = await paymentService.forceRelease(req.params.id, {
    actor:     req.user.id,
    reason:    req.body?.reason || req.body?.note,
    reasonCode: req.body?.reasonCode,
    ipAddress: req.ip,
  });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment force-released.', p);
};

const adminForceLock = async (req, res) => {
  const p = await paymentService.forceLock(req.params.id, {
    actor:     req.user.id,
    reason:    req.body?.reason || req.body?.note,
    reasonCode: req.body?.reasonCode,
    ipAddress: req.ip,
  });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment locked.', p);
};

const adminForceUnlock = async (req, res) => {
  const p = await paymentService.forceUnlock(req.params.id, {
    actor:     req.user.id,
    reason:    req.body?.reason || req.body?.note,
    reasonCode: req.body?.reasonCode,
    ipAddress: req.ip,
  });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment unlocked.', p);
};

module.exports = {
  holdPayment,
  downloadReceipt,
  adminForceRelease,
  adminForceLock,
  adminForceUnlock,
  adminPartialRefund,
  adminListPayments,
  adminPaymentDetail,
  adminPaymentsStats,
  confirmCompletion,
  adminApproveCompletion,
  adminRejectCash,
  getPendingApprovals,
  getCashDebts,
  markCashDebtPaid,
  getMyDebts,
  getMyDebtsV2,
  settleMyDebt,
  getMySettlements,
  adminListSettlements,
  adminVerifySettlement,
  adminRejectSettlement,
  adminListCashDebtsGrouped,
  adminListWorkerDebts,
  adminSendDebtReminder,
  adminSettlementHistoryCsv,
  createPayoutRequest,
  myPayouts,
  adminListPayouts,
  adminApprovePayout,
  adminMarkPayoutPaid,
  adminRejectPayout,
  getCustomerHistory,
  getMyCustomerCredits,
  adminIssueCustomerCredit,
  getMyInvoices,
  getMyTransactions,
  getMyPayment,
  getWorkerEarnings,
  getWorkerEarningsHistory,
  adminRefund,
  openDispute,
  resolveDispute,
  markDisputeReviewing,
  assignDisputeAdmin,
  addDisputeInternalNote,
  requestDisputeEvidence,
  addDisputeEvidence,
  appealDispute,
  resolveDisputeAppeal,
  getDisputeById,
  getDisputeByIdForParty,
  getDisputes,
  getMyDisputes,
  getMyWorkerDisputes,
  updatePayoutSettings,
};
