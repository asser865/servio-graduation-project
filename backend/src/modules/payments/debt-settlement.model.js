const mongoose = require('mongoose');

const debtSettlementSchema = new mongoose.Schema(
  {
    worker: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    debts: [{ type: mongoose.Schema.Types.ObjectId, ref: 'CashDebt' }],
    totalAmount: { type: Number, required: true, min: 0.01 },
    method: {
      type: String,
      enum: ['instapay', 'vodafone_cash', 'bank_transfer', 'cash_to_office'],
      required: true,
    },
    reference: { type: String, required: true },
    proofUrl: { type: String },
    status: {
      type: String,
      enum: ['pending_verification', 'verified', 'rejected'],
      default: 'pending_verification',
      index: true,
    },
    submittedAt: { type: Date, default: Date.now },
    verifiedAt: { type: Date },
    verifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    rejectionReason: { type: String },
    adminNote: { type: String },
  },
  { timestamps: true },
);

module.exports = mongoose.model('DebtSettlement', debtSettlementSchema);
