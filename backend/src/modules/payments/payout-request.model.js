const mongoose = require('mongoose');

const payoutSchema = new mongoose.Schema(
  {
    worker: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    amount: { type: Number, required: true, min: 0.01 },
    status: {
      type: String,
      enum: ['pending', 'approved', 'paid', 'rejected'],
      default: 'pending',
      index: true,
    },
    payoutMethod: {
      type: String,
      enum: ['bank', 'instapay', 'vodafone_cash', 'orange_cash'],
      required: true,
    },
    payoutDetails: { type: mongoose.Schema.Types.Mixed },
    transactionRef: { type: String },
    adminNote: { type: String },
    rejectionReason: { type: String },
    requestedAt: { type: Date, default: Date.now },
    processedAt: { type: Date },
    processedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('PayoutRequest', payoutSchema);
