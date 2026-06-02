const { StatusCodes } = require('http-status-codes');
const Booking = require('./booking.model');
const autoFeeDebtSvc = require('../payments/auto-fee-debt.service');
const ApiError = require('../../utils/ApiError');

async function submit(bookingId, userId, payload) {
  const { action, rating, issueReason, notes, evidenceImages = [] } = payload;
  if (!['confirmed', 'reported_issue'].includes(action)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid action');
  }
  if (action === 'reported_issue') {
    if (!Booking.CUSTOMER_ISSUE_REASONS.includes(issueReason)) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'A valid issue reason is required.');
    }
    if (typeof notes !== 'string' || !notes.trim()) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Issue details are required.');
    }
    if (!Array.isArray(evidenceImages) || !evidenceImages.some(image => typeof image === 'string' && image.trim())) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'At least one evidence image is required.');
    }
  }

  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
  if (String(booking.user) !== String(userId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Not authorized for this booking');
  }
  if (booking.status !== 'awaiting_customer_confirmation') {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Cannot submit feedback from status '${booking.status}'`
    );
  }

  booking.customerFeedback = {
    action,
    rating,
    issueReason: action === 'reported_issue' ? issueReason : undefined,
    notes,
    evidenceImages,
    submittedAt: new Date(),
    confirmedVia: action === 'confirmed' ? 'customer' : undefined,
  };

  if (action === 'confirmed') {
    booking.customerConfirmedAt = new Date();
    booking.customerConfirmedVia = 'customer';
    booking.status = 'pending_admin_review';
  } else {
    booking.status = 'customer_disputed';
  }

  await booking.save();
  if (action === 'confirmed' && booking.paymentMethod === 'cash') {
    const result = await autoFeeDebtSvc.createIfClean(booking._id);
    return result.booking || booking;
  }
  return booking;
}

module.exports = { submit };
