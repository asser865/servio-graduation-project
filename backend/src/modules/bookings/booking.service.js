// ─── Purpose ──────────────────────────────────────────────────────────────────
// booking.service.js owns the booking state machine. Role-based status
// transition rules live here — not in the controller or model — so they are
// easy to find, test, and update as business rules evolve.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const Booking        = require('./booking.model');
const Service        = require('../services/service.model');
const User           = require('../users/user.model');
const SavedCard      = require('../savedCards/savedCard.model');
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
  const { workerId, serviceId, serviceCategory, serviceName, scheduledDate, scheduledTime, address, description, images, savedCardId } = data;
  const paymentMethod = normalizePaymentMethod(data.paymentMethod);

  // Fetch worker
  const worker = await User.findOne({ _id: workerId, role: 'worker', isActive: true, isVerified: true });
  if (!worker) throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found or not available.');

  // 3a — Worker availability gate
  if (!worker.isAvailable) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'This technician is not currently accepting bookings.');
  }

  // 3b — Date range (UTC-based to match Mongoose's Date type storage)
  const [y, m, d] = scheduledDate.split('-').map(Number);
  const bookingDateUTC = new Date(Date.UTC(y, m - 1, d));
  const todayUTC       = new Date(); todayUTC.setUTCHours(0, 0, 0, 0);
  const maxDateUTC     = new Date(todayUTC); maxDateUTC.setUTCDate(maxDateUTC.getUTCDate() + 30);

  if (bookingDateUTC < todayUTC) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Booking date must be today or in the future.');
  }
  if (bookingDateUTC > maxDateUTC) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Bookings can only be made up to 30 days in advance.');
  }

  // 3c — Time provided
  if (!scheduledTime) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A time slot must be selected.');
  }

  // 3d — Slot alignment: valid hour (00–23) at whole-hour boundary
  if (!/^(0[0-9]|1[0-9]|2[0-3]):00$/.test(scheduledTime)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid time slot format. Only whole-hour slots are accepted.');
  }

  const scheduledHour = parseInt(scheduledTime, 10);

  // 3d-extra — Same-day past-time check (compare local hours since scheduledTime is local)
  const todayLocal       = new Date(); todayLocal.setHours(0, 0, 0, 0);
  const bookingDateLocal = new Date(y, m - 1, d);
  if (bookingDateLocal.getTime() === todayLocal.getTime() && scheduledHour <= new Date().getHours()) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Cannot book a time slot that has already started or passed today.');
  }

  // 3e — Day must exist in worker's schedule.
  // bookingDateUTC = Date.UTC(y, m-1, d) which is always exactly "YYYY-MM-DDT00:00:00Z".
  // getUTCDay() on that value returns the calendar day-of-week for the requested date
  // regardless of server timezone — safe to use here instead of bookingDateLocal.getDay().
  const DAY_NAMES = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const dayName   = DAY_NAMES[bookingDateUTC.getUTCDay()];
  const daySlot   = (worker.availability || []).find(a => a.day === dayName);
  if (!daySlot) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Technician is not available on this day.');
  }

  // 3e-extra — Blocked date check (worker marked this date as time-off)
  const bookingDateStr = `${y}-${String(m).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
  if ((worker.blockedDates || []).includes(bookingDateStr)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Technician is not available on this date (time off).');
  }

  // 3f — Time must fall within working hours (last valid slot starts at toHour - 1)
  const fromHour = parseInt(daySlot.from, 10);
  const toHour   = parseInt(daySlot.to,   10);
  if (scheduledHour < fromHour || scheduledHour >= toHour) {
    throw new ApiError(StatusCodes.BAD_REQUEST, "Selected time is outside technician's working hours.");
  }

  // 3g — Double-booking check (exact UTC midnight match eliminates timezone range ambiguity).
  // All bookings created by this function store scheduledDate as bookingDateUTC (UTC midnight),
  // so exact equality is safe and intentional — no range query needed.
  const conflict = await Booking.findOne({
    worker:        workerId,
    scheduledDate: bookingDateUTC,
    scheduledTime,
    status:        { $in: ['pending', 'accepted', 'in_progress'] },
  });
  if (conflict) {
    throw new ApiError(StatusCodes.CONFLICT, 'This time slot is already booked. Please select another.');
  }

  // ── Service / category validation ──────────────────────────────────────────
  let service     = null;
  let bookingPrice = 0;
  let resolvedCategory = serviceCategory || '';
  let resolvedName     = serviceName || '';

  if (serviceId) {
    // Specific sub-service path
    service = await Service.findOne({ _id: serviceId, isActive: true });
    if (!service) throw new ApiError(StatusCodes.NOT_FOUND, 'Service not found or no longer available.');

    const workerSupportsService = Array.isArray(worker.services) &&
      worker.services.some((id) => id.toString() === service._id.toString());
    const legacyCategoryMatches = !workerSupportsService &&
      Array.isArray(worker.categories) &&
      worker.categories.includes(service.category);
    if (!workerSupportsService && !legacyCategoryMatches) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Selected worker does not support this service.');
    }

    bookingPrice     = service.basePrice;
    resolvedCategory = service.category;
    resolvedName     = service.title;
  } else if (serviceCategory) {
    // General category path — no specific sub-service selected
    const workerCoversCategory = (worker.categories || []).includes(serviceCategory);
    if (!workerCoversCategory) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'This technician does not offer this service category.');
    }
    bookingPrice  = worker.hourlyRate || 0;
    resolvedName  = resolvedName || `General ${serviceCategory.charAt(0).toUpperCase() + serviceCategory.slice(1)}`;
  } else {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A service or service category is required.');
  }

  const paymentData = await resolvePaymentData(userId, paymentMethod, savedCardId);

  // Create booking — catch duplicate-key as race-condition safeguard
  let booking;
  try {
    booking = await Booking.create({
      user:            userId,
      worker:          workerId,
      service:         serviceId || undefined,
      serviceCategory: resolvedCategory,
      serviceName:     resolvedName,
      scheduledDate:   bookingDateUTC,
      scheduledTime,
      address,
      description,
      images,
      totalPrice:      bookingPrice,
      paymentMethod:    paymentData.paymentMethod,
      savedCard:        paymentData.savedCard,
      paymentMeta:      paymentData.paymentMeta,
    });
  } catch (err) {
    if (err.code === 11000) {
      throw new ApiError(StatusCodes.CONFLICT, 'This time slot is already booked. Please select another.');
    }
    throw err;
  }

  return booking.populate(['user', 'worker', 'service', 'savedCard']);
};

function normalizePaymentMethod(value) {
  const method = String(value || '').trim().toLowerCase();
  if (method === 'cash') return 'cash';
  if (method === 'card' || method === 'online') return 'card';
  throw new ApiError(StatusCodes.BAD_REQUEST, 'Payment method must be cash or card.');
}

async function resolvePaymentData(userId, paymentMethod, savedCardId) {
  if (paymentMethod === 'cash') {
    return {
      paymentMethod: 'cash',
      savedCard:    undefined,
      paymentMeta:  undefined,
    };
  }

  if (!savedCardId) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A saved card is required for card payments.');
  }

  const card = await SavedCard.findOne({ _id: savedCardId, userId });
  if (!card) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Saved card not found for this customer.');
  }

  return {
    paymentMethod: 'card',
    savedCard:    card._id,
    paymentMeta:  {
      last4:    card.last4,
      cardType: card.cardType,
      label:    card.label,
    },
  };
}

/**
 * GET USER BOOKINGS
 * WHAT: Returns all bookings made by the logged-in user.
 * HOW:  Optional ?status filter (pending, completed, etc.).
 */
const getUserBookings = async (userId, { status, page = 1, limit = 10 }) => {
  const filter = { user: userId };
  if (status) {
    filter.status = status.includes(',') ? { $in: status.split(',') } : status;
  }

  const skip = (Number(page) - 1) * Number(limit);

  const [bookings, total] = await Promise.all([
    Booking.find(filter)
      .populate('worker', 'name profileImage averageRating')
      .populate('service', 'title category basePrice priceUnit')
      .populate('savedCard', 'last4 expiry cardType label isDefault')
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
  if (status) {
    filter.status = status.includes(',') ? { $in: status.split(',') } : status;
  }

  const skip = (Number(page) - 1) * Number(limit);

  const [bookings, total] = await Promise.all([
    Booking.find(filter)
      .populate('user',    'name phone profileImage')
      .populate('service', 'title category basePrice priceUnit')
      .populate('savedCard', 'last4 expiry cardType label isDefault')
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
      .populate('savedCard', 'last4 expiry cardType label isDefault')
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
  if (actorRole === 'worker' && booking.worker.toString() !== actorId.toString()) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'You are not assigned to this booking.');
  }
  if (actorRole === 'user' && booking.user.toString() !== actorId.toString()) {
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

  const updated = await Booking.findByIdAndUpdate(
    bookingId,
    { status: newStatus },
    { new: true, runValidators: false }
  );

  return updated;
};

const getBookingById = async (bookingId, requestingUser) => {
  const booking = await Booking.findById(bookingId)
    .populate('user',    'name email phone profileImage')
    .populate('worker',  'name email phone profileImage')
    .populate('service', 'title basePrice category')
    .populate('savedCard', 'last4 expiry cardType label isDefault');

  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');

  const isUser   = booking.user._id.toString() === requestingUser.id.toString();
  const isWorker = booking.worker._id.toString() === requestingUser.id.toString();
  const isAdmin  = requestingUser.role === 'admin';
  if (!isUser && !isWorker && !isAdmin) throw new ApiError(StatusCodes.FORBIDDEN, 'Not authorized to view this booking');

  return booking;
};

module.exports = { createBooking, getUserBookings, getWorkerBookings, getAllBookings, updateBookingStatus, getBookingById };
