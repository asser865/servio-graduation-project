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
  'cancelled_no_show', 'customer_no_show', 'worker_no_show', 're_pooling',
  'payment_refused', 'refusal_under_investigation', 'incomplete_review', 'customer_disputed',
  'customer_declined',
];
const PAYMENT_METHODS = ['cash', 'card', 'online'];

const COMPLETION_OUTCOME_VALUES = ['customer_paid', 'customer_refused_payment', 'could_not_complete', 'customer_declined_work'];
const CUSTOMER_FEEDBACK_ACTIONS = ['confirmed', 'reported_issue', 'system_auto_confirmed'];
const CUSTOMER_ISSUE_REASONS = [
  'work_not_done',
  'work_damaged_property',
  'overcharged',
  'tech_unprofessional',
  'incomplete',
  'tech_did_not_arrive',
  'other',
];

const completionOutcomeSchema = new mongoose.Schema({
  outcome: { type: String, enum: COMPLETION_OUTCOME_VALUES },
  submittedAt: { type: Date },
  beforePhotos: { type: [String], default: [] },
  afterPhotos: { type: [String], default: [] },
  workerNotes: { type: String, trim: true },
  materialsUsed: { type: String, trim: true },
  refusalReason: { type: String, trim: true },
  couldNotCompleteReason: { type: String, trim: true },
}, { _id: false });

const customerFeedbackSchema = new mongoose.Schema({
  action: { type: String, enum: CUSTOMER_FEEDBACK_ACTIONS },
  issueReason: { type: String, enum: CUSTOMER_ISSUE_REASONS },
  rating: { type: Number, min: 1, max: 5 },
  notes: { type: String, trim: true },
  evidenceImages: { type: [String], default: [] },
  submittedAt: { type: Date },
  confirmedVia: { type: String, enum: ['customer', 'system_auto'] },
}, { _id: false });

