const mongoose = require('mongoose');

const REASONS = ['late_cancel', 'no_show', 'rejected_after_accept'];

const schema = new mongoose.Schema({
  worker:    { type: mongoose.Schema.Types.ObjectId, ref: 'User',    required: true, index: true },
  booking:   { type: mongoose.Schema.Types.ObjectId, ref: 'Booking', required: true },
  reason:    { type: String, enum: REASONS, required: true },
  issuedAt:  { type: Date, default: Date.now },
  expiresAt: { type: Date },
  notes:     { type: String },
}, { timestamps: true });

schema.index({ worker: 1, issuedAt: -1 });
schema.statics.REASONS = REASONS;

module.exports = mongoose.model('WorkerStrike', schema);
