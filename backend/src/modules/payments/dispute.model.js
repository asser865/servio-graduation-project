// ─── Purpose ──────────────────────────────────────────────────────────────────
// Dispute model — records when a user or worker contests a transaction.
// A dispute freezes the payment (status → 'disputed') until an admin resolves it.
//
// STATUS LIFECYCLE:
//   open         → Dispute just submitted (payment is frozen)
//   reviewing    → Admin acknowledged and is investigating
//   resolved_refund   → Admin decided: refund the user
//   resolved_release  → Admin decided: release funds to worker
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');

const disputeSchema = new mongoose.Schema(
  {
    // ── References ─────────────────────────────────────────────────────────────
    booking: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'Booking',
      required: [true, 'Booking reference is required'],
    },
    payment: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'Payment',
      required: [true, 'Payment reference is required'],
    },
    raisedBy: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'The user who raised this dispute is required'],
    },
    raisedByRole: {
      type:    String,
      enum:    ['user', 'worker'],
      required: true,
    },

    // ── Dispute content ────────────────────────────────────────────────────────
    reason: {
      type:      String,
      required:  [true, 'Dispute reason is required'],
      minlength: [20, 'Dispute reason must be at least 20 characters'],
      trim:      true,
    },
    evidence: {
      type:    [String], // Image URLs or document links
      default: [],
    },

    // ── Status ─────────────────────────────────────────────────────────────────
    status: {
      type:    String,
      enum:    ['open', 'reviewing', 'resolved_refund', 'resolved_release'],
      default: 'open',
    },

    // ── Resolution (filled by admin) ───────────────────────────────────────────
    resolution: {
      type: String,
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'User',
    },
    resolvedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Index for fast admin queries by status
disputeSchema.index({ status: 1, createdAt: -1 });
disputeSchema.index({ booking: 1 });

const Dispute = mongoose.model('Dispute', disputeSchema);

module.exports = Dispute;