const riskFlagSchema = new mongoose.Schema({
  code: { type: String, required: true, trim: true },
  reason: { type: String, trim: true },
  status: { type: String, enum: ['unresolved', 'resolved'], default: 'unresolved' },
  createdAt: { type: Date, default: Date.now },
  resolvedAt: { type: Date },
}, { _id: false });

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

    // ── Pricing snapshots (immutable, set at creation) ─────────────────────
    startsFromSnapshot: { type: Number, default: 0, min: 0 },
    seedRangeSnapshot:  { min: { type: Number, default: 0 }, max: { type: Number, default: 0 } },
    holdCeiling:        { type: Number, default: 0, min: 0 },

    // ── Final itemized invoice (set at completion) ─────────────────────────
    laborAmount: { type: Number, default: 0, min: 0 },
    materials: [{
      name:      { type: String, trim: true, required: true },
      qty:       { type: Number, default: 1, min: 0 },
      unitPrice: { type: Number, default: 0, min: 0 },
      reason:    { type: String, trim: true },
      photo:     { type: String },
    }],
    subtotal:    { type: Number, default: 0, min: 0 },   // money(labor + Σ materials) = worker earning
    platformFee: { type: Number, default: 0, min: 0 },   // money(labor × rate) — LABOR ONLY (Adj.14)
    vat:         { type: Number, default: 0, min: 0 },   // VAT inside grandTotal: money(grandTotal − grandTotal/(1+rate)) — reporting only (Guard B)
    grandTotal:  { type: Number, default: 0, min: 0 },   // money(subtotal + platformFee) = captured amount (VAT-inclusive)
    isOverBand:  { type: Boolean, default: false, index: true },

    scheduledTime: {
      type:    String,
      trim:    true,
      default: '',
    },

    // Planned UTC instant for job start (scheduledDate + scheduledTime resolved via
    // worker.timezone). Source of truth for overlap math.
    scheduledStart: {
      type: Date,
      index: true,
    },

    // scheduledStart + estimatedDurationMin + travelBufferMin (snapshot at create/accept).
    // Source of truth for the upper bound of the overlap window.
    scheduledEnd: {
      type: Date,
      index: true,
    },

    // Snapshot at accept time — defends against retro-shifting if Service duration changes later.
    estimatedDurationMin: {
      type: Number,
      min:  [15, 'Duration cannot be less than 15 minutes'],
      max:  [480, 'Duration cannot exceed 8 hours'],
    },

    // Snapshot at create time, taken from Settings.travelBufferMin.
    travelBufferMin: {
      type:    Number,
      min:     [0, 'Travel buffer cannot be negative'],
      default: 30,
    },

    // Set when status transitions to in_progress (PIN entry).
    actualStartedAt: {
      type:    Date,
      default: null,
    },

    // actualStartedAt + estimatedDurationMin, re-stamped on each extension.
    estimatedFinishAt: {
      type:    Date,
      default: null,
    },

    // Count of auto-extensions applied (lazy, computed at read time).
    extensionCount: {
      type:    Number,
      default: 0,
      min:     0,
    },

    // Audit trail of each extension.
    extensionLog: {
      type: [
        new mongoose.Schema(
          {
            at:       { type: Date,   required: true },
            addedMin: { type: Number, required: true },
          },
          { _id: false }
        ),
      ],
      default: [],
    },

    // Set when admin review is needed (e.g., stuck in_progress past 2× + buffer).
    needsAdminReview: {
      type:    Boolean,
      default: false,
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

    workerCompletionImages: {
      type:    [String],
      default: [],
    },

    // Required when status is cancelled or rejected
    cancellationReason: {
      type:  String,
      trim:  true,
    },

    // Cancellation metadata (Plan 3 Task 3+)
    acceptedAt:    { type: Date },
    cancelledAt:   { type: Date },
    cancelledBy:   { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    cancelledByRole: { type: String, enum: ['user', 'worker', 'admin', 'system'] },
    lateFeeAmount: { type: Number, default: 0 },

    // Re-pool tracking after worker cancel (Task 5)
    rePooledFrom: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    rePooledAt:   { type: Date },

    // No-show metadata (Task 7)
    noShowMarkedAt:   { type: Date },
    noShowMarkedBy:   { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    noShowEvidence:   { type: [String], default: [] },

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

    // Stamped when tech clicks "Mark Complete" → awaiting_customer_confirmation
    actualCompletedAt: {
      type:    Date,
      default: null,
    },

    // Server-computed minutes from actualStartedAt → actualCompletedAt. Never editable.
    actualBilledMin: {
      type:    Number,
      default: null,
    },

    // True when actualBilledMin exceeds category cap or anomaly threshold
    flaggedForReview: {
      type:    Boolean,
      default: false,
      index:   true,
    },

    flagReason: {
      type:  String,
      trim:  true,
    },
    enhancedReviewReason: {
      type: String,
      enum: ['HIGH_VALUE', 'SAFEGUARD_BLOCK'],
    },
    riskFlags: { type: [riskFlagSchema], default: [] },

    completedAt: { type: Date },
    releasedAt: { type: Date },
    cashCollectedAt: { type: Date },
    customerConfirmAutoAt: { type: Date },
    customerConfirmedVia: {
      type: String,
      enum: ['customer', 'system_auto', 'admin'],
    },
    completionNotes:  { type: String },
    completionPhotos: { type: [String], default: [] },
    confirmRemindersSent: { type: [Number], default: [] },

    // ── Completion outcome (worker submits) ────────────────────────────────
    completionOutcome: { type: completionOutcomeSchema, default: () => ({}) },

    // ── Customer feedback (confirm or report issue) ────────────────────────
    customerFeedback: { type: customerFeedbackSchema, default: () => ({}) },

    // ── Refusal-of-payment verification flow ───────────────────────────────
    refusalVerification: {
      status: {
        type: String,
        enum: ['pending', 'customer_confirmed_refusal', 'customer_disputes_refusal'],
        default: undefined,
      },
      notifiedAt: { type: Date },
      respondedAt: { type: Date },
      customerResponse: { type: String, trim: true },
    },
  },
  { timestamps: true }
);

bookingSchema.pre('save', async function () {
  if (this.isModified('status') && this.status === 'completed' && !this.completedAt) {
    this.completedAt = new Date();
  }
  if (this.isModified('paymentStatus') && this.paymentStatus === 'released' && !this.releasedAt) {
    this.releasedAt = new Date();
  }
});

// ── Indexes for common queries ────────────────────────────────────────────────
bookingSchema.index({ user:   1, status: 1 });
bookingSchema.index({ worker: 1, status: 1 });

// New overlap-aware indexes. The old (worker, scheduledDate, scheduledTime) unique
// partial index is dropped — overlap is now enforced in code via interval-intersect,
// because slots are no longer fixed-hour buckets.
bookingSchema.index({ worker: 1, status: 1, scheduledEnd: 1 });
bookingSchema.index({ worker: 1, status: 1, scheduledStart: 1 });

bookingSchema.index({ status: 1, paymentMethod: 1, customerConfirmedAt: -1 });

const Booking = mongoose.model('Booking', bookingSchema);

module.exports = Booking;
module.exports.COMPLETION_OUTCOME_VALUES = COMPLETION_OUTCOME_VALUES;
module.exports.CUSTOMER_FEEDBACK_ACTIONS = CUSTOMER_FEEDBACK_ACTIONS;
module.exports.CUSTOMER_ISSUE_REASONS = CUSTOMER_ISSUE_REASONS;
