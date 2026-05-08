const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    payment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Payment',
    },
    wallet: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Wallet',
    },
    type: {
      type: String,
      enum: ['charge', 'hold', 'release', 'refund', 'fee', 'dispute'],
      required: [true, 'Transaction type is required'],
    },
    amount: {
      type: Number,
      required: [true, 'Transaction amount is required'],
    },
    currency: {
      type: String,
      default: 'egp',
    },
    direction: {
      type: String,
      enum: ['credit', 'debit'],
      required: [true, 'Direction (credit/debit) is required'],
    },
    actor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    note: {
      type: String,
      trim: true,
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
  }
);

transactionSchema.pre('save', async function () {
  if (!this.isNew) {
    throw new Error('Transaction logs are immutable and cannot be updated.');
  }
});

transactionSchema.index({ payment: 1 });
transactionSchema.index({ wallet: 1, createdAt: -1 });
transactionSchema.index({ type: 1, createdAt: -1 });

const Transaction = mongoose.model('Transaction', transactionSchema);

module.exports = Transaction;
