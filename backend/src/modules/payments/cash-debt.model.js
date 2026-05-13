const mongoose = require('mongoose');

const cashDebtSchema = new mongoose.Schema(
  {
    worker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: true,
      unique: true,
    },
    amount: {
      type: Number,
      required: true,
    },
    paidAmount: {
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
      enum: ['outstanding', 'partially_paid', 'paid'],
      default: 'outstanding',
    },
    autoDeductedAt: { type: Date },
    paidAt:         { type: Date },
    paidBy: {
      type: String,
      enum: ['auto_wallet', 'manual_admin'],
    },
    adminNote: { type: String },
  },
  { timestamps: true }
);

cashDebtSchema.index({ worker: 1, status: 1 });
cashDebtSchema.index({ worker: 1, createdAt: 1 });

const CashDebt = mongoose.model('CashDebt', cashDebtSchema);

module.exports = CashDebt;
