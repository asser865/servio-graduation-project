const mongoose = require('mongoose');

const ACTION_TYPES = [
  'payment_release', 'payment_reject', 'payment_refund', 'payment_partial_refund',
  'debt_mark_paid', 'debt_verify', 'debt_reject',
  'payout_approve', 'payout_reject', 'payout_mark_paid',
  'dispute_resolve', 'dispute_escalate',
  'restriction_clear', 'emergency_release', 'emergency_lock', 'emergency_unlock',
  'system_auto_confirm', 'system_apology_credit', 'system_migration',
  'credit_issue',
  'above_hold_manual_collection',
  'callout_fee_captured',
];

const TARGET_TYPES = ['payment', 'debt', 'payout', 'dispute', 'user', 'settlement', 'booking'];

const adminActionSchema = new mongoose.Schema({
  admin:      { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
  actionType: { type: String, enum: ACTION_TYPES, required: true, index: true },
  targetType: { type: String, enum: TARGET_TYPES, required: true },
  targetId:   { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  details:    { type: mongoose.Schema.Types.Mixed },
  ipAddress:  { type: String },
}, { timestamps: { createdAt: true, updatedAt: false } });

adminActionSchema.set('strict', 'throw');

const AdminAction = mongoose.model('AdminAction', adminActionSchema);
AdminAction.ACTION_TYPES = ACTION_TYPES;
AdminAction.TARGET_TYPES = TARGET_TYPES;

module.exports = AdminAction;
