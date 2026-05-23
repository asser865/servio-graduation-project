const mongoose = require('mongoose');

const preferencesSchema = new mongoose.Schema(
  {
    user: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      unique:   true,
      required: true,
    },
    channels: {
      email: { type: Boolean, default: true },
      inApp: { type: Boolean, default: true },
      push:  { type: Boolean, default: true },
      sms:   { type: Boolean, default: false },
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('NotificationPreference', preferencesSchema);
