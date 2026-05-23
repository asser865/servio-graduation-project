// ─── Purpose ──────────────────────────────────────────────────────────────────
// Stores card metadata (last4, expiry, cardType, label, isDefault) linked to a
// user. Full card numbers are never stored — only the last 4 digits sent by the
// frontend after client-side processing. Up to 3 cards per user (enforced by
// the controller). isDefault is managed by the controller, not auto-computed.
// ─────────────────────────────────────────────────────────────────────────────

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

    brand:                  { type: String },
    gateway:                { type: String, default: 'demo' },
    gatewayCustomerId:      { type: String },
    gatewayPaymentMethodId: { type: String },
  },
  { timestamps: true }
);

savedCardSchema.index(
  { userId: 1, last4: 1, expiry: 1 },
  { unique: true, name: 'unique_card_per_user' }
);

const SavedCard = mongoose.model('SavedCard', savedCardSchema);
module.exports = SavedCard;
