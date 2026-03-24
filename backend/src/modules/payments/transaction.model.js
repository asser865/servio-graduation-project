// ─── Purpose ──────────────────────────────────────────────────────────────────
// Transaction Log model — an IMMUTABLE audit trail of every money movement.
// Think of this as a ledger: every debit and credit is recorded here and can
// never be edited or deleted.
//
// WHY immutable:
//   Financial regulations (and basic accounting) require that money movements
//   cannot be altered retroactively. The pre-save hook enforces this by throwing
//   if anyone tries to update an existing log entry.
//
// TYPES:
//   charge   → User's card was charged (payment intent created and captured)
//   hold     → Funds moved to escrow after payment succeeded
//   release  → Escrow released to worker after service confirmed
//   refund   → Money returned to user (dispute or admin refund)
//   fee      → Platform commission recorded separately for accounting
//   dispute  → Dispute opened, payment frozen
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    payment: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'Payment',
    },
    wallet: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'Wallet',  // Optional — not all events touch a wallet
    },
    type: {
      type:     String,
      enum:     ['charge', 'hold', 'release', 'refund', 'fee', 'dispute'],
      required: [true, 'Transaction type is required'],
    },
    amount: {
      type:     Number,
      required: [true, 'Transaction amount is required'],
    },
    currency: {
      type:    String,
      default: process.env.STRIPE_CURRENCY || 'egp',
    },
    direction: {
      type:     String,
      enum:     ['credit', 'debit'],
      required: [true, 'Direction (credit/debit) is required'],
    },
    actor: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'User', // Who triggered this event
    },
    note: {
      type: String,
      trim: true,
    },
  },
  {
    // No updatedAt — logs are immutable by design
    timestamps: { createdAt: true, updatedAt: false },
  }
);

// ── Pre-save hook — enforce immutability ──────────────────────────────────────
// WHAT: Prevents any modification to an existing transaction log.
// WHY:  If this.isNew is false, someone is calling .save() on an existing
//       document — that's an update, which we must block.
transactionSchema.pre('save', async function () {
  if (!this.isNew) {
    throw new Error('Transaction logs are immutable and cannot be updated.');
  }
});

// Index for reporting (by payment, by wallet, by type+date)
transactionSchema.index({ payment: 1 });
transactionSchema.index({ wallet: 1, createdAt: -1 });
transactionSchema.index({ type: 1, createdAt: -1 });

const Transaction = mongoose.model('Transaction', transactionSchema);

module.exports = Transaction;
