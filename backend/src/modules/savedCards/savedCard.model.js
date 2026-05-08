const mongoose = require('mongoose');

const savedCardSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    last4: {
      type: String,
      required: [true, 'Last 4 digits are required'],
      match: [/^\d{4}$/, 'last4 must be exactly 4 digits'],
    },
    expiry: {
      type: String,
      required: [true, 'Expiry is required'],
      match: [/^\d{2}\/\d{2}$/, 'Expiry must be MM/YY'],
    },
    cardType: {
      type: String,
      enum: ['visa', 'mastercard', 'amex', 'other'],
      default: 'other',
    },
    label: {
      type: String,
      trim: true,
      maxlength: 40,
    },
    isDefault: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

const SavedCard = mongoose.model('SavedCard', savedCardSchema);
module.exports = SavedCard;
