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
    debtType: {
      type: String,
      enum: ['platform_fee', 'refund_recovery', 'penalty'],
      default: 'platform_fee',
    },
    refundRecipientAmount: {
      type: Number,
      default: 0,
    },
    relatedDispute: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Dispute',
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
    remaining: { type: Number },
    settlementMethod: {
      type: String,
      enum: ['auto_offset', 'wallet_balance', 'instapay', 'vodafone_cash', 'bank_transfer', 'cash_to_office', 'card', 'admin_override'],
    },
    settlementRef: { type: mongoose.Schema.Types.ObjectId, ref: 'DebtSettlement' },
  },
  { timestamps: true }
);

cashDebtSchema.index({ worker: 1, status: 1 });
cashDebtSchema.index({ worker: 1, createdAt: 1 });

cashDebtSchema.pre('save', async function () {
  if (this.isNew && (this.remaining === undefined || this.remaining === null)) {
    this.remaining = this.amount;
  }
});

const CashDebt = mongoose.model('CashDebt', cashDebtSchema);

module.exports = CashDebt;
