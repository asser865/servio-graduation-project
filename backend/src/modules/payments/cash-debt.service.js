const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const CashDebt    = require('./cash-debt.model');
const Booking     = require('../bookings/booking.model');
const Wallet      = require('./wallet.model');
const Transaction = require('./transaction.model');
const Settings    = require('../admin/settings.model');
const User        = require('../users/user.model');
const ApiError    = require('../../utils/ApiError');
const notify      = require('../notifications/dispatcher');
const { money: r2 } = require('../../utils/rounding');

const getOrCreateWallet = async (workerId, session) => {
  let wallet = await Wallet.findOne({ worker: workerId }).session(session || null);
  if (!wallet) {
    [wallet] = await Wallet.create([{ worker: workerId }], session ? { session } : {});
  }
  return wallet;
};

class CashDebtService {
  /**
   * Apply incomingAmount to outstanding debts oldest-first, then deduct
   * remaining debts from wallet.balance. Returns amount left over to credit.
   */
  async settleCashDebtsFromAmount(workerId, incomingAmount, session) {
    let remaining = incomingAmount;

    const debts = await CashDebt.find({
      worker: workerId,
      status: { $in: ['outstanding', 'partially_paid'] },
    })
      .sort({ createdAt: 1 })
      .session(session || null);

    for (const debt of debts) {
      const owed = debt.amount - debt.paidAmount;

      if (remaining >= owed) {
        remaining -= owed;
        debt.paidAmount += owed;
        debt.remaining = 0;
        debt.status = 'paid';
        debt.paidBy = 'auto_wallet';
        debt.paidAt = new Date();
        debt.settlementMethod = 'auto_offset';
        await debt.save({ session });

        await Booking.findByIdAndUpdate(
          debt.booking,
          { paymentStatus: 'cash_settled' },
          { session }
        );

        const wallet = await getOrCreateWallet(workerId, session);
        await Transaction.create([{
          wallet: wallet._id,
          cashDebt: debt._id,
          type: 'cash_debt_auto_deduct',
          amount: owed,
          currency: debt.currency,
          direction: 'debit',
          actor: workerId,
          note: `Auto-settled cash debt for booking ${debt.booking}`,
        }], { session });
      } else if (remaining > 0) {
        debt.paidAmount += remaining;
        debt.remaining = r2(debt.amount - debt.paidAmount);
        debt.status = 'partially_paid';
        debt.settlementMethod = 'auto_offset';
        await debt.save({ session });

        const wallet = await getOrCreateWallet(workerId, session);
        await Transaction.create([{
          wallet: wallet._id,
          cashDebt: debt._id,
          type: 'cash_debt_auto_deduct',
          amount: remaining,
          currency: debt.currency,
          direction: 'debit',
          actor: workerId,
          note: `Partial auto-deduct on cash debt for booking ${debt.booking}`,
        }], { session });

        remaining = 0;
        break;
      }
    }

    // Step 2 — if incoming amount exhausted, deduct remaining debts from wallet balance
    if (remaining === 0) {
      const wallet = await getOrCreateWallet(workerId, session);
      const freshDebts = await CashDebt.find({
        worker: workerId,
        status: { $in: ['outstanding', 'partially_paid'] },
      })
        .sort({ createdAt: 1 })
        .session(session || null);

      for (const debt of freshDebts) {
        const owed = debt.amount - debt.paidAmount;
        if (wallet.balance >= owed) {
          wallet.balance -= owed;
          await wallet.save({ session });

          debt.paidAmount += owed;
          debt.remaining = 0;
          debt.status = 'paid';
          debt.settlementMethod = 'auto_offset';
          debt.paidBy = 'auto_wallet';
          debt.paidAt = new Date();
          await debt.save({ session });

          await Booking.findByIdAndUpdate(
            debt.booking,
            { paymentStatus: 'cash_settled' },
            { session }
          );

          await Transaction.create([{
            wallet: wallet._id,
            cashDebt: debt._id,
            type: 'cash_debt_auto_deduct',
            amount: owed,
            currency: debt.currency,
            direction: 'debit',
            actor: workerId,
            note: `Wallet-deduct cash debt for booking ${debt.booking}`,
          }], { session });
        } else {
          break;
        }
      }
    }

    return { remainingAmount: remaining };
  }

