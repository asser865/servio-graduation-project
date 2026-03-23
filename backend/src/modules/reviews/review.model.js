// ─── Purpose ──────────────────────────────────────────────────────────────────
// Reviews are scoped to completed bookings (enforced by the service layer).
// Using booking as unique prevents a user from reviewing the same job twice.
// The post-save hook keeps User.averageRating in sync automatically without
// requiring the caller to do any extra work.
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');
const User     = require('../users/user.model');

const reviewSchema = new mongoose.Schema(
  {
    user: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'User is required'],
    },

    worker: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'User',
      required: [true, 'Worker is required'],
    },

    // One booking can only have one review
    booking: {
      type:     mongoose.Schema.Types.ObjectId,
      ref:      'Booking',
      required: [true, 'Booking is required'],
      unique:   true,
    },

    rating: {
      type:     Number,
      required: [true, 'Rating is required'],
      min:      [1, 'Rating must be at least 1'],
      max:      [5, 'Rating cannot exceed 5'],
    },

    comment: {
      type:      String,
      trim:      true,
      maxlength: [1000, 'Comment cannot exceed 1000 characters'],
    },
  },
  { timestamps: true }
);

// ── Post-save hook — recalculate worker's rating ──────────────────────────────
// After every review save, recalculate the worker's aggregated rating from all
// reviews. Using aggregation instead of incremental math prevents drift.
reviewSchema.post('save', async function () {
  const stats = await this.constructor.aggregate([
    { $match: { worker: this.worker } },
    {
      $group: {
        _id:           '$worker',
        averageRating: { $avg: '$rating' },
        totalReviews:  { $sum: 1 },
      },
    },
  ]);

  if (stats.length > 0) {
    await User.findByIdAndUpdate(this.worker, {
      averageRating: Math.round(stats[0].averageRating * 10) / 10, // round to 1dp
      totalReviews:  stats[0].totalReviews,
    });
  }
});

const Review = mongoose.model('Review', reviewSchema);

module.exports = Review;
