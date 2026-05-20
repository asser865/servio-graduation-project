const mongoose = require('mongoose');

const SUPPORT_ISSUE_TYPES = [
  'late',
  'no_show',
  'during_work_problem',
  'safety',
  'post_completion',
  'other',
];

const SUPPORT_ISSUE_STATUSES = [
  'open',
  'reviewing',
  'waiting_customer',
  'waiting_worker',
  'resolved',
  'closed',
];

const SUPPORT_ISSUE_PRIORITIES = ['normal', 'high', 'urgent'];

const supportIssueSchema = new mongoose.Schema(
  {
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: [true, 'Booking reference is required'],
    },
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Customer is required'],
    },
    worker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Worker is required'],
    },
    type: {
      type: String,
      enum: SUPPORT_ISSUE_TYPES,
      required: true,
    },
    status: {
      type: String,
      enum: SUPPORT_ISSUE_STATUSES,
      default: 'open',
    },
    priority: {
      type: String,
      enum: SUPPORT_ISSUE_PRIORITIES,
      default: 'normal',
    },
    description: {
      type: String,
      required: [true, 'Issue description is required'],
      minlength: [20, 'Issue description must be at least 20 characters'],
      trim: true,
    },
    evidence: {
      type: [String],
      default: [],
    },
    adminNotes: {
      type: String,
      trim: true,
      default: '',
    },
    resolution: {
      type: String,
      trim: true,
      default: '',
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    resolvedAt: {
      type: Date,
    },
  },
  { timestamps: true }
);

supportIssueSchema.index({ status: 1, priority: 1, createdAt: -1 });
supportIssueSchema.index({ booking: 1, status: 1 });
supportIssueSchema.index({ customer: 1, createdAt: -1 });

module.exports = mongoose.model('SupportIssue', supportIssueSchema);
module.exports.SUPPORT_ISSUE_TYPES = SUPPORT_ISSUE_TYPES;
module.exports.SUPPORT_ISSUE_STATUSES = SUPPORT_ISSUE_STATUSES;
module.exports.SUPPORT_ISSUE_PRIORITIES = SUPPORT_ISSUE_PRIORITIES;
