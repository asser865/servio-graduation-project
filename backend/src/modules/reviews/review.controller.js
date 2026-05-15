// ─── Purpose ──────────────────────────────────────────────────────────────────
// Review controller — business logic lives in the service layer so this stays
// clean. The booking completion check is critical to data integrity.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const Review          = require('./review.model');
const Booking         = require('../bookings/booking.model');
const ApiError        = require('../../utils/ApiError');
const ApiResponse     = require('../../utils/ApiResponse');
const notifSvc        = require('../notifications/notification.service');

// ── CREATE REVIEW (User Only) ────────────────────────────────────────────────
// WHAT: Allows users to rate a worker after a booking is "completed".
// WHY:  Ensures data integrity (cannot review workers you didn't book).
const createReview = async (req, res) => {
  const { bookingId, rating, comment } = req.body;
  const userId = req.user.id;

  const booking = await Booking.findById(bookingId);
  if (!booking) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
  }
  if (booking.user.toString() !== userId.toString()) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'You can only review your own bookings.');
  }
  if (booking.status !== 'completed') {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'You can only review a completed booking.');
  }

  // The unique index on booking prevents duplicate reviews automatically
  const review = await Review.create({
    user:    userId,
    worker:  booking.worker,
    booking: bookingId,
    rating,
    comment,
  });

  notifSvc.notifyReviewReceived(
    booking.worker,
    req.user.name || 'A customer',
    rating,
    bookingId
  );

  return ApiResponse.success(res, StatusCodes.CREATED, 'Review submitted successfully.', review);
};

// ── GET MY REVIEWS (User Only) ────────────────────────────────────────────────
// WHAT: Fetches all reviews submitted by the authenticated user.
const getMyReviews = async (req, res) => {
  const reviews = await Review.find({ user: req.user.id }).select('booking rating comment');
  return ApiResponse.success(res, StatusCodes.OK, 'Reviews retrieved.', { reviews });
};

// ── GET WORKER REVIEWS (Public) ──────────────────────────────────────────────
// WHAT: Fetches all reviews for a specific worker.
const getWorkerReviews = async (req, res) => {
  const reviews = await Review.find({ worker: req.params.workerId })
    .populate('user', 'name profileImage')
    .sort({ createdAt: -1 });

  return ApiResponse.success(res, StatusCodes.OK, 'Reviews retrieved successfully.', reviews);
};

// ── DELETE REVIEW (Admin Only) ────────────────────────────────────────────────
// WHAT: Allows admins to remove inappropriate or fake reviews.
const deleteReview = async (req, res) => {
  const review = await Review.findByIdAndDelete(req.params.id);
  if (!review) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Review not found.');
  }
  return ApiResponse.success(res, StatusCodes.OK, 'Review deleted.', null);
};

module.exports = { createReview, getMyReviews, getWorkerReviews, deleteReview };
