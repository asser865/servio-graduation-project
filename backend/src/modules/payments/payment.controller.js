// ─── Purpose ──────────────────────────────────────────────────────────────────
// Payment controller — thin layer between HTTP and service logic.
// All business rules are in payment.service.js and dispute.service.js.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes }  = require('http-status-codes');
const paymentService   = require('./payment.service');
const disputeService   = require('./dispute.service');
const ApiResponse      = require('../../utils/ApiResponse');
const ApiError         = require('../../utils/ApiError');

// ── CREATE PAYMENT INTENT (User Only) ─────────────────────────────────────────
// WHAT: Starts the payment flow — creates Stripe PaymentIntent.
// HOW:  Returns clientSecret that frontend passes to Stripe.js.
// WHO:  Authenticated user only.
const createPaymentIntent = async (req, res) => {
  const { bookingId } = req.body;
  if (!bookingId) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'bookingId is required.');
  }

  const result = await paymentService.createPaymentIntent(bookingId, req.user.id);

  return ApiResponse.success(
    res, StatusCodes.CREATED,
    'Payment intent created. Use clientSecret to complete payment via Stripe.js.',
    result
  );
};

// ── STRIPE WEBHOOK ─────────────────────────────────────────────────────────────
// WHAT: Stripe calls this endpoint when payment events occur.
// CRITICAL: This route uses express.raw() — NOT express.json().
//           The raw body is required for Stripe signature verification.
// SECURITY: Never throw errors to the client (Stripe interprets non-200 as failure
//           and retries the webhook). Log errors internally instead.
const stripeWebhook = async (req, res) => {
  const signature = req.headers['stripe-signature'];

  if (!signature) {
    // Return 400 — invalid webhook, but don't crash
    return res.status(StatusCodes.BAD_REQUEST).json({ error: 'Missing stripe-signature header' });
  }

  try {
    // req.body is a raw Buffer because the route uses express.raw()
    await paymentService.handleWebhook(req.body, signature);
  } catch (err) {
    // Log internally but always return 200 to stop Stripe from retrying
    console.error('❌ Webhook processing error:', err.message);
    return res.status(StatusCodes.OK).json({ received: true, error: err.message });
  }

  // Stripe requires a fast 200 response — do not wait for business logic
  return res.status(StatusCodes.OK).json({ received: true });
};

// ── CONFIRM COMPLETION (User Only) ─────────────────────────────────────────────
// WHAT: User confirms the service is done → triggers escrow release to worker.
// WHO:  The user who owns the booking.
const confirmCompletion = async (req, res) => {
  const { bookingId } = req.params;
  const payment = await paymentService.releasePaymentToWorker(bookingId, req.user.id);

  return ApiResponse.success(
    res, StatusCodes.OK,
    'Service confirmed. Payment released to worker.',
    payment
  );
};

// ── GET MY PAYMENT (User / Worker / Admin) ────────────────────────────────────
// WHAT: Get payment details for a specific booking.
// WHO:  User sees own, Worker sees own, Admin sees all.
const getMyPayment = async (req, res) => {
  const { bookingId } = req.params;
  const payment = await paymentService.getPaymentByBooking(
    bookingId, req.user.id, req.user.role
  );

  return ApiResponse.success(res, StatusCodes.OK, 'Payment retrieved.', payment);
};

// ── GET WORKER EARNINGS (Worker Only) ─────────────────────────────────────────
// WHAT: Worker views their wallet summary and earnings history.
// HOW:  Supports ?dateFrom, ?dateTo, ?status filters.
const getWorkerEarnings = async (req, res) => {
  const result = await paymentService.getWorkerEarnings(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Earnings retrieved.', result);
};

// ── ADMIN REFUND (Admin Only) ─────────────────────────────────────────────────
// WHAT: Admin manually issues a full refund to the user.
// WHY:  Triggered outside the dispute flow when admin intervenes directly.
const adminRefund = async (req, res) => {
  const { paymentId } = req.params;
  const { reason }    = req.body;

  if (!reason) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund reason is required.');
  }

  const payment = await paymentService.refundPayment(paymentId, req.user.id, reason);
  return ApiResponse.success(res, StatusCodes.OK, 'Payment refunded successfully.', payment);
};

// ── OPEN DISPUTE (User Only) ──────────────────────────────────────────────────
// WHAT: User opens a dispute to freeze escrow and request admin review.
const openDispute = async (req, res) => {
  const { bookingId, reason, evidence } = req.body;
  if (!bookingId || !reason) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'bookingId and reason are required.');
  }

  const dispute = await disputeService.openDispute(
    bookingId, req.user.id, reason, evidence
  );
  return ApiResponse.success(res, StatusCodes.CREATED, 'Dispute opened successfully.', dispute);
};

// ── RESOLVE DISPUTE (Admin Only) ──────────────────────────────────────────────
// WHAT: Admin resolves a dispute by choosing to refund or release.
const resolveDispute = async (req, res) => {
  const { id }                  = req.params;
  const { resolution, decision } = req.body;

  if (!resolution || !decision) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'resolution and decision are required.');
  }

  const dispute = await disputeService.resolveDispute(
    id, req.user.id, resolution, decision
  );
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute resolved.', dispute);
};

// ── GET ALL DISPUTES (Admin Only) ─────────────────────────────────────────────
// WHAT: Paginated list of all disputes for admin review.
const getDisputes = async (req, res) => {
  const result = await disputeService.getDisputesByAdmin(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Disputes retrieved.', result);
};

module.exports = {
  createPaymentIntent,
  stripeWebhook,
  confirmCompletion,
  getMyPayment,
  getWorkerEarnings,
  adminRefund,
  openDispute,
  resolveDispute,
  getDisputes,
};
