// ─── Purpose ──────────────────────────────────────────────────────────────────
// Booking is the core transactional record — it links a user, a worker,
// and a service with a lifecycle managed by the status enum.
// The status machine is enforced in booking.service.js, not the schema.
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');

const BOOKING_STATUSES = [
  'pending', 'accepted', 'en_route', 'arrived', 'rejected', 'in_progress',
  'awaiting_customer_confirmation', 'pending_admin_review',
  'completed', 'cancelled', 'disputed',
];
const PAYMENT_METHODS = ['cash', 'card', 'online'];

const bookingSchema = new mongoose.Schema(
  {
    user: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'User is required'],
    },

    worker: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'Worker is required'],
    },

    // Specific sub-service (optional — null for general category bookings)
    service: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'Service',
    },

    // Main category string (e.g. 'plumbing') — always set, required
    serviceCategory: {
      type:     String,
      trim:     true,
      required: [true, 'Service category is required'],
    },

    // Human-readable name shown in reviews, receipts, notifications
    serviceName: {
      type:  String,
      trim:  true,
      default: '',
    },

    status: {
      type:    String,
      enum:    BOOKING_STATUSES,
      default: 'pending',
    },

    scheduledDate: {
      type:     Date,
      required: [true, 'Scheduled date is required'],
    },

    address: {
      type:     String,
      required: [true, 'Address is required'],
      trim:     true,
    },

    description: {
      type:  String,
      trim:  true,
      maxlength: [1000, 'Description cannot exceed 1000 characters'],
    },

    images: {
      type:    [String],
      default: [],
    },

    totalPrice: {
      type:  Number,
      min:   [0, 'Price cannot be negative'],
    },

    paymentMethod: {
      type:     String,
      enum:     PAYMENT_METHODS,
      default:  'cash',
      required: [true, 'Payment method is required'],
    },

    paymentStatus: {
      type:    String,
      enum:    [
        'unpaid', 'held', 'released', 'refunded', 'failed', 'disputed',
        'cash_pending_settlement', 'cash_settled', 'not_required',
        // Legacy (kept for migration safety — no longer written by new code):
        'demo_pending', 'cash_pending', 'paid',
      ],
      default: 'unpaid',
    },

    platformFeeRate: {
      type:    Number,
      min:     [0, 'Platform fee rate cannot be negative'],
      default: 10,
    },

    platformFeeAmount: {
      type:    Number,
      min:     [0, 'Platform fee cannot be negative'],
      default: 0,
    },

    estimatedTotal: {
      type:    Number,
      min:     [0, 'Estimated total cannot be negative'],
      default: 0,
    },

    scheduledTime: {
      type:    String,
      trim:    true,
      default: '',
    },

    // 4-digit PIN generated at booking creation — customer shows this to worker to start the job
    pin: {
      type:    String,
      default: () => String(Math.floor(1000 + Math.random() * 9000)),
    },

    // Worker can add notes on completion (e.g., materials used)
    workerNotes: {
      type:  String,
      trim:  true,
    },

    // Required when status is cancelled or rejected
    cancellationReason: {
      type:  String,
      trim:  true,
    },

    savedCard: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'SavedCard',
    },

    paymentMeta: {
      savedCardId: { type: mongoose.Schema.Types.ObjectId, ref: 'SavedCard' },
      last4:       { type: String },
      cardType:    { type: String },
      expiry:      { type: String },
      label:       { type: String },
    },

    paymentDeadline: {
      type: Date,
    },

    customerConfirmedAt: {
      type: Date,
    },

    customerConfirmedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  { timestamps: true }
);

// ── Indexes for common queries ────────────────────────────────────────────────
bookingSchema.index({ user:   1, status: 1 });
bookingSchema.index({ worker: 1, status: 1 });

// Prevents double-booking at the DB level (application-layer findOne is not atomic)
bookingSchema.index(
  { worker: 1, scheduledDate: 1, scheduledTime: 1 },
  { unique: true, partialFilterExpression: { status: { $in: ['pending', 'accepted', 'en_route', 'arrived', 'in_progress'] } } }
);

bookingSchema.index({ status: 1, paymentMethod: 1, customerConfirmedAt: -1 });

const Booking = mongoose.model('Booking', bookingSchema);

module.exports = Booking;
