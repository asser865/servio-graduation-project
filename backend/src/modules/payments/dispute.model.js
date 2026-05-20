const mongoose = require('mongoose');

const disputeSchema = new mongoose.Schema(
  {
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: [true, 'Booking reference is required'],
    },
    payment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Payment',
    },
    raisedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'The user who raised this dispute is required'],
    },
    raisedByRole: {
      type: String,
      enum: ['user', 'worker', 'admin'],
      required: true,
    },
    reason: {
      type: String,
      required: [true, 'Dispute reason is required'],
      minlength: [20, 'Dispute reason must be at least 20 characters'],
      trim: true,
    },
    category: {
      type: String,
      enum: ['quality', 'incomplete', 'damage', 'pricing', 'safety', 'no_show', 'other'],
      default: 'other',
    },
    evidence: {
      type: [String],
      default: [],
    },
    status: {
      type: String,
      enum: ['open', 'reviewing', 'resolved_refund', 'resolved_release'],
      default: 'open',
    },
    resolution: {
      type: String,
    },
    decision: {
      type: String,
      enum: ['refund', 'release'],
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    resolvedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

disputeSchema.index({ status: 1, createdAt: -1 });
disputeSchema.index({ booking: 1 });

const Dispute = mongoose.model('Dispute', disputeSchema);

module.exports = Dispute;