  async checkDebtThresholds(workerId) {
    const settings = await Settings.findOne().lean();
    const warningThreshold = settings?.cashDebtWarningThreshold ?? 1000;
    const blockThreshold   = settings?.cashDebtBlockThreshold   ?? 5000;
    const autoBlockEnabled = settings?.cashDebtAutoBlockEnabled  !== false;

    const debts = await CashDebt.find({
      worker: workerId,
      status: { $in: ['outstanding', 'partially_paid'] },
    }).lean();

    const total = debts.reduce((sum, d) => sum + (d.amount - d.paidAmount), 0);

    if (total >= warningThreshold) {
      const { logEvent } = require('../admin/audit.service');
      logEvent({
        type: 'finance',
        action: `Cash debt warning: worker ${workerId} owes ${total}`,
        target: String(workerId),
        status: 'warn',
      });
    }

    if (total >= blockThreshold && autoBlockEnabled) {
      await User.findByIdAndUpdate(workerId, {
        'restrictions.cashBookingsBlocked': true,
        'restrictions.blockReason': 'cash_debt_limit',
        'restrictions.blockedAt': new Date(),
        'restrictions.blockedBy': 'system',
      });
    }
  }

  async markCashDebtManuallyPaid(debtId, adminId, { amount, adminNote }) {
    const debt = await CashDebt.findById(debtId);
    if (!debt) throw new ApiError(StatusCodes.NOT_FOUND, 'Cash debt not found.');

    const remaining = debt.amount - debt.paidAmount;
    if (!amount || amount <= 0 || amount > remaining) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Amount must be between 1 and ${remaining} (remaining owed).`
      );
    }

    const session = await mongoose.startSession();
    await session.withTransaction(async () => {
      debt.paidAmount += amount;
      if (debt.paidAmount >= debt.amount) {
        debt.status = 'paid';
        debt.paidBy = 'manual_admin';
        debt.paidAt = new Date();
        await Booking.findByIdAndUpdate(
          debt.booking,
          { paymentStatus: 'cash_settled' },
          { session }
        );
      } else {
        debt.status = 'partially_paid';
      }
      if (adminNote) debt.adminNote = adminNote;
      await debt.save({ session });

      const wallet = await getOrCreateWallet(debt.worker, session);
      await Transaction.create([{
        wallet: wallet._id,
        cashDebt: debt._id,
        type: 'cash_debt_manual_payment',
        amount,
        currency: debt.currency,
        direction: 'debit',
        actor: adminId,
        note: adminNote || `Manual payment by admin ${adminId}`,
      }], { session });
    });
    await session.endSession();

    // Re-evaluate block status after manual payment
    await this.checkDebtThresholds(debt.worker);
    return debt;
  }

  async getWorkerDebts(workerId) {
    const settings = await Settings.findOne().lean();
    const blockThreshold = settings?.cashDebtBlockThreshold ?? 5000;

    const debts = await CashDebt.find({ worker: workerId })
      .populate('booking', 'scheduledDate serviceCategory')
      .sort({ createdAt: -1 });

    const outstanding = debts.filter(d => d.status === 'outstanding')
      .reduce((s, d) => s + (d.amount - d.paidAmount), 0);
    const partiallyPaid = debts.filter(d => d.status === 'partially_paid')
      .reduce((s, d) => s + (d.amount - d.paidAmount), 0);
    const autoDeductedTotal = debts
      .filter(d => d.paidBy === 'auto_wallet')
      .reduce((s, d) => s + d.paidAmount, 0);
    const manualPaidTotal = debts
      .filter(d => d.paidBy === 'manual_admin')
      .reduce((s, d) => s + d.paidAmount, 0);
    const totalOwed = outstanding + partiallyPaid;

    return {
      items: debts.map(d => ({
        debtId: d._id,
        bookingId: d.booking,
        amount: d.amount,
        paidAmount: d.paidAmount,
        currency: d.currency,
        status: d.status,
        createdAt: d.createdAt,
      })),
      summary: {
        totalOutstanding: outstanding,
        totalPartiallyPaid: partiallyPaid,
        autoDeductedTotal,
        manualPaidTotal,
        blockThreshold,
        remainingBeforeBlock: Math.max(0, blockThreshold - totalOwed),
      },
    };
  }

  async getAdminDebts({ status, workerId, page = 1, limit = 20 } = {}) {
    const filter = {};
    if (status) filter.status = status;
    if (workerId) filter.worker = workerId;

    const skip = (Number(page) - 1) * Number(limit);

    const [debts, total] = await Promise.all([
      CashDebt.find(filter)
        .populate('worker', 'name email')
        .populate('booking', 'scheduledDate serviceCategory')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      CashDebt.countDocuments(filter),
    ]);

    const all = await CashDebt.find({}).lean();
    const summary = {
      totalOutstanding: all.filter(d => d.status === 'outstanding').reduce((s, d) => s + (d.amount - d.paidAmount), 0),
      totalPartiallyPaid: all.filter(d => d.status === 'partially_paid').reduce((s, d) => s + (d.amount - d.paidAmount), 0),
      totalPaid: all.filter(d => d.status === 'paid').reduce((s, d) => s + d.paidAmount, 0),
    };

    return {
      items: debts.map(d => ({
        debtId: d._id,
        worker: d.worker,
        bookingId: d.booking?._id,
        amount: d.amount,
        paidAmount: d.paidAmount,
        currency: d.currency,
        status: d.status,
        createdAt: d.createdAt,
        paidAt: d.paidAt,
      })),
      summary,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }

  async getWorkerDebtSummary(workerId) {
    const debts = await CashDebt.find({
      worker: workerId,
      status: { $in: ['outstanding', 'partially_paid'] },
    });
    const remainingOf = (d) => (d.remaining ?? (d.amount - (d.paidAmount || 0)));
    const totalOutstanding = debts.reduce((a, d) => a + remainingOf(d), 0);
    const oldest = debts.length
      ? debts.reduce((m, d) => (d.createdAt < m.createdAt ? d : m), debts[0])
      : null;
    const wallet = await Wallet.findOne({ worker: workerId }).select('balance');
    return {
      totalOutstanding: r2(totalOutstanding),
      count: debts.length,
      outstandingCount: debts.filter((d) => d.status === 'outstanding').length,
      partialCount: debts.filter((d) => d.status === 'partially_paid').length,
      oldestAt: oldest?.createdAt || null,
      walletBalance: wallet ? r2(wallet.balance || 0) : 0,
    };
  }

  async settleByWallet({ workerId, amount }) {
    if (!(amount > 0)) throw new ApiError(StatusCodes.BAD_REQUEST, 'Amount must be > 0');
    const session = await mongoose.startSession();
    try {
      return await session.withTransaction(async () => {
        const wallet = await Wallet.findOne({ worker: workerId }).session(session);
        if (!wallet || wallet.balance < amount) {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'Wallet underfunded');
        }
        const debts = await CashDebt.find({
          worker: workerId,
          status: { $in: ['outstanding', 'partially_paid'] },
        })
          .sort({ createdAt: 1 })
          .session(session);
        const remainingOf = (d) => (d.remaining ?? (d.amount - (d.paidAmount || 0)));
        const totalOutstanding = debts.reduce((a, d) => a + remainingOf(d), 0);
        if (amount > totalOutstanding) {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'Amount exceeds outstanding total');
        }
        let left = amount;
        const touched = [];
        for (const d of debts) {
          if (left <= 0) break;
          const owed = remainingOf(d);
          const pay = Math.min(owed, left);
          d.remaining = r2(owed - pay);
          d.paidAmount = (d.paidAmount || 0) + pay;
          d.status = d.remaining === 0 ? 'paid' : 'partially_paid';
          d.settlementMethod = 'wallet_balance';
          if (d.status === 'paid') {
            d.paidBy = 'auto_wallet';
            d.paidAt = new Date();
          }
          await d.save({ session });
          touched.push({ debtId: d._id, applied: pay });
          left -= pay;
        }
        wallet.balance = r2(wallet.balance - amount);
        await wallet.save({ session });
        try {
          const adminAction = require('../admin/admin-action.service');
          await adminAction.record({
            adminId: workerId,
            actionType: 'debt_mark_paid',
            targetType: 'debt',
            targetId: touched[0]?.debtId,
            details: { method: 'wallet_balance', amount, touched },
            session,
          });
        } catch (_) {}
        return { amountApplied: amount, touched, walletBalanceAfter: wallet.balance };
      });
    } finally {
      await session.endSession();
    }
  }

  async submitManualSettlement({ workerId, amount, method, reference, proofUrl }) {
    const allowed = ['instapay', 'vodafone_cash', 'bank_transfer', 'cash_to_office'];
    if (!allowed.includes(method)) throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid manual method');
    if (!reference || reference.length < 3) throw new ApiError(StatusCodes.BAD_REQUEST, 'Reference required');
    if (!(amount > 0)) throw new ApiError(StatusCodes.BAD_REQUEST, 'Amount must be > 0');
    const DebtSettlement = require('./debt-settlement.model');
    const open = await CashDebt.find({
      worker: workerId,
      status: { $in: ['outstanding', 'partially_paid'] },
    }).sort({ createdAt: 1 });
    const remainingOf = (d) => (d.remaining ?? (d.amount - (d.paidAmount || 0)));
    const total = open.reduce((a, d) => a + remainingOf(d), 0);
    if (amount > total) throw new ApiError(StatusCodes.BAD_REQUEST, 'Amount exceeds outstanding total');
    const doc = await DebtSettlement.create({
      worker: workerId,
      debts: open.map((d) => d._id),
      totalAmount: amount,
      method,
      reference,
      proofUrl,
    });
    try { require('../../sockets/settlement.events').emitSettlementSubmitted({ settlement: doc }); } catch (_) {}
    return doc;
  }

  async verifyManualSettlement({ settlementId, adminId, ipAddress }) {
    const DebtSettlement = require('./debt-settlement.model');
    const session = await mongoose.startSession();
    try {
      return await session.withTransaction(async () => {
        const s = await DebtSettlement.findById(settlementId).session(session);
        if (!s) throw new ApiError(StatusCodes.NOT_FOUND, 'Settlement not found');
        if (s.status !== 'pending_verification') {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'Settlement already processed');
        }
        const debts = await CashDebt.find({ _id: { $in: s.debts } })
          .sort({ createdAt: 1 })
          .session(session);
        const remainingOf = (d) => (d.remaining ?? (d.amount - (d.paidAmount || 0)));
        let left = s.totalAmount;
        for (const d of debts) {
          if (left <= 0) break;
          const owed = remainingOf(d);
          const pay = Math.min(owed, left);
          d.remaining = r2(owed - pay);
          d.paidAmount = (d.paidAmount || 0) + pay;
          d.status = d.remaining === 0 ? 'paid' : 'partially_paid';
          d.settlementMethod = s.method;
          d.settlementRef = s._id;
          if (d.status === 'paid') {
            d.paidBy = 'manual_admin';
            d.paidAt = new Date();
          }
          await d.save({ session });
          left -= pay;
        }
        s.status = 'verified';
        s.verifiedAt = new Date();
        s.verifiedBy = adminId;
        await s.save({ session });
        try {
          const adminAction = require('../admin/admin-action.service');
          await adminAction.record({
            adminId,
            actionType: 'settlement_verified',
            targetType: 'settlement',
            targetId: s._id,
            details: { amount: s.totalAmount, method: s.method, ipAddress },
            session,
          });
        } catch (_) {}
        try { require('../../sockets/settlement.events').emitSettlementVerified({ settlement: s }); } catch (_) {}
        notify.safeDispatch('settlement.verified', {
          worker: s.worker,
          amount: s.totalAmount,
          currency: 'EGP',
          settlementId: s._id,
        });
        return { settlement: s, touchedCount: debts.length };
      });
    } finally {
      await session.endSession();
    }
  }

  async rejectManualSettlement({ settlementId, adminId, reason }) {
    const DebtSettlement = require('./debt-settlement.model');
    const s = await DebtSettlement.findById(settlementId);
    if (!s) throw new ApiError(StatusCodes.NOT_FOUND, 'Settlement not found');
    if (s.status !== 'pending_verification') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Settlement already processed');
    }
    s.status = 'rejected';
    s.rejectionReason = reason;
    s.verifiedBy = adminId;
    s.verifiedAt = new Date();
    await s.save();
    try {
      const adminAction = require('../admin/admin-action.service');
      await adminAction.record({
        adminId,
        actionType: 'settlement_rejected',
        targetType: 'settlement',
        targetId: s._id,
        details: { reason },
      });
    } catch (_) {}
    try { require('../../sockets/settlement.events').emitSettlementRejected({ settlement: s }); } catch (_) {}
    notify.safeDispatch('settlement.rejected', {
      worker: s.worker,
      amount: s.totalAmount,
      currency: 'EGP',
      settlementId: s._id,
      reason,
    });
    return s;
  }
}

module.exports = new CashDebtService();
