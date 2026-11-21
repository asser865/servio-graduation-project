const mongoose = require('mongoose');

const PLATFORM_FEE_PCT = Number(process.env.PLATFORM_FEE_PERCENTAGE || 10) / 100;

const paymentSchema = new mongoose.Schema(
  {
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: [true, 'Booking reference is required'],
      unique: true,
    },
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    worker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    amount: {
      type: Number,
      required: true,
      min: [1, 'Amount must be at least 1 (smallest currency unit)'],
    },
    platformFee: {
      type: Number,
      default: 0,
    },
    workerEarning: {
      type: Number,
      default: 0,
    },
    currency: {
      type: String,
      default: 'egp',
      lowercase: true,
    },
    status: {
      type: String,
      enum: ['pending', 'held', 'released', 'refunded', 'failed', 'disputed', 'partially_refunded'],
      default: 'pending',
    },
    paymentMethod: {
      type: String,
      enum: ['online', 'cash', 'card'],
      default: 'online',
    },
    gateway: {
      type: String,
      default: 'manual',
    },
    gatewayPaymentIntentId: {
      type: String,
      index: true,
    },
    gatewayChargeId: {
      type: String,
    },
    gatewayRefundId: {
      type: String,
    },
    receiptUrl: {
      type: String,
    },
    releasedAt: {
      type: Date,
    },
    refundedAt: {
      type: Date,
    },
    failureReason: {
      type: String,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
    },

    skipFeeCalc: {
      type: Boolean,
      default: false,
      select: false,
    },

    releaseRequestedAt:  { type: Date },
    releaseRequestedBy:  { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    releaseApprovedAt:   { type: Date },
    releaseApprovedBy:   { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

    gatewayId:       { type: String, default: 'demo' },
    gatewayIntentId: { type: String, index: true },
    lastError:       { code: String, message: String, at: Date },
    refundAttempts:  { type: Number, default: 0 },
    refundedAmount:  { type: Number, default: 0 },
    capturedAt:      { type: Date },
    capturedAmount:  { type: Number },
    creditApplied:       { type: Number, default: 0 },
    gatewayChargeAmount: { type: Number },
    heldAt:          { type: Date },
    lockedAt:        { type: Date },
    lockReason:      { type: String },
    lockedBy:        { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  {
    timestamps: true,
  }
);

paymentSchema.pre('save', async function () {
  if (this.isModified('amount') && !this.skipFeeCalc) {
    this.platformFee = Math.round(this.amount * PLATFORM_FEE_PCT);
    this.workerEarning = this.amount - this.platformFee;
  }
});

paymentSchema.statics.findByBooking = function (bookingId) {
  return this.findOne({ booking: bookingId })
    .populate('user', 'name email')
    .populate('worker', 'name email')
    .populate('booking', 'scheduledDate address status');
};

paymentSchema.index({ booking: 1, status: 1 });

const Payment = mongoose.model('Payment', paymentSchema);

module.exports = Payment;
