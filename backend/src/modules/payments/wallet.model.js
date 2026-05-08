const mongoose = require('mongoose');
const ApiError = require('../../utils/ApiError');
const { StatusCodes } = require('http-status-codes');

const walletSchema = new mongoose.Schema(
  {
    worker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Worker reference is required'],
      unique: true,
    },
    balance: {
      type: Number,
      default: 0,
      min: [0, 'Balance cannot be negative'],
    },
    totalEarned: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalWithdrawn: {
      type: Number,
      default: 0,
      min: 0,
    },
    pendingBalance: {
      type: Number,
      default: 0,
      min: [0, 'Pending balance cannot be negative'],
    },
    currency: {
      type: String,
      default: 'egp',
      lowercase: true,
    },
  },
  {
    timestamps: true,
  }
);

walletSchema.methods.credit = async function (amount) {
  this.balance += amount;
  this.totalEarned += amount;
  return this.save();
};

walletSchema.methods.debit = async function (amount) {
  if (this.balance < amount) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Insufficient wallet balance. Available: ${this.balance}, Requested: ${amount}.`
    );
  }
  this.balance -= amount;
  this.totalWithdrawn += amount;
  return this.save();
};

walletSchema.methods.addPending = async function (amount) {
  this.pendingBalance += amount;
  return this.save();
};

walletSchema.methods.releasePending = async function (amount) {
  if (this.pendingBalance < amount) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Insufficient pending balance. Pending: ${this.pendingBalance}, Releasing: ${amount}.`
    );
  }
  this.pendingBalance -= amount;
  this.balance += amount;
  this.totalEarned += amount;
  return this.save();
};

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
