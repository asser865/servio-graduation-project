// ─── Purpose ──────────────────────────────────────────────────────────────────
// Payment routes — maps HTTP endpoints to payment controller functions.
//
// ════════════════════════════════════════════════════════════════════════════════
// ⚠️  CRITICAL: WEBHOOK ROUTE AND express.raw() ⚠️
//
// The Stripe webhook endpoint MUST receive the RAW (unparsed) request body.
// This is because Stripe signs the request body, and the signature check
// (verifyWebhookSignature) requires the exact bytes Stripe sent.
//
// If express.json() parses the body first, the buffer is converted to an
// object, the signature check FAILS, and ALL webhook events are rejected.
//
// HOW WE SOLVE THIS:
//   - The webhook route uses express.raw({ type: 'application/json' })
//     so the route gets req.body as a raw Buffer.
//   - All other routes use the global express.json() from app.js.
//   - In app.js, the payment router is registered BEFORE express.json()
//     is applied globally, or we apply express.raw() specifically to this route.
// ════════════════════════════════════════════════════════════════════════════════

const express    = require('express');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');
const controller = require('./payment.controller');

const router = express.Router();

// ── /api/v1/payments/webhook ──────────────────────────────────────────────────
// NO auth guard — Stripe calls this directly (not the user's browser).
// express.raw() parses body as Buffer instead of JSON — REQUIRED for Stripe.
router.post(
  '/webhook',
  express.raw({ type: 'application/json' }),
  controller.stripeWebhook
);

// ── All other payment routes — authenticated ───────────────────────────────────

// POST /payments/intent — user initiates payment
router.post(
  '/intent',
  protect,
  authorize('user'),
  controller.createPaymentIntent
);

// POST /payments/confirm/:bookingId — user confirms service done → releases escrow
router.post(
  '/confirm/:bookingId',
  protect,
  authorize('user'),
  controller.confirmCompletion
);

// GET /payments/booking/:bookingId — view payment for a booking
router.get(
  '/booking/:bookingId',
  protect,
  authorize('user', 'worker', 'admin'),
  controller.getMyPayment
);

// GET /payments/earnings — worker's earnings dashboard
router.get(
  '/earnings',
  protect,
  authorize('worker'),
  controller.getWorkerEarnings
);

// POST /payments/refund/:paymentId — admin refunds a payment
router.post(
  '/refund/:paymentId',
  protect,
  authorize('admin'),
  controller.adminRefund
);

// ── Dispute routes ─────────────────────────────────────────────────────────────

// POST /payments/disputes — user opens a dispute
router.post(
  '/disputes',
  protect,
  authorize('user'),
  controller.openDispute
);

// PATCH /payments/disputes/:id/resolve — admin resolves a dispute
router.patch(
  '/disputes/:id/resolve',
  protect,
  authorize('admin'),
  controller.resolveDispute
);

// GET /payments/disputes — admin views all disputes
router.get(
  '/disputes',
  protect,
  authorize('admin'),
  controller.getDisputes
);

module.exports = router;
