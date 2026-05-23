const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  number:   { type: String, required: true, unique: true, index: true },
  payment:  { type: mongoose.Schema.Types.ObjectId, ref: 'Payment', required: true },
  booking:  { type: mongoose.Schema.Types.ObjectId, ref: 'Booking' },
  customer: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  worker:   { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  subtotal: { type: Number, required: true },
  vatRate:  { type: Number, default: 0.14 },
  vat:      { type: Number, required: true },
  total:    { type: Number, required: true },
  currency: { type: String, default: 'EGP' },
  issuedAt: { type: Date, default: Date.now },
  pdfPath:  { type: String },
}, { timestamps: true });

module.exports = mongoose.models.Invoice || mongoose.model('Invoice', schema);
