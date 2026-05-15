const { StatusCodes } = require('http-status-codes');
const mongoose = require('mongoose');
const Booking  = require('../bookings/booking.model');
const Payment  = require('./payment.model');
const Dispute  = require('./dispute.model');
const Transaction = require('./transaction.model');
const ApiError = require('../../utils/ApiError');

let paymentService;
const getPaymentService = () => {
  if (!paymentService) paymentService = require('./payment.service');
  return paymentService;
};

class DisputeService {
  async openDispute(bookingId, userId, reason, evidence = []) {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== userId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }

    const validStatuses = ['in_progress', 'completed', 'awaiting_customer_confirmation'];
    if (!validStatuses.includes(booking.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot open a dispute for a booking with status '${booking.status}'.`
      );
    }

    const existingDispute = await Dispute.findOne({
      booking: bookingId,
      status: { $in: ['open', 'reviewing'] },
    });
    if (existingDispute) {
      throw new ApiError(StatusCodes.CONFLICT, 'An open dispute already exists for this booking.');
    }

    let payment = null;
    if (booking.paymentMethod === 'online') {
      payment = await Payment.findOne({ booking: bookingId });
      if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found for this booking.');
      if (payment.status !== 'held') {
        throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot dispute a payment with status '${payment.status}'.`);
      }
      payment.status = 'disputed';
      await payment.save();

      await Booking.findByIdAndUpdate(bookingId, {
        status: 'disputed',
        paymentStatus: 'disputed',
      });

      await Transaction.create({
        payment: payment._id,
        type: 'dispute',
        amount: payment.amount,
        currency: payment.currency,
        direction: 'debit',
        actor: userId,
        note: `Dispute opened for booking ${bookingId}. Reason: ${reason.substring(0, 50)}`,
      });
    } else {
      // Cash dispute — no Payment record
      await Booking.findByIdAndUpdate(bookingId, { status: 'disputed' });
    }

    const dispute = await Dispute.create({
      booking: bookingId,
      payment: payment?._id,
      raisedBy: userId,
      raisedByRole: 'user',
      reason,
      evidence,
    });

    return dispute;
  }

  async resolveDispute(disputeId, adminId, resolution, decision) {
    const dispute = await Dispute.findById(disputeId).populate('booking payment');
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');

    if (!['open', 'reviewing'].includes(dispute.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot resolve a dispute with status '${dispute.status}'.`
      );
    }
    if (!['refund', 'release'].includes(decision)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, "Decision must be 'refund' or 'release'.");
    }

    const ps = getPaymentService();

    if (decision === 'refund') {
      await ps.refundPayment(dispute.payment._id.toString(), adminId, resolution);
      dispute.status = 'resolved_refund';
    } else {
      // Release path
      const session = await mongoose.startSession();
      await session.withTransaction(async () => {
        const booking = await Booking.findById(dispute.booking._id).session(session);
        booking.status = 'completed';
        booking.paymentStatus = 'released';
        await booking.save({ session });
        await ps.releaseHeldPayment(dispute.payment, booking, adminId, session);
      });
      await session.endSession();
      dispute.status = 'resolved_release';
    }

    dispute.resolution = resolution;
    dispute.resolvedBy = adminId;
    dispute.resolvedAt = new Date();
    await dispute.save();

    return dispute;
  }

  async getDisputesByAdmin({ status, page = 1, limit = 20 } = {}) {
    const filter = {};
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);

    const [disputes, total] = await Promise.all([
      Dispute.find(filter)
        .populate('booking', 'scheduledDate address status')
        .populate('payment', 'amount status currency')
        .populate('raisedBy', 'name email')
        .populate('resolvedBy', 'name')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Dispute.countDocuments(filter),
    ]);

    return {
      disputes,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }
}

module.exports = new DisputeService();
