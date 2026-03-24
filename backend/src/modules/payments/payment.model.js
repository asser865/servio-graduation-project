// ─── Purpose ──────────────────────────────────────────────────────────────────
// Payment model — central record for every financial transaction on SERVIO.
// One Payment document is created per Booking (1:1 enforced by unique index).
//
// STATUS LIFECYCLE:
//   pending  → held       (Stripe PaymentIntent succeeded)
//   held     → released   (user confirmed service completion)
//   held     → refunded   (admin refund or dispute resolved as refund)
//   held     → disputed   (user/worker opened a dispute)
//   pending  → failed     (card declined or payment cancelled)
//   disputed → released   (dispute resolved in worker's favour)
//   disputed → refunded   (dispute resolved in user's favour)
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');

const PLATFORM_FEE_PCT = Number(process.env.PLATFORM_FEE_PERCENTAGE || 10) / 100;

const paymentSchema = new mongoose.Schema(
  {
    // ── Core references ────────────────────────────────────────────────────────
    booking: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'Booking',
      required: [true, 'Booking reference is required'],
      unique:   true, // Enforce: one payment per booking
    },
    user: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },
    worker: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: true,
    },

    // ── Financial fields ───────────────────────────────────────────────────────
    // All amounts are stored in the SMALLEST currency unit.
    // For EGP: 150.00 EGP → stored as 15000 (piastres).
    // For USD: $1.00 → stored as 100 (cents).
    // This is what Stripe expects and prevents floating-point rounding errors.
    amount: {
      type:     Number,
      required: true,
      min:      [1, 'Amount must be at least 1 (smallest currency unit)'],
    },
    platformFee: {
      type:    Number,
      default: 0,
    },
    workerEarning: {
      type:    Number,
      default: 0,
    },
    currency: {
      type:    String,
      default: process.env.STRIPE_CURRENCY || 'egp',
      lowercase: true,
    },

    // ── Status ─────────────────────────────────────────────────────────────────
    status: {
      type:    String,
      enum:    ['pending', 'held', 'released', 'refunded', 'failed', 'disputed'],
      default: 'pending',
    },
    paymentMethod: {
      type:    String,
      enum:    ['card', 'cash'],
      default: 'card',
    },

    // ── Gateway data ───────────────────────────────────────────────────────────
    gateway: {
      type:    String,
      default: 'stripe',
    },
    // Stripe PaymentIntent ID — created when user initiates payment
    gatewayPaymentIntentId: {
      type:   String,
      index:  true, // Indexed for fast webhook lookups
    },
    // Stripe Charge ID — populated after payment succeeds
    gatewayChargeId: {
      type: String,
    },
    // Stripe Refund ID — populated if payment is refunded
    gatewayRefundId: {
      type: String,
    },
    // Stripe-generated PDF/URL of the receipt
    receiptUrl: {
      type: String,
    },

    // ── Timestamps for audit ───────────────────────────────────────────────────
    releasedAt: {
      type: Date,
    },
    refundedAt: {
      type: Date,
    },

    // ── Error tracking ─────────────────────────────────────────────────────────
    failureReason: {
      type: String,
    },

    // ── Flexible audit metadata ────────────────────────────────────────────────
    // Stores raw gateway response data for compliance audits
    metadata: {
      type: mongoose.Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
  }
);

// ── Pre-save hook — auto-calculate fee split ───────────────────────────────────
// WHAT: Automatically calculates platformFee and workerEarning whenever
//       the payment amount changes.
// WHY:  Centralising this logic in the model ensures the fee split is ALWAYS
//       consistent. No service method can accidentally use the wrong percentage.
paymentSchema.pre('save', async function () {
  if (this.isModified('amount')) {
    this.platformFee   = Math.round(this.amount * PLATFORM_FEE_PCT);
    this.workerEarning = this.amount - this.platformFee;
  }
});

// ── Static method — convenience finder ────────────────────────────────────────
// WHAT: Finds a payment for a booking and populates user/worker references.
paymentSchema.statics.findByBooking = function (bookingId) {
  return this.findOne({ booking: bookingId })
    .populate('user',    'name email')
    .populate('worker',  'name email')
    .populate('booking', 'scheduledDate address status');
};

const Payment = mongoose.model('Payment', paymentSchema);

module.exports = Payment;
