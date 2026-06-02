const { StatusCodes } = require('http-status-codes');
const Booking = require('./booking.model');
const autoFeeDebt = require('../payments/auto-fee-debt.service');
const techReputation = require('../trust/tech-reputation.service');
const ApiError = require('../../utils/ApiError');

async function respond(bookingId, userId, { customerConfirmsRefusal, customerResponse } = {}) {
  if (typeof customerConfirmsRefusal !== 'boolean') {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'customerConfirmsRefusal must be a boolean');
  }

  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
  if (String(booking.user) !== String(userId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Not authorized for this booking');
  }
  if (booking.refusalVerification?.status !== 'pending') {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Refusal verification not pending');
  }

  booking.refusalVerification.respondedAt = new Date();
  booking.refusalVerification.customerResponse = customerResponse;

  if (customerConfirmsRefusal) {
    booking.refusalVerification.status = 'customer_confirmed_refusal';
    booking.status = 'refusal_under_investigation';
    await booking.save();
    return booking;
  }

  booking.refusalVerification.status = 'customer_disputes_refusal';
  booking.status = 'pending_admin_review';
  await booking.save();

  await techReputation.recordIncident(booking.worker, {
    type: 'false_refusal_claim',
    bookingId: booking._id,
    severity: 'high',
  });

  const result = await autoFeeDebt.createIfClean(booking._id);
  return result.booking || booking;
}

module.exports = { respond };
