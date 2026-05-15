const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const Booking    = require('../bookings/booking.model');
const Payment    = require('./payment.model');
const SavedCard  = require('../savedCards/savedCard.model');
const Wallet     = require('./wallet.model');
const Transaction = require('./transaction.model');
const ApiError   = require('../../utils/ApiError');

let cashDebtSvc;
const getCashDebtSvc = () => {
  if (!cashDebtSvc) cashDebtSvc = require('./cash-debt.service');
  return cashDebtSvc;
};

const logTransaction = async (data, session) => {
  const [log] = await Transaction.create([data], session ? { session } : {});
  return log;
};

const getOrCreateWallet = async (workerId, session) => {
  let wallet = await Wallet.findOne({ worker: workerId }).session(session || null);
  if (!wallet) {
    [wallet] = await Wallet.create([{ worker: workerId }], session ? { session } : {});
  }
  return wallet;
};

class PaymentService {
  async holdPayment(bookingId, customerId, { savedCardId }) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== customerId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }

    // Deadline check — must be first
    if (booking.paymentDeadline && Date.now() > new Date(booking.paymentDeadline).getTime()) {
      await Booking.findByIdAndUpdate(bookingId, { status: 'cancelled' }, { runValidators: false });
      throw new ApiError(StatusCodes.GONE, 'Payment deadline expired. Booking has been cancelled.');
    }

    // Lifecycle validation (never create/update Payment on these)
    if (booking.paymentMethod !== 'online') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'This booking does not use online payment.');
    }
    if (booking.status !== 'pending') {
      throw new ApiError(StatusCodes.CONFLICT, `Cannot hold payment for booking with status '${booking.status}'.`);
    }

    // Idempotency — check existing Payment
    const existing = await Payment.findOne({ booking: bookingId });
    if (existing && ['held', 'released', 'refunded', 'disputed'].includes(existing.status)) {
      throw new ApiError(StatusCodes.CONFLICT, `Payment already in status '${existing.status}'.`);
    }

    // Card lookup
    const card = savedCardId ? await SavedCard.findById(savedCardId) : null;

    // Demo failure conditions
    const buildFailureMeta = (failureReason) => ({
      demoCard: card ? { savedCardId: card._id, last4: card.last4, cardType: card.cardType, expiry: card.expiry, label: card.label } : undefined,
      failureReason,
    });

    if (!savedCardId || !card) {
      await this._upsertFailedPayment(booking, existing, buildFailureMeta('invalid_card'), customerId);
      throw new ApiError(StatusCodes.UNPROCESSABLE_ENTITY, 'Saved card not found.');
    }
    if (card.userId.toString() !== customerId.toString()) {
      await this._upsertFailedPayment(booking, existing, buildFailureMeta('invalid_card'), customerId);
      throw new ApiError(StatusCodes.FORBIDDEN, 'Card does not belong to you.');
    }
    if (card.last4 === '0000') {
      await this._upsertFailedPayment(booking, existing, buildFailureMeta('demo_decline'), customerId);
      throw new ApiError(StatusCodes.PAYMENT_REQUIRED, 'Card was declined (demo).');
    }

    // Success path
    const demoCard = { savedCardId: card._id, last4: card.last4, cardType: card.cardType, expiry: card.expiry, label: card.label };
    const paymentData = {
      booking: bookingId,
      user: customerId,
      worker: booking.worker,
      amount: booking.estimatedTotal,
      platformFee: booking.platformFeeAmount,
      workerEarning: booking.totalPrice,
      gateway: 'demo',
      status: 'held',
      paymentMethod: 'online',
      skipFeeCalc: true,
      metadata: { demoCard },
    };

    const session = await mongoose.startSession();
    let savedPayment;

    try {
      await session.withTransaction(async () => {
        if (existing && existing.status === 'failed') {
          Object.assign(existing, paymentData);
          savedPayment = await existing.save({ session });
        } else {
          try {
            [savedPayment] = await Payment.create([paymentData], { session });
          } catch (err) {
            if (err.code === 11000) {
              throw new ApiError(StatusCodes.CONFLICT, 'Payment already exists for this booking.');
            }
            throw err;
          }
        }

        booking.paymentMeta = demoCard;
        booking.paymentStatus = 'held';
        await booking.save({ session });

        const wallet = await getOrCreateWallet(booking.worker, session);
        await wallet.addPending(savedPayment.workerEarning);

        await logTransaction({
          payment: savedPayment._id,
          wallet: wallet._id,
          type: 'hold',
          amount: savedPayment.amount,
          currency: savedPayment.currency,
          direction: 'debit',
          actor: customerId,
          note: `Demo escrow hold for booking ${bookingId}`,
        }, session);
      });
    } finally {
      await session.endSession();
    }

    return savedPayment;
  }

  async _upsertFailedPayment(booking, existing, metadata, customerId) {
    const failData = {
      status: 'failed',
      metadata,
    };
    if (existing && existing.status === 'failed') {
      Object.assign(existing, failData);
      await existing.save();
    } else if (!existing) {
      await Payment.create({
        booking: booking._id,
        user: customerId,
        worker: booking.worker,
        amount: booking.estimatedTotal,
        platformFee: booking.platformFeeAmount,
        workerEarning: booking.totalPrice,
        gateway: 'demo',
        paymentMethod: 'online',
        skipFeeCalc: true,
        ...failData,
      });
    }
    await Booking.findByIdAndUpdate(booking._id, { paymentStatus: 'failed' }, { runValidators: false });
  }

  async requestReleaseByCustomer(bookingId, customerId) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== customerId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }
    if (booking.status !== 'awaiting_customer_confirmation') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot confirm completion for booking with status '${booking.status}'.`
      );
    }

    booking.customerConfirmedAt = new Date();
    booking.customerConfirmedBy = customerId;
    booking.status = 'pending_admin_review';

    if (booking.paymentMethod === 'online') {
      const payment = await Payment.findOne({ booking: bookingId });
      if (!payment || payment.status !== 'held') {
        throw new ApiError(StatusCodes.BAD_REQUEST, 'No held payment found for this booking.');
      }
      payment.releaseRequestedAt = new Date();
      payment.releaseRequestedBy = customerId;
      await payment.save();
    }

    await booking.save();
    return booking;
  }

  async adminApproveCompletion(bookingId, adminId) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.status !== 'pending_admin_review') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Booking must be in 'pending_admin_review' status. Current: '${booking.status}'.`
      );
    }

    const session = await mongoose.startSession();
    let result;

    await session.withTransaction(async () => {
      if (booking.paymentMethod === 'online') {
        const payment = await Payment.findOne({ booking: bookingId }).session(session);
        if (!payment || payment.status !== 'held') {
          throw new ApiError(StatusCodes.BAD_REQUEST, 'No held payment found for this booking.');
        }
        await this.releaseHeldPayment(payment, booking, adminId, session);
        booking.paymentStatus = 'released';
      } else {
        const CashDebt = require('./cash-debt.model');
        await CashDebt.create([{
          worker: booking.worker,
          booking: booking._id,
          amount: booking.platformFeeAmount,
        }], { session });

        await getCashDebtSvc().settleCashDebtsFromAmount(
          booking.worker,
          0,
          session
        );
        booking.paymentStatus = 'cash_pending_settlement';
      }

      booking.status = 'completed';
      await booking.save({ session });
      result = booking;
    });

    await session.endSession();

    // Check thresholds outside transaction (non-critical)
    if (booking.paymentMethod === 'cash') {
      getCashDebtSvc().checkDebtThresholds(booking.worker).catch(() => {});
    }

    return result;
  }

  async releaseHeldPayment(payment, booking, adminId, session) {
    const workerId = payment.worker || booking.worker;

    const { remainingAmount } = await getCashDebtSvc().settleCashDebtsFromAmount(
      workerId,
      payment.workerEarning,
      session
    );

    const wallet = await getOrCreateWallet(workerId, session);
    await wallet.deductPending(payment.workerEarning);
    await wallet.credit(remainingAmount);

    payment.status = 'released';
    payment.releaseApprovedAt = new Date();
    payment.releaseApprovedBy = adminId;
    await payment.save({ session });

    await logTransaction({
      payment: payment._id,
      wallet: wallet._id,
      type: 'release',
      amount: payment.workerEarning,
      currency: payment.currency,
      direction: 'credit',
      actor: adminId,
      note: `Escrow released to worker for booking ${payment.booking}`,
    }, session);

    await logTransaction({
      payment: payment._id,
      type: 'fee',
      amount: payment.platformFee,
      currency: payment.currency,
      direction: 'credit',
      actor: adminId,
      note: `Platform fee for booking ${payment.booking}`,
    }, session);
  }

  async adminRejectCash(bookingId, adminId, reason) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.paymentMethod !== 'cash') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'This endpoint is for cash bookings only.');
    }

    const Dispute = require('./dispute.model');
    booking.status = 'disputed';
    await booking.save();

    const dispute = await Dispute.create({
      booking: bookingId,
      raisedBy: adminId,
      raisedByRole: 'admin',
      reason: reason || 'Rejected by admin',
    });

    return { booking, dispute };
  }

  async refundPayment(paymentId, adminId, reason) {
    const payment = await Payment.findById(paymentId);
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');

    const booking = await Booking.findById(payment.booking);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');

    if (!['pending_admin_review', 'disputed'].includes(booking.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot refund: booking status must be 'pending_admin_review' or 'disputed'. Current: '${booking.status}'.`
      );
    }
    if (!['held', 'disputed'].includes(payment.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot refund payment with status '${payment.status}'.`
      );
    }

    const session = await mongoose.startSession();
    let updatedPayment;

    await session.withTransaction(async () => {
      const wallet = await getOrCreateWallet(payment.worker, session);
      await wallet.deductPending(payment.workerEarning);

      payment.status = 'refunded';
      payment.refundedAt = new Date();
      updatedPayment = await payment.save({ session });

      await Booking.findByIdAndUpdate(
        payment.booking,
        { status: 'cancelled', paymentStatus: 'refunded' },
        { session }
      );

      await logTransaction({
        payment: payment._id,
        wallet: wallet._id,
        type: 'refund',
        amount: payment.amount,
        currency: payment.currency,
        direction: 'credit',
        actor: adminId,
        note: reason || `Admin refund by ${adminId}`,
      }, session);
    });

    await session.endSession();
    return updatedPayment;
  }

  async getPendingApprovals({ paymentMethod, page = 1, limit = 20 } = {}) {
    const filter = { status: 'pending_admin_review' };
    if (paymentMethod) filter.paymentMethod = paymentMethod;

    const skip = (Number(page) - 1) * Number(limit);
    const [bookings, total] = await Promise.all([
      Booking.find(filter)
        .populate('user', 'name')
        .populate('worker', 'name')
        .populate('service', 'title')
        .sort({ customerConfirmedAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Booking.countDocuments(filter),
    ]);

    const bookingIds = bookings.map(b => b._id);
    const payments = await Payment.find({ booking: { $in: bookingIds } });
    const paymentMap = {};
    payments.forEach(p => { paymentMap[p.booking.toString()] = p; });

    const items = bookings.map(b => {
      const p = paymentMap[b._id.toString()];
      return {
        bookingId:           b._id,
        paymentId:           p?._id || null,
        customer:            { id: b.user?._id, name: b.user?.name },
        worker:              { id: b.worker?._id, name: b.worker?.name },
        service:             b.service?.title || b.serviceCategory,
        amount:              b.totalPrice,
        paymentMethod:       b.paymentMethod,
        workerEarning:       p?.workerEarning ?? null,
        platformFee:         p?.platformFee ?? null,
        totalPaid:           p?.amount || 0,
        customerConfirmedAt: b.customerConfirmedAt,
        paymentStatus:       b.paymentStatus,
      };
    });

    return {
      items,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }

  async getPaymentByBooking(bookingId, requesterId, requesterRole) {
    const payment = await Payment.findByBooking(bookingId);
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');
    if (requesterRole === 'user' && payment.user._id.toString() !== requesterId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You cannot view this payment.');
    }
    if (requesterRole === 'worker' && payment.worker._id.toString() !== requesterId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'You cannot view this payment.');
    }
    return payment;
  }

  async getWorkerEarnings(workerId, filters = {}) {
    const wallet = await getOrCreateWallet(workerId);
    const User = require('../users/user.model');
    const worker = await User.findById(workerId).select('completedJobs');

    const query = {
      worker: workerId,
      status: { $in: ['held', 'released'] },
    };


    if (filters.dateFrom || filters.dateTo) {
      query.createdAt = {};
      if (filters.dateFrom) query.createdAt.$gte = new Date(filters.dateFrom);
      if (filters.dateTo) query.createdAt.$lte = new Date(filters.dateTo);
    }
    if (filters.status) query.status = filters.status;
    const payments = await Payment.find(query)
      .populate('booking', 'scheduledDate address')
      .sort({ createdAt: -1 });
    const summary = payments.reduce(
      (acc, p) => {
        if (p.status === 'held') acc.totalHeld += p.workerEarning;
        if (p.status === 'released') acc.totalReleased += p.workerEarning;
        return acc;
      },
      { totalHeld: 0, totalReleased: 0 }
    );

    return {
      wallet,
      payments,
      summary,
      completedJobs: worker ? worker.completedJobs : 0
    };
  }

  async updateWorkerPayoutSettings(workerId, payload = {}) {
    const wallet = await getOrCreateWallet(workerId);

    if (payload.payoutMethod) wallet.payoutMethod = payload.payoutMethod;
    if (payload.payoutSchedule) wallet.payoutSchedule = payload.payoutSchedule;

    if (payload.payoutDetails) {
      wallet.payoutDetails = {
        ...wallet.payoutDetails,
        ...payload.payoutDetails,
      };
    }

    await wallet.save();
    return wallet;
  }
}

module.exports = new PaymentService();
