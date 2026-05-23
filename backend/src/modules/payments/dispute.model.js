const mongoose = require('mongoose');

const SLA_FIRST_RESPONSE_HOURS = Number(process.env.DISPUTE_SLA_FIRST_RESPONSE_HOURS || 24);
const SLA_RESOLVE_HOURS = Number(process.env.DISPUTE_SLA_RESOLVE_HOURS || 72);

const evidenceSchema = new mongoose.Schema(
  {
    url: { type: String, required: true, trim: true },
    name: { type: String, trim: true },
    mime: { type: String, trim: true },
    size: { type: Number },
    uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    uploadedByRole: { type: String, enum: ['user', 'worker', 'admin'] },
    uploadedAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

const historyEntrySchema = new mongoose.Schema(
  {
    status: { type: String, required: true },
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    byRole: { type: String, enum: ['user', 'worker', 'admin', 'system'] },
    note: { type: String, trim: true },
    at: { type: Date, default: Date.now },
  },
  { _id: false }
);

const internalNoteSchema = new mongoose.Schema(
  {
    by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    note: { type: String, required: true, trim: true },
    at: { type: Date, default: Date.now },
  },
  { _id: false }
);

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
    severity: {
      type: String,
      enum: ['low', 'medium', 'high', 'critical'],
      default: 'medium',
    },
    estimatedDamages: {
      type: Number,
      min: 0,
    },
    // Mixed type for backward compatibility with legacy string[] evidence.
    // New writes use evidenceSchema shape via service-layer normalization.
    evidence: {
      type: [mongoose.Schema.Types.Mixed],
      default: [],
    },
    status: {
      type: String,
      enum: [
        'open',
        'reviewing',
        'awaiting_evidence',
        'resolved_refund',
        'resolved_release',
        'resolved_partial',
        'resolved_redo',
        'appealed',
        'closed',
        'escalated',
      ],
      default: 'open',
    },
    resolution: {
      type: String,
    },
    decision: {
      type: String,
      enum: ['refund', 'release', 'partial_refund', 'redo'],
    },
    refundAmount: {
      type: Number,
      min: 0,
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    resolvedAt: {
      type: Date,
    },
    assignedAdmin: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    slaFirstResponseDueAt: { type: Date },
    slaResolveDueAt: { type: Date },
    firstResponseAt: { type: Date },
    slaBreachedAt: { type: Date },
    escalatedAt: { type: Date },
    history: { type: [historyEntrySchema], default: [] },
    internalNotes: { type: [internalNoteSchema], default: [] },
    evidenceRequestedFrom: {
      type: String,
      enum: ['user', 'worker', 'both', null],
      default: null,
    },
    evidenceRequestedAt: { type: Date },
    appealStatus: {
      type: String,
      enum: [null, 'pending', 'reviewing', 'upheld', 'overturned'],
      default: null,
    },
    appealReason: { type: String, trim: true },
    appealedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    appealedByRole: { type: String, enum: ['user', 'worker'] },
    appealedAt: { type: Date },
    appealResolvedAt: { type: Date },
  },
  {
    timestamps: true,
  }
);

disputeSchema.index({ status: 1, createdAt: -1 });
disputeSchema.index({ booking: 1 });
disputeSchema.index({ assignedAdmin: 1, status: 1 });
disputeSchema.index({ slaResolveDueAt: 1, status: 1 });

disputeSchema.statics.SLA_FIRST_RESPONSE_HOURS = SLA_FIRST_RESPONSE_HOURS;
disputeSchema.statics.SLA_RESOLVE_HOURS = SLA_RESOLVE_HOURS;

const Dispute = mongoose.model('Dispute', disputeSchema);

module.exports = Dispute;
