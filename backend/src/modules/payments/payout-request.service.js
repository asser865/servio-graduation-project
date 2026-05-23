const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');
const PayoutRequest = require('./payout-request.model');
const Wallet = require('./wallet.model');
const settings = require('../admin/admin-settings.service');
const ApiError = require('../../utils/ApiError');
const notify = require('../notifications/dispatcher');
const { money: r2 } = require('../../utils/rounding');

async function recordAudit(payload) {
  try {
    const adminAction = require('../admin/admin-action.service');
    await adminAction.record(payload);
  } catch (_) {
    // audit failures must not break payouts
  }
}

async function requestPayout({ workerId, amount, method, details }) {
  const cfg = await settings.get();
  if (amount < cfg.payout.minAmount) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Min ${cfg.payout.minAmount}`);
  }
  const wallet = await Wallet.findOne({ worker: workerId });
  if (!wallet || wallet.balance < amount) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Amount exceeds available balance');
  }
  const payout = await PayoutRequest.create({
    worker: workerId,
    amount,
    payoutMethod: method,
    payoutDetails: details || {},
  });
  try { require('../../sockets/settlement.events').emitPayoutRequested({ payout }); } catch (_) {}
  return payout;
}

async function approvePayout({ payoutId, adminId, note, ipAddress }) {
  const p = await PayoutRequest.findById(payoutId);
  if (!p) throw new ApiError(StatusCodes.NOT_FOUND, 'Payout not found');
  if (p.status !== 'pending') throw new ApiError(StatusCodes.BAD_REQUEST, `Already ${p.status}`);
  p.status = 'approved';
  p.processedBy = adminId;
  p.processedAt = new Date();
  p.adminNote = note;
  await p.save();
  await recordAudit({
    adminId,
    actionType: 'payout_approve',
    targetType: 'payout',
    targetId: p._id,
    details: { amount: p.amount, method: p.payoutMethod },
    ipAddress,
  });
  try { require('../../sockets/settlement.events').emitPayoutDecided({ payout: p }); } catch (_) {}
  notify.safeDispatch('payout.approved', {
    worker: p.worker,
    amount: p.amount,
    currency: 'EGP',
    payoutId: p._id,
  });
  return p;
}

async function markPayoutPaid({ payoutId, adminId, transactionRef, ipAddress }) {
  if (!transactionRef) throw new ApiError(StatusCodes.BAD_REQUEST, 'transactionRef required');
  const session = await mongoose.startSession();
  try {
    return await session.withTransaction(async () => {
      const p = await PayoutRequest.findById(payoutId).session(session);
      if (!p) throw new ApiError(StatusCodes.NOT_FOUND, 'Payout not found');
      if (p.status !== 'approved') {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Must be approved (was ${p.status})`);
      }
      const wallet = await Wallet.findOne({ worker: p.worker }).session(session);
      if (!wallet || wallet.balance < p.amount) {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'Wallet underfunded (stale)');
      }
      wallet.balance = r2(wallet.balance - p.amount);
      await wallet.save({ session });

      p.status = 'paid';
      p.transactionRef = transactionRef;
      await p.save({ session });

      await recordAudit({
        adminId,
        actionType: 'payout_mark_paid',
        targetType: 'payout',
        targetId: p._id,
        details: { amount: p.amount, transactionRef },
        ipAddress,
        session,
      });
      try { require('../../sockets/settlement.events').emitPayoutDecided({ payout: p }); } catch (_) {}
      notify.safeDispatch('payout.paid', {
        worker: p.worker,
        amount: p.amount,
        currency: 'EGP',
        payoutId: p._id,
        transactionRef,
      });
      return p;
    });
  } finally {
    await session.endSession();
  }
}

async function rejectPayout({ payoutId, adminId, reason, ipAddress }) {
  const p = await PayoutRequest.findById(payoutId);
  if (!p) throw new ApiError(StatusCodes.NOT_FOUND, 'Payout not found');
  if (p.status !== 'pending') throw new ApiError(StatusCodes.BAD_REQUEST, `Already ${p.status}`);
  p.status = 'rejected';
  p.rejectionReason = reason;
  p.processedBy = adminId;
  p.processedAt = new Date();
  await p.save();
  await recordAudit({
    adminId,
    actionType: 'payout_reject',
    targetType: 'payout',
    targetId: p._id,
    details: { reason },
    ipAddress,
  });
  try { require('../../sockets/settlement.events').emitPayoutDecided({ payout: p }); } catch (_) {}
  return p;
}

async function listPending() {
  return PayoutRequest.find({ status: { $in: ['pending', 'approved'] } })
    .populate('worker', 'name email')
    .sort({ createdAt: -1 });
}

async function listMine(workerId) {
  return PayoutRequest.find({ worker: workerId }).sort({ createdAt: -1 });
}

module.exports = { requestPayout, approvePayout, markPayoutPaid, rejectPayout, listPending, listMine };
