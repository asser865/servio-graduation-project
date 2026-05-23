// ─── Purpose ──────────────────────────────────────────────────────────────────
// Booking controller — maps HTTP verbs to service layer methods.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes }  = require('http-status-codes');
const bookingService   = require('./booking.service');
const Booking          = require('./booking.model');
const ApiResponse      = require('../../utils/ApiResponse');
const { logEvent }     = require('../admin/audit.service');

const create = async (req, res) => {
  const booking = await bookingService.createBooking(req.user.id, req.body);
  logEvent({ req, type: 'booking', action: 'Booking created', target: booking._id?.toString() });
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
    req.user.role,
    req.body
  );
  const status = req.body.status === 'cancelled' ? 'warn' : 'ok';
  logEvent({ req, type: 'booking', action: `Booking ${req.body.status}`, target: booking._id?.toString(), status });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking status updated.', booking);
};

const reschedule = async (req, res) => {
  const booking = await bookingService.rescheduleBooking(
    req.params.id,
    req.body,
    req.user.id,
    req.user.role
  );
  logEvent({ req, type: 'booking', action: 'Booking rescheduled', target: booking._id?.toString() });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking rescheduled.', booking);
};

const getAllBookings = async (req, res) => {
  const result = await bookingService.getAllBookings(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'All bookings retrieved.', result);
};

const getBookingById = async (req, res) => {
  const booking = await bookingService.getBookingById(req.params.id, req.user);
  return ApiResponse.success(res, StatusCodes.OK, 'Booking retrieved', booking);
};

const getWorkerBookedSlots = async (req, res) => {
  const { workerId } = req.params;
  const { date } = req.query;

  if (!date) {
    return ApiResponse.error(res, StatusCodes.BAD_REQUEST, 'date query param is required (YYYY-MM-DD).');
  }

  const start = new Date(date + 'T00:00:00.000Z');
  const end   = new Date(date + 'T23:59:59.999Z');

  const bookings = await Booking.find({
    worker: workerId,
    scheduledDate: { $gte: start, $lte: end },
    status: { $in: ['pending', 'accepted', 'en_route', 'arrived', 'in_progress'] },
  }).select('scheduledTime scheduledStart scheduledEnd estimatedFinishAt');

  const blocked = new Set();

  bookings.forEach(b => {
    if (!b.scheduledTime) return;
    blocked.add(b.scheduledTime);

    if (b.scheduledStart && b.scheduledEnd) {
      // If tech extended mid-job, estimatedFinishAt may exceed scheduledEnd — use whichever is later
      const effectiveEnd = (b.estimatedFinishAt && b.estimatedFinishAt > b.scheduledEnd)
        ? b.estimatedFinishAt
        : b.scheduledEnd;
      const windowMs   = effectiveEnd.getTime() - b.scheduledStart.getTime();
      const startHour  = parseInt(b.scheduledTime, 10);
      // Number of additional hours the window spills into (exact-hour boundary = not blocked)
      const extraHours = windowMs % 3_600_000 === 0
        ? windowMs / 3_600_000 - 1
        : Math.floor(windowMs / 3_600_000);

      for (let h = 1; h <= extraHours; h++) {
        const hour = startHour + h;
        if (hour < 24) blocked.add(`${String(hour).padStart(2, '0')}:00`);
      }
    }
  });

  return ApiResponse.success(res, StatusCodes.OK, 'Booked slots retrieved.', {
    bookedSlots: Array.from(blocked),
  });
};

const cancellationService = require('./cancellation.service');
const noShowService       = require('./no-show.service');
const ApiError            = require('../../utils/ApiError');

const cancelBooking = async (req, res) => {
  const booking = await Booking.findById(req.params.id).select('user worker status');
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
  const isCustomer = String(booking.user)   === String(req.user.id);
  const isWorker   = String(booking.worker) === String(req.user.id);
  if (!isCustomer && !isWorker) throw new ApiError(StatusCodes.FORBIDDEN, 'Not a party to this booking.');

  const reason = (req.body && req.body.reason) || '';
  let result;
  if (isCustomer) {
    result = await cancellationService.customerCancel(booking._id, { reason, by: req.user.id });
  } else {
    result = await cancellationService.workerCancel(booking._id, { reason, by: req.user.id });
  }
  logEvent({ req, type: 'booking', action: `Booking cancelled by ${isCustomer ? 'customer' : 'worker'}`, target: booking._id?.toString() });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking cancelled.', result);
};

const markCustomerNoShow = async (req, res) => {
  const result = await noShowService.markCustomerNoShow(req.params.id, {
    by: req.user.id,
    evidence: Array.isArray(req.body?.evidence) ? req.body.evidence : [],
    note: req.body?.note,
  });
  logEvent({ req, type: 'booking', action: 'Customer no-show marked', target: req.params.id });
  return ApiResponse.success(res, StatusCodes.OK, 'Customer marked no-show.', result);
};

const markWorkerNoShow = async (req, res) => {
  const result = await noShowService.markWorkerNoShow(req.params.id, {
    by: req.user.id,
    note: req.body?.note,
  });
  logEvent({ req, type: 'booking', action: 'Worker no-show marked', target: req.params.id });
  return ApiResponse.success(res, StatusCodes.OK, 'Worker marked no-show.', result);
};

const acceptBooking = async (req, res) => {
  const booking = await bookingService.acceptBooking({
    bookingId: req.params.id,
    technicianId: req.user.id,
  });
  logEvent({ req, type: 'booking', action: 'Booking accepted', target: booking._id?.toString() });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking accepted.', booking);
};

const startBooking = async (req, res) => {
  const booking = await bookingService.startWork({
    bookingId: req.params.id,
    technicianId: req.user.id,
  });
  logEvent({ req, type: 'booking', action: 'Booking started', target: booking._id?.toString() });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking started.', booking);
};

const completeBooking = async (req, res) => {
  const booking = await bookingService.markComplete({
    bookingId: req.params.id,
    technicianId: req.user.id,
    notes: req.body?.notes,
    photos: Array.isArray(req.body?.photos) ? req.body.photos : [],
  });
  logEvent({ req, type: 'booking', action: 'Booking completed', target: booking._id?.toString() });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking completed.', booking);
};

module.exports = {
  create, getMyBookings, getWorkerBookings, updateStatus, reschedule,
  getAllBookings, getBookingById, getWorkerBookedSlots,
  cancelBooking, markCustomerNoShow, markWorkerNoShow,
  acceptBooking, startBooking, completeBooking,
};
