'use strict';

const mongoose = require('mongoose');

const notifyRequestSchema = new mongoose.Schema(
  {
    email: {
      type:     String,
      required: true,
      trim:     true,
      lowercase: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref:  'User',
      default: null,
    },
    serviceCategory: {
      type:     String,
      required: true,
      trim:     true,
      lowercase: true,
    },
    serviceArea: {
      type:    String,
      trim:    true,
      default: '',
    },
    fulfilledAt: {
      type:    Date,
      default: null,
    },
  },
  { timestamps: true }
);

// TTL index: auto-delete unfulfilled requests after 30 days
notifyRequestSchema.index({ createdAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 30 });

// Prevent duplicate subscriptions for the same email + category
notifyRequestSchema.index({ email: 1, serviceCategory: 1 }, { unique: true, partialFilterExpression: { fulfilledAt: null } });

module.exports = mongoose.model('NotifyRequest', notifyRequestSchema);
