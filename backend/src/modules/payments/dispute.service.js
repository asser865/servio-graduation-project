const { StatusCodes } = require('http-status-codes');
const mongoose = require('mongoose');

const Booking     = require('../bookings/booking.model');
const Payment     = require('./payment.model');
const Dispute     = require('./dispute.model');
const CashDebt    = require('./cash-debt.model');
const Transaction = require('./transaction.model');
const ApiError    = require('../../utils/ApiError');
const notifSvc    = require('../notifications/notification.service');

let paymentService;
const getPaymentService = () => {
  if (!paymentService) paymentService = require('./payment.service');
  return paymentService;
};

const ACTIVE_DISPUTE_STATUSES = ['open', 'reviewing'];
const DISPUTABLE_BOOKING_STATUSES = [
  'awaiting_customer_confirmation',
];

function sanitizeEvidence(evidence) {
  return Array.isArray(evidence)
    ? evidence.map(url => String(url || '').trim()).filter(Boolean).slice(0, 6)
    : [];
}

function isCashBooking(booking) {
  return String(booking?.paymentMethod || '').toLowerCase() === 'cash';
}

class DisputeService {
  async openDispute(bookingId, userId, reason, evidence = [], category = 'other') {
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== userId.toString()) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }

    if (!DISPUTABLE_BOOKING_STATUSES.includes(booking.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot open a dispute for a booking with status '${booking.status}'.`
      );
    }

    const existingDispute = await Dispute.findOne({
      booking: bookingId,
      status: { $in: ACTIVE_DISPUTE_STATUSES },
    });
    if (existingDispute) {
      throw new ApiError(StatusCodes.CONFLICT, 'An open dispute already exists for this booking.');
    }

    let payment = null;
    if (!isCashBooking(booking)) {
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
      await Booking.findByIdAndUpdate(bookingId, {
        status: 'disputed',
        paymentStatus: 'disputed',
      });
    }

    const dispute = await Dispute.create({
      booking: bookingId,
      payment: payment?._id,
      raisedBy: userId,
      raisedByRole: 'user',
      reason,
      category,
      evidence: sanitizeEvidence(evidence),
    });

    Promise.resolve(notifSvc.notifyDisputeOpened({ ...(dispute.toObject?.() || dispute), booking })).catch(() => {});
    return dispute;
  }

  async resolveDispute(disputeId, adminId, resolution, decision) {
    const dispute = await Dispute.findById(disputeId)
      .populate({
        path: 'booking',
        populate: [
          { path: 'user', select: 'name email' },
          { path: 'worker', select: 'name email' },
          { path: 'service', select: 'title category' },
        ],
      })
      .populate('payment');
    if (!dispute) throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');

    if (!ACTIVE_DISPUTE_STATUSES.includes(dispute.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot resolve a dispute with status '${dispute.status}'.`
      );
    }
    if (!['refund', 'release'].includes(decision)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, "Decision must be 'refund' or 'release'.");
    }

    const booking = dispute.booking;
    const payment = dispute.payment;
    const hasPayment = Boolean(payment);
    const ps = getPaymentService();

    if (decision === 'refund') {
      if (hasPayment) {
        await ps.refundPayment(payment._id.toString(), adminId, resolution);
      } else {
        booking.status = 'cancelled';
        booking.paymentStatus = 'not_required';
        booking.cancellationReason = resolution;
        await booking.save();
      }
      dispute.status = 'resolved_refund';
    } else {
      const session = await mongoose.startSession();
      await session.withTransaction(async () => {
        const freshBooking = await Booking.findById(booking._id).session(session);
        freshBooking.status = 'completed';

        if (hasPayment) {
          freshBooking.paymentStatus = 'released';
          await freshBooking.save({ session });
          await ps.releaseHeldPayment(payment, freshBooking, adminId, session);
          return;
        }

        freshBooking.paymentStatus = 'cash_pending_settlement';
        await freshBooking.save({ session });

        const existingDebt = await CashDebt.findOne({ booking: freshBooking._id }).session(session);
        if (!existingDebt && freshBooking.platformFeeAmount > 0) {
          await CashDebt.create([{
            worker: freshBooking.worker,
            booking: freshBooking._id,
            amount: freshBooking.platformFeeAmount,
          }], { session });
        }
      });
      await session.endSession();
      dispute.status = 'resolved_release';
    }

    dispute.resolution = resolution;
    dispute.decision = decision;
    dispute.resolvedBy = adminId;
    dispute.resolvedAt = new Date();
    await dispute.save();

    Promise.resolve(notifSvc.notifyDisputeResolved(dispute)).catch(() => {});
    return dispute;
  }

  async markDisputeReviewing(disputeId) {
    const dispute = await Dispute.findById(disputeId)
      .populate({
        path: 'booking',
        select: 'user worker service serviceCategory status paymentMethod paymentStatus',
        populate: [
          { path: 'user', select: 'name email' },
          { path: 'worker', select: 'name email' },
          { path: 'service', select: 'title category' },
        ],
      })
      .populate('raisedBy', 'name email')
      .populate('resolvedBy', 'name');

    if (!dispute) {
      throw new ApiError(StatusCodes.NOT_FOUND, 'Dispute not found.');
    }
    if (!ACTIVE_DISPUTE_STATUSES.includes(dispute.status)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Dispute is already resolved.');
    }

    dispute.status = 'reviewing';
    await dispute.save();
    return dispute;
  }

  async getDisputesByAdmin({ status, page = 1, limit = 20 } = {}) {
    const filter = {};
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);

    const [disputes, total] = await Promise.all([
      Dispute.find(filter)
        .populate({
          path: 'booking',
          select: 'scheduledDate scheduledTime address status paymentMethod paymentStatus totalPrice estimatedTotal platformFeeAmount serviceCategory service user worker',
          populate: [
            { path: 'user', select: 'name email phone' },
            { path: 'worker', select: 'name email phone' },
            { path: 'service', select: 'title category basePrice' },
          ],
        })
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

  async getDisputesForCustomer(userId, { status, page = 1, limit = 20 } = {}) {
    const filter = { raisedBy: userId, raisedByRole: 'user' };
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);
    const [disputes, total] = await Promise.all([
      Dispute.find(filter)
        .populate({
          path: 'booking',
          select: 'scheduledDate scheduledTime status paymentMethod paymentStatus serviceCategory service worker',
          populate: [
            { path: 'worker', select: 'name profileImage' },
            { path: 'service', select: 'title category' },
          ],
        })
        .populate('payment', 'amount status currency')
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
