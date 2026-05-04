// ─── Purpose ──────────────────────────────────────────────────────────────────
// booking.service.js owns the booking state machine. Role-based status
// transition rules live here — not in the controller or model — so they are
// easy to find, test, and update as business rules evolve.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const Booking        = require('./booking.model');
const Service        = require('../services/service.model');
const User           = require('../users/user.model');
const ApiError       = require('../../utils/ApiError');

// Role → allowed status transitions
const TRANSITION_RULES = {
  worker: ['accepted', 'rejected', 'in_progress', 'completed'],
  user:   ['cancelled'],
  admin:  ['pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled', 'disputed'],
};

/**
 * CREATE NEW BOOKING
 * WHAT: Reserves a service from a specific worker.
 * HOW:  Checks if worker and service are valid/active before creating.
 */
const createBooking = async (userId, data) => {
  const { workerId, serviceId, scheduledDate, address, description, images } = data;

  // Verify the worker exists and is an active, verified worker
  const worker = await User.findOne({ _id: workerId, role: 'worker', isActive: true, isVerified: true });
  if (!worker) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found or not available.');
  }

  // Verify the service exists and is active
  const service = await Service.findOne({ _id: serviceId, isActive: true });
  if (!service) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found or no longer available.');
  }

  // Verify the worker supports this specific service (canonical check via ObjectId)
  const workerSupportsService = Array.isArray(worker.services) &&
    worker.services.some((id) => id.toString() === service._id.toString());

  // Backward-compatibility: also accept if worker's legacy categories include this service's category
  const legacyCategoryMatches = !workerSupportsService &&
    Array.isArray(worker.categories) &&
    worker.categories.includes(service.category);

  if (!workerSupportsService && !legacyCategoryMatches) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Selected worker does not support this service.');
  }

  const booking = await Booking.create({
    user: userId,
    worker: workerId,
    service: serviceId,
    scheduledDate,
    address,
    description,
    images,
    totalPrice: service.basePrice, // initial estimate; can be adjusted
  });

  return booking.populate(['user', 'worker', 'service']);
};

/**
 * GET USER BOOKINGS
 * WHAT: Returns all bookings made by the logged-in user.
 * HOW:  Optional ?status filter (pending, completed, etc.).
 */
const getUserBookings = async (userId, { status, page = 1, limit = 10 }) => {
  const filter = { user: userId };
  if (status) filter.status = status;

  const skip = (Number(page) - 1) * Number(limit);

  const [bookings, total] = await Promise.all([
    Booking.find(filter)
      .populate('worker', 'name profileImage averageRating')
      .populate('service', 'title category basePrice priceUnit')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit)),
    Booking.countDocuments(filter),
  ]);

  return { bookings, pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) } };
};

/**
 * GET WORKER BOOKINGS
 * WHAT: Returns all bookings assigned to the logged-in worker.
 * HOW:  Helps workers see their incoming work schedule.
 */
const getWorkerBookings = async (workerId, { status, page = 1, limit = 10 }) => {
  const filter = { worker: workerId };
  if (status) filter.status = status;

  const skip = (Number(page) - 1) * Number(limit);

  const [bookings, total] = await Promise.all([
    Booking.find(filter)
      .populate('user',    'name phone profileImage')
      .populate('service', 'title category basePrice priceUnit')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit)),
    Booking.countDocuments(filter),
  ]);

  return { bookings, pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) } };
};

/**
 * GET ALL BOOKINGS (Admin Only)
 * WHAT: Global view of every booking in the system.
 */
const getAllBookings = async ({ status, page = 1, limit = 10 }) => {
  const filter = {};
  if (status) filter.status = status;

  const skip = (Number(page) - 1) * Number(limit);

  const [bookings, total] = await Promise.all([
    Booking.find(filter)
      .populate('user',    'name email')
      .populate('worker',  'name email')
      .populate('service', 'title category')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit)),
    Booking.countDocuments(filter),
  ]);

  return { bookings, pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) } };
};

/**
 * UPDATE BOOKING STATUS
 * WHAT: Transitions a booking (pending -> accepted -> in_progress -> completed).
 * WHY:  Enforces rules (e.g., users can cancel, but only workers can accept).
 */
const updateBookingStatus = async (bookingId, newStatus, actorId, actorRole) => {
  const booking = await Booking.findById(bookingId);
  if (!booking) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
  }

  // ── Ownership check ────────────────────────────────────────────────────────
  if (actorRole === 'worker' && booking.worker.toString() !== actorId) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'You are not assigned to this booking.');
  }
  if (actorRole === 'user' && booking.user.toString() !== actorId) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'This is not your booking.');
  }

  // ── Transition rule check ──────────────────────────────────────────────────
  const allowedTransitions = TRANSITION_RULES[actorRole] || [];
  if (!allowedTransitions.includes(newStatus)) {
    throw new ApiError(
      StatusCodes.FORBIDDEN,
      `Role '${actorRole}' cannot set booking status to '${newStatus}'.`
    );
  }

  // ── User can only cancel a pending booking ────────────────────────────────
  if (actorRole === 'user' && newStatus === 'cancelled' && booking.status !== 'pending') {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'You can only cancel a booking that is still pending.');
  }

  booking.status = newStatus;
  await booking.save();

  return booking;
};

const getBookingById = async (bookingId, requestingUser) => {
  const booking = await Booking.findById(bookingId)
    .populate('user',    'name email phone profileImage')
    .populate('worker',  'name email phone profileImage')
    .populate('service', 'title basePrice category');

  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');

  const isUser   = booking.user._id.toString() === requestingUser.id.toString();
  const isWorker = booking.worker._id.toString() === requestingUser.id.toString();
  const isAdmin  = requestingUser.role === 'admin';
  if (!isUser && !isWorker && !isAdmin) throw new ApiError(StatusCodes.FORBIDDEN, 'Not authorized to view this booking');

  return booking;
};

module.exports = { createBooking, getUserBookings, getWorkerBookings, getAllBookings, updateBookingStatus, getBookingById };
