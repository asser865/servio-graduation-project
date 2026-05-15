const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const CashDebt    = require('./cash-debt.model');
const Booking     = require('../bookings/booking.model');
const Wallet      = require('./wallet.model');
const Transaction = require('./transaction.model');
const Settings    = require('../admin/settings.model');
const User        = require('../users/user.model');
const ApiError    = require('../../utils/ApiError');

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
        debt.status = 'paid';
        debt.paidBy = 'auto_wallet';
        debt.paidAt = new Date();
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
        debt.status = 'partially_paid';
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
          debt.status = 'paid';
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
}

module.exports = new CashDebtService();
