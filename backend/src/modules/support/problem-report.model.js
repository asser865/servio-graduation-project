const mongoose = require('mongoose');

const PROBLEM_REPORT_CATEGORIES = [
  'Bug / App Crash',
  'Wrong Information',
  'Payment Issue',
  'Account Problem',
  'Other',
];

const PROBLEM_REPORT_STATUSES = ['open', 'resolved'];

const problemReportSchema = new mongoose.Schema(
  {
    category: {
      type: String,
      enum: PROBLEM_REPORT_CATEGORIES,
      required: [true, 'Category is required'],
    },
    description: {
      type: String,
      required: [true, 'Description is required'],
      minlength: [20, 'Description must be at least 20 characters'],
      trim: true,
    },
    screenshotUrl: {
      type: String,
      default: '',
    },
    reporter: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    status: {
      type: String,
      enum: PROBLEM_REPORT_STATUSES,
      default: 'open',
    },
    adminNotes: {
      type: String,
      trim: true,
      default: '',
    },
  },
  { timestamps: true }
);

problemReportSchema.index({ status: 1, createdAt: -1 });
problemReportSchema.index({ reporter: 1, createdAt: -1 });

module.exports = mongoose.model('ProblemReport', problemReportSchema);
module.exports.PROBLEM_REPORT_CATEGORIES = PROBLEM_REPORT_CATEGORIES;
module.exports.PROBLEM_REPORT_STATUSES = PROBLEM_REPORT_STATUSES;
