// ─── Purpose ──────────────────────────────────────────────────────────────────
// Wallet model — tracks a worker's financial state on the platform.
// Each worker has exactly ONE wallet (enforced by unique index on worker).
//
// BALANCE BREAKDOWN:
//   balance        → Funds available for withdrawal (fully earned, released)
//   pendingBalance → Funds held in escrow (payment received but service not
//                    yet confirmed). The worker can see it but can't withdraw.
//   totalEarned    → Lifetime accumulation — never decreases (for stats)
//   totalWithdrawn → Lifetime withdrawals (for stats)
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');
const ApiError = require('../../utils/ApiError');
const { StatusCodes } = require('http-status-codes');

const walletSchema = new mongoose.Schema(
  {
    worker: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'Worker reference is required'],
      unique:   true, // One wallet per worker
    },

    // Current spendable/withdrawable balance (in smallest currency unit)
    balance: {
      type:    Number,
      default: 0,
      min:     [0, 'Balance cannot be negative'],
    },

    // Lifetime earnings accumulator — only ever increases
    totalEarned: {
      type:    Number,
      default: 0,
      min:     0,
    },

    // Lifetime withdrawal accumulator — only ever increases
    totalWithdrawn: {
      type:    Number,
      default: 0,
      min:     0,
    },

    // Money held for jobs in progress — not yet accessible
    pendingBalance: {
      type:    Number,
      default: 0,
      min:     [0, 'Pending balance cannot be negative'],
    },

    currency: {
      type:    String,
      default: process.env.STRIPE_CURRENCY || 'egp',
      lowercase: true,
    },
  },
  {
    timestamps: true,
  }
);

// ── Instance method: credit ───────────────────────────────────────────────────
// WHAT: Add funds to the worker's available balance (e.g. manual bonus).
// HOW:  Adds to both balance and totalEarned.
walletSchema.methods.credit = async function (amount) {
  this.balance     += amount;
  this.totalEarned += amount;
  return this.save();
};

// ── Instance method: debit ────────────────────────────────────────────────────
// WHAT: Subtract funds from balance (e.g. withdrawal).
// WHY:  Throws if insufficient — prevents negative balances at the model level.
walletSchema.methods.debit = async function (amount) {
  if (this.balance < amount) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Insufficient wallet balance. Available: ${this.balance}, Requested: ${amount}.`
    );
  }
  this.balance       -= amount;
  this.totalWithdrawn += amount;
  return this.save();
};

// ── Instance method: addPending ───────────────────────────────────────────────
// WHAT: Move funds into pendingBalance when a booking payment is received.
// WHY:  Funds are "visible" to the worker but locked until service is confirmed.
walletSchema.methods.addPending = async function (amount) {
  this.pendingBalance += amount;
  return this.save();
};

// ── Instance method: releasePending ──────────────────────────────────────────
// WHAT: Graduate funds from pendingBalance → balance after service confirmation.
// WHY:  This is the escrow release step. Two fields updated atomically.
walletSchema.methods.releasePending = async function (amount) {
  if (this.pendingBalance < amount) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Insufficient pending balance. Pending: ${this.pendingBalance}, Releasing: ${amount}.`
    );
  }
  this.pendingBalance -= amount;
  this.balance        += amount;
  this.totalEarned    += amount;
  return this.save();
};

// ── Instance method: deductPending ───────────────────────────────────────────
// WHAT: Remove from pendingBalance when a booking is refunded.
// WHY:  The funds were never truly the worker's — they go back to the user.
walletSchema.methods.deductPending = async function (amount) {
  if (this.pendingBalance < amount) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Insufficient pending balance. Pending: ${this.pendingBalance}, Deducting: ${amount}.`
    );
  }
  this.pendingBalance -= amount;
  return this.save();
};

const Wallet = mongoose.model('Wallet', walletSchema);

module.exports = Wallet;
