const { StatusCodes } = require('http-status-codes');
const Booking = require('../bookings/booking.model');
const paymentService = require('../payments/payment.service');
const ApiError = require('../../utils/ApiError');
const { classify } = require('./queue-classifier.service');

function bookingId(booking) {
  return String(booking._id);
}

function classifierInput(booking) {
  const item = typeof booking.toObject === 'function'
    ? booking.toObject()
    : booking;

  return {
    ...item,
    amount: item.amount ?? item.totalPrice ?? 0,
    type: 'card_release',
  };
}

const releaseLowRiskBookings = async (req, res) => {
  const { ids } = req.body || {};

  if (!Array.isArray(ids) || ids.length === 0) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'ids must be a non-empty array.');
  }

  const requestedIds = [...new Set(ids.map(id => String(id)))];
  const bookings = await Booking.find({ _id: { $in: ids } });
  const bookingsById = new Map(bookings.map(booking => [bookingId(booking), booking]));
  const missingIds = requestedIds.filter(id => !bookingsById.has(id));

  if (missingIds.length > 0) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      'Some bookings could not be found.',
      missingIds.map(id => ({ id }))
    );
  }

  const orderedBookings = requestedIds.map(id => bookingsById.get(id));
  const blocked = orderedBookings
    .map(booking => {
      const classification = classify(classifierInput(booking));
      return {
        id: bookingId(booking),
        tier: classification.tier,
        reason: classification.reason,
      };
    })
    .filter(item => item.tier !== 'low');

  if (blocked.length > 0) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      'Bulk release only accepts low-risk bookings.',
      blocked
    );
  }

  const ineligible = [];
  for (const booking of orderedBookings) {
    try {
      await paymentService.validateAdminApproveCompletion(booking);
    } catch (error) {
      ineligible.push({ id: bookingId(booking), reason: error.message });
    }
  }
  if (ineligible.length > 0) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      'Some bookings are not eligible for release.',
      ineligible
    );
  }

  const released = [];
  for (const booking of orderedBookings) {
    released.push(await paymentService.adminApproveCompletion(
      bookingId(booking),
      req.user.id,
      { reasonCode: 'bulk_low_risk' }
    ));
  }

  return res.status(StatusCodes.OK).json({ released });
};

module.exports = {
  releaseLowRiskBookings,
};
