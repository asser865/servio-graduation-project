// ─── Purpose ──────────────────────────────────────────────────────────────────
// DisputeService — business logic for the dispute resolution flow.
// A dispute freezes escrow funds until an admin makes a decision.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const Booking         = require('../bookings/booking.model');
const Payment         = require('./payment.model');
const Dispute         = require('./dispute.model');
const Transaction     = require('./transaction.model');
const ApiError        = require('../../utils/ApiError');

// ── Lazy import to avoid circular dependency ──────────────────────────────────
// payment.service.js imports dispute.service.js, so we load paymentService
// lazily (inside methods) rather than at module load time.
let paymentService;
const getPaymentService = () => {
  if (!paymentService) paymentService = require('./payment.service');
  return paymentService;
};

class DisputeService {

  // ── 6a. openDispute ─────────────────────────────────────────────────────────
  // WHAT: User opens a dispute — freezes the held payment.
  // WHY:  If a user is unhappy with completed work, they shouldn't lose their
  //       money automatically. Freezing gives admin time to investigate.
  async openDispute(bookingId, userId, reason, evidence = []) {
    // Verify booking exists and belongs to this user
    const booking = await Booking.findById(bookingId);
    if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
    if (booking.user.toString() !== userId) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This booking does not belong to you.');
    }

    // Can only dispute a booking that is in_progress or completed
    if (!['in_progress', 'completed'].includes(booking.status)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot open a dispute for a booking with status '${booking.status}'.`
      );
    }

    // Verify payment exists and is in a state that can be disputed
    const payment = await Payment.findOne({ booking: bookingId });
    if (!payment) throw new ApiError(StatusCodes.NOT_FOUND, 'Payment not found for this booking.');
    if (payment.status !== 'held') {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot dispute a payment with status '${payment.status}'. Must be 'held'.`
      );
    }

    // Check no open dispute already exists
    const existingDispute = await Dispute.findOne({
      booking: bookingId,
      status:  { $in: ['open', 'reviewing'] },
    });
    if (existingDispute) {
      throw new ApiError(StatusCodes.CONFLICT, 'An open dispute already exists for this booking.');
    }

    // Create the dispute document
    const dispute = await Dispute.create({
      booking:      bookingId,
      payment:      payment._id,
      raisedBy:     userId,
      raisedByRole: 'user',
      reason,
      evidence,
    });

    // Freeze the payment
    payment.status = 'disputed';
    await payment.save();

    // Audit log
    await Transaction.create({
      payment:   payment._id,
      type:      'dispute',
      amount:    payment.amount,
      currency:  payment.currency,
      direction: 'debit',
      actor:     userId,
      note:      `Dispute opened for booking ${bookingId}. Reason: ${reason.substring(0, 50)}`,
    });

    return dispute;
  }

  // ── 6b. resolveDispute ──────────────────────────────────────────────────────
  // WHAT: Admin reviews evidence and makes a final decision.
  // HOW:  decision = 'refund' → user gets money back
  //       decision = 'release' → worker gets paid
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
      // Refund the user — cancels booking too
      await ps.refundPayment(dispute.payment._id.toString(), adminId, resolution);
      dispute.status = 'resolved_refund';
    } else {
      // Release to worker — marks service as successfully completed
      // We first need to ensure the booking is 'completed' for the release logic
      await Booking.findByIdAndUpdate(dispute.booking._id, { status: 'completed' });
      await ps.releasePaymentToWorker(
        dispute.booking._id.toString(),
        dispute.booking.user.toString()
      );
      dispute.status = 'resolved_release';
    }

    dispute.resolution = resolution;
    dispute.resolvedBy  = adminId;
    dispute.resolvedAt  = new Date();
    await dispute.save();

    return dispute;
  }

  // ── 6c. getDisputesByAdmin ──────────────────────────────────────────────────
  // WHAT: Admin view of all disputes with pagination and status filter.
  async getDisputesByAdmin({ status, page = 1, limit = 20 } = {}) {
    const filter = {};
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);

    const [disputes, total] = await Promise.all([
      Dispute.find(filter)
        .populate('booking',  'scheduledDate address status')
        .populate('payment',  'amount status currency')
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
        page:       Number(page),
        limit:      Number(limit),
        totalPages: Math.ceil(total / Number(limit)),
      },
    };
  }
}

module.exports = new DisputeService();
