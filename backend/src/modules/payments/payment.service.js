const mongoose = require('mongoose');
const { StatusCodes } = require('http-status-codes');

const Booking = require('../bookings/booking.model');
const Payment = require('./payment.model');
const Wallet = require('./wallet.model');
const Transaction = require('./transaction.model');
const ApiError = require('../../utils/ApiError');

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
  async releasePaymentToWorker(bookingId, userId) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');

    if (booking.user.toString() !== userId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'Only the booking owner can confirm completion.');
    }
    if (booking.status !== 'completed') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot release payment for a booking with status '${booking.status}'. Must be 'completed'.`
      );
    }

    const payment = await Payment.findOne({ booking: bookingId });
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment record not found.');

    if (payment.status !== 'held') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot release payment with status '${payment.status}'. Must be 'held'.`
      );
    }

    const session = await mongoose.startSession();
    let updatedPayment;

    await session.withTransaction(async () => {
      const wallet = await getOrCreateWallet(payment.worker, session);
      await wallet.releasePending(payment.workerEarning);

      payment.status = 'released';
      payment.releasedAt = new Date();
      updatedPayment = await payment.save({ session });

      await Transaction.create([{
        payment: payment._id,
        wallet: wallet._id,
        type: 'release',
        amount: payment.workerEarning,
        currency: payment.currency,
        direction: 'credit',
        actor: userId,
        note: `Escrow released to worker for booking ${bookingId}`,
      }], { session });

      await Transaction.create([{
        payment: payment._id,
        type: 'fee',
        amount: payment.platformFee,
        currency: payment.currency,
        direction: 'credit',
        actor: userId,
        note: `Platform fee recorded for booking ${bookingId}`,
      }], { session });
    });

    await session.endSession();
    return updatedPayment;
  }

  async refundPayment(paymentId, adminId, reason) {
    const payment = await Payment.findById(paymentId);
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found.');

    if (!['held', 'disputed'].includes(payment.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot refund a payment with status '${payment.status}'. Must be 'held' or 'disputed'.`
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
        { status: 'cancelled' },
        { session }
      );

      await Transaction.create([{
        payment: payment._id,
        wallet: wallet._id,
        type: 'refund',
        amount: payment.amount,
        currency: payment.currency,
        direction: 'credit',
        actor: adminId,
        note: reason || `Admin refund by ${adminId}`,
      }], { session });
    });

    await session.endSession();
    return updatedPayment;
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
      (acc, payment) => {
        if (payment.status === 'held') acc.totalHeld += payment.workerEarning;
        if (payment.status === 'released') acc.totalReleased += payment.workerEarning;
        return acc;
      },
      { totalHeld: 0, totalReleased: 0 }
    );

    return { wallet, payments, summary };
  }
}

module.exports = new PaymentService();
