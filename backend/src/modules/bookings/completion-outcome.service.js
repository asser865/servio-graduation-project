const { StatusCodes } = require('http-status-codes');
const Booking = require('./booking.model');
const settings = require('../admin/admin-settings.service');
const ApiError = require('../../utils/ApiError');

const VALID_OUTCOMES = Booking.COMPLETION_OUTCOME_VALUES;

function hasPhotos(value) {
  return Array.isArray(value) && value.some(photo => typeof photo === 'string' && photo.trim());
}

function requiredText(value, message) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new ApiError(StatusCodes.BAD_REQUEST, message);
  }
}

async function submit(bookingId, workerId, payload) {
  const {
    outcome,
    beforePhotos = [],
    afterPhotos = [],
    workerNotes,
    materialsUsed,
    refusalReason,
    couldNotCompleteReason,
  } = payload;

  if (!VALID_OUTCOMES.includes(outcome)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid outcome');
  }
  if (outcome === 'customer_paid' && (!hasPhotos(beforePhotos) || !hasPhotos(afterPhotos))) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Before and after completion photos are required.');
  }
  if (outcome === 'customer_refused_payment') {
    requiredText(refusalReason, 'Refusal reason is required.');
  }
  if (outcome === 'could_not_complete') {
    requiredText(couldNotCompleteReason, 'Incomplete-job reason is required.');
  }

  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
  if (String(booking.worker) !== String(workerId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Worker not authorized for this booking');
  }
  if (!['in_progress', 'arrived'].includes(booking.status)) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `Cannot submit outcome from status '${booking.status}'`
    );
  }

  const submittedAt = new Date();
  booking.completionOutcome = {
    outcome,
    submittedAt,
    beforePhotos,
    afterPhotos,
    workerNotes,
    materialsUsed,
    refusalReason,
    couldNotCompleteReason,
  };

  switch (outcome) {
    case 'customer_paid':
      booking.status = 'awaiting_customer_confirmation';
      booking.actualCompletedAt = booking.actualCompletedAt || submittedAt;
      {
        const cfg = await settings.get();
        const hours = Number(cfg?.escrow?.autoConfirmHours || 48);
        booking.customerConfirmAutoAt = new Date(submittedAt.getTime() + hours * 3600 * 1000);
      }
      break;
    case 'customer_refused_payment':
      booking.status = 'payment_refused';
      booking.refusalVerification = {
        status: 'pending',
        notifiedAt: new Date(),
      };
      break;
    case 'could_not_complete':
      booking.status = 'incomplete_review';
      break;
  }

  await booking.save();
  return booking;
}

module.exports = { submit, VALID_OUTCOMES };
