// ─── Purpose ──────────────────────────────────────────────────────────────────
// Booking controller — maps HTTP verbs to service layer methods.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes }  = require('http-status-codes');
const bookingService   = require('./booking.service');
const ApiResponse      = require('../../utils/ApiResponse');

const create = async (req, res) => {
  const booking = await bookingService.createBooking(req.user.id, req.body);
  return ApiResponse.success(res, StatusCodes.CREATED, 'Booking created successfully.', booking);
};

const getMyBookings = async (req, res) => {
  const result = await bookingService.getUserBookings(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Your bookings retrieved.', result);
};

const getWorkerBookings = async (req, res) => {
  const result = await bookingService.getWorkerBookings(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Worker bookings retrieved.', result);
};

const updateStatus = async (req, res) => {
  const booking = await bookingService.updateBookingStatus(
    req.params.id,
    req.body.status,
    req.user.id,
    req.user.role
  );
  return ApiResponse.success(res, StatusCodes.OK, 'Booking status updated.', booking);
};

const getAllBookings = async (req, res) => {
  const result = await bookingService.getAllBookings(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'All bookings retrieved.', result);
};

module.exports = { create, getMyBookings, getWorkerBookings, updateStatus, getAllBookings };
