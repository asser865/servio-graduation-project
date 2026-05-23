'use strict';

const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      required: true,
      enum: [
        'booking_created',
        'booking_accepted',
        'booking_rejected',
        'booking_en_route',
        'booking_arrived',
        'booking_in_progress',
        'booking_completed',
        'booking_cancelled',
        'booking_action_required',
        'payment_released',
        'payment_refunded',
        'dispute_opened',
        'dispute_resolved',
        'dispute_evidence_requested',
        'dispute_evidence_added',
        'dispute_appealed',
        'dispute_status_changed',
        'support_issue_opened',
        'support_issue_updated',
        'support_issue_resolved',
        'tech_available',
        'review_received',
        'payment_held',
        'settlement_verified',
        'settlement_rejected',
        'payout_approved',
        'payout_paid',
        'credit_issued',
        'booking_no_show',
        'dispute_escalated',
        'system',
      ],
    },
    title: { type: String, required: true, maxlength: 120 },
    body:  { type: String, required: true, maxlength: 280 },
    referenceId:  { type: String, default: null },   // bookingId, reviewId, etc.
    referenceUrl: { type: String, default: null },   // frontend deep-link
    isRead: { type: Boolean, default: false, index: true },
  },
  { timestamps: true }
);

// Compound index for efficient per-user unread count
notificationSchema.index({ userId: 1, isRead: 1, createdAt: -1 });

// Auto-delete read notifications older than 90 days; unread kept indefinitely
notificationSchema.index(
  { createdAt: 1 },
  { expireAfterSeconds: 60 * 60 * 24 * 90, partialFilterExpression: { isRead: true } }
);

module.exports = mongoose.model('Notification', notificationSchema);
