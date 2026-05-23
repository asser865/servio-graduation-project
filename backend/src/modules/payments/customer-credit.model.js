const mongoose = require('mongoose');

const SOURCES = ['apology', 'refund_fallback', 'admin_grant', 'promo'];

const schema = new mongoose.Schema({
  customer:       { type: mongoose.Schema.Types.ObjectId, ref: 'User',    required: true, index: true },
  amount:         { type: Number, required: true, min: 0 },
  source:         { type: String, enum: SOURCES, required: true },
  reason:         { type: String },
  relatedPayment: { type: mongoose.Schema.Types.ObjectId, ref: 'Payment' },
  relatedBooking: { type: mongoose.Schema.Types.ObjectId, ref: 'Booking' },
  issuedBy:       { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  consumed:       { type: Number, default: 0 },
  expiresAt:      { type: Date },
}, { timestamps: true });

schema.virtual('balanceRemaining').get(function () { return this.amount - this.consumed; });
schema.set('toJSON', { virtuals: true });
schema.statics.SOURCES = SOURCES;

module.exports = mongoose.model('CustomerCredit', schema);
