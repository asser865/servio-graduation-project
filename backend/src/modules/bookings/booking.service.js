// ─── Purpose ──────────────────────────────────────────────────────────────────
// booking.service.js owns the booking state machine. Role-based status
// transition rules live here — not in the controller or model — so they are
// easy to find, test, and update as business rules evolve.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const mongoose      = require('mongoose');
const Booking        = require('./booking.model');
const Service        = require('../services/service.model');
const User           = require('../users/user.model');
const SavedCard      = require('../savedCards/savedCard.model');
const Settings       = require('../admin/settings.model');
const ApiError       = require('../../utils/ApiError');
const notifSvc       = require('../notifications/notification.service');
const { computeScheduledWindow } = require('./availability.service');
const { resolveDurationMin }     = require('../services/duration-fallback');

const FRONTEND_URL = (process.env.FRONTEND_URL || 'http://localhost:5500/temp_repo/servio_frontend').replace(/\/$/, '');

// Role → allowed status transitions
const TRANSITION_RULES = {
  worker: ['accepted', 'en_route', 'arrived', 'rejected', 'in_progress', 'awaiting_customer_confirmation'],
  user:   ['cancelled', 'completed', 'disputed'],
  admin:  [
    'pending', 'accepted', 'en_route', 'arrived', 'rejected', 'in_progress',
    'awaiting_customer_confirmation', 'pending_admin_review', 'completed', 'cancelled', 'disputed',
  ],
};

const ACTIVE_SLOT_STATUSES = ['pending', 'accepted', 'en_route', 'arrived', 'in_progress'];

const autoCancelExpiredBookings = async (bookings) => {
  const now = Date.now();
  const toCancel = bookings.filter(
    b => b.paymentMethod === 'online'
      && b.status === 'pending'
      && b.paymentDeadline
      && now > new Date(b.paymentDeadline).getTime()
  );
  if (toCancel.length > 0) {
    await Booking.updateMany(
      { _id: { $in: toCancel.map(b => b._id) }, status: 'pending' },
      { status: 'cancelled' },
      { runValidators: false }
    );
    toCancel.forEach(b => { b.status = 'cancelled'; });
  }
  return bookings;
};

const DAY_NAMES = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
const DEFAULT_PLATFORM_FEE_RATE = 10;

const toMoney = (value) => Number((Number(value) || 0).toFixed(2));

const normalizePercentage = (value, fallback = DEFAULT_PLATFORM_FEE_RATE) => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric < 0) return fallback;
  return numeric;
};

const getPublicPlatformSettings = async () => {
  const query = Settings.findOne();
  const selected = typeof query?.select === 'function'
    ? query.select('commissionRate cashPaymentsEnabled travelBufferMin')
    : query;
  const settings = typeof selected?.lean === 'function' ? await selected.lean() : await selected;
  return {
    commissionRate:      normalizePercentage(settings?.commissionRate),
    cashPaymentsEnabled: settings?.cashPaymentsEnabled !== false,
    travelBufferMin:     Number.isFinite(Number(settings?.travelBufferMin))
                           ? Number(settings.travelBufferMin)
                           : 30,
  };
};

const calculateFeeSnapshot = (baseAmount, platformFeeRate) => {
  const base = toMoney(baseAmount);
  const rate = normalizePercentage(platformFeeRate);
  const fee = toMoney(base * (rate / 100));
  return {
    platformFeeRate: rate,
    platformFeeAmount: fee,
    estimatedTotal: toMoney(base + fee),
  };
};

const normalizePaymentMethod = (value) => {
  const method = String(value || '').trim().toLowerCase();
  if (['cash', 'card', 'online'].includes(method)) return method;
  throw new ApiError(StatusCodes.BAD_REQUEST, 'Payment method must be cash, card, or online.');
};

const sanitizePaymentMeta = (paymentMeta = {}) => {
  const clean = {};
  ['last4', 'cardType', 'expiry', 'label'].forEach((key) => {
    if (paymentMeta[key]) clean[key] = String(paymentMeta[key]).trim().slice(0, 64);
  });
  if (paymentMeta.savedCardId) clean.savedCardId = paymentMeta.savedCardId;
  return Object.keys(clean).length ? clean : undefined;
};

const normalizeSchedule = ({ scheduledDate, scheduledTime }) => {
  if (!scheduledDate) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Scheduled date is required.');
  }
  if (!scheduledTime) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A time slot must be selected.');
  }
  if (!/^(0[0-9]|1[0-9]|2[0-3]):00$/.test(scheduledTime)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Invalid time slot format. Only whole-hour slots are accepted.');
  }

  const datePart = String(scheduledDate).slice(0, 10);
  const [y, m, d] = datePart.split('-').map(Number);
  if (!y || !m || !d) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Scheduled date must be a valid date.');
  }

  const bookingDateUTC = new Date(Date.UTC(y, m - 1, d));
  const todayUTC = new Date(); todayUTC.setUTCHours(0, 0, 0, 0);
  const maxDateUTC = new Date(todayUTC); maxDateUTC.setUTCDate(maxDateUTC.getUTCDate() + 30);

  if (bookingDateUTC < todayUTC) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Booking date must be today or in the future.');
  }
  if (bookingDateUTC > maxDateUTC) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Bookings can only be made up to 30 days in advance.');
  }

  const scheduledHour = parseInt(scheduledTime, 10);
  const todayLocal = new Date(); todayLocal.setHours(0, 0, 0, 0);
  const bookingDateLocal = new Date(y, m - 1, d);
  if (bookingDateLocal.getTime() === todayLocal.getTime() && scheduledHour <= new Date().getHours()) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Cannot book a time slot that has already started or passed today.');
  }

  return { bookingDateUTC, bookingDateStr: datePart, scheduledHour };
};

const assertWorkerAvailableForSchedule = (worker, bookingDateUTC, bookingDateStr, scheduledHour) => {
  if (!worker.isAvailable) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'This technician is not currently accepting bookings.');
  }

  const dayName = DAY_NAMES[bookingDateUTC.getUTCDay()];
  const daySlot = (worker.availability || []).find(a => a.day === dayName);
  if (!daySlot) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Technician is not available on this day.');
  }

  if ((worker.blockedDates || []).includes(bookingDateStr)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Technician is not available on this date (time off).');
  }

  const fromHour = parseInt(daySlot.from, 10);
  const toHour = parseInt(daySlot.to, 10);
  if (scheduledHour < fromHour || scheduledHour >= toHour) {
    throw new ApiError(StatusCodes.BAD_REQUEST, "Selected time is outside technician's working hours.");
  }
};

/**
 * CREATE NEW BOOKING
 * WHAT: Reserves a service from a specific worker.
 * HOW:  Checks if worker and service are valid/active before creating.
 */
const createBooking = async (userId, data) => {
  const { workerId, serviceId, serviceCategory, serviceName, scheduledDate, scheduledTime, address, description, images, savedCardId, paymentMeta: inputPaymentMeta } = data;
  const paymentMethod = normalizePaymentMethod(data.paymentMethod);

  // Fetch worker
  const worker = await User.findOne({ _id: workerId, role: 'worker', isActive: true, isVerified: true });
  if (!worker) throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found or not available.');

  // 3a — Worker availability gate
  if (!worker.isAvailable) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'This technician is not currently accepting bookings.');
  }

  // 3a-bis — Worker not suspended
  if (worker.suspendedUntil && new Date(worker.suspendedUntil) > new Date()) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'This technician is temporarily suspended.');
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
      worker.services.some((s) => s.serviceId && s.serviceId.toString() === service._id.toString());
    const legacyCategoryMatches = !workerSupportsService &&
      Array.isArray(worker.categories) &&
      worker.categories.includes(service.category);
    if (!workerSupportsService && !legacyCategoryMatches) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Selected worker does not support this service.');
    }

    const priced = (worker.services || []).find(
      (s) => s.serviceId && s.serviceId.toString() === service._id.toString()
    );
    // Use `!= null` so a legitimate startsFrom of 0 is honored, not treated as unset.
    bookingPrice     = (priced && priced.startsFrom != null) ? priced.startsFrom : service.basePrice;
    resolvedCategory = service.category;
    resolvedName     = resolvedName || service.title;
  } else if (serviceCategory) {
    // General category path — no specific sub-service selected
    const workerCoversCategory = (worker.categories || []).includes(serviceCategory);
    const workerCoversSkill = (worker.skills || []).includes(serviceCategory);
    if (!workerCoversCategory && !workerCoversSkill) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'This technician does not offer this service category.');
    }
    bookingPrice  = worker.hourlyRate || 0;
    resolvedName  = resolvedName || `General ${serviceCategory.charAt(0).toUpperCase() + serviceCategory.slice(1)}`;
  } else {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'A service or service category is required.');
  }

  const platformSettings = await getPublicPlatformSettings();
  if (paymentMethod === 'cash' && !platformSettings.cashPaymentsEnabled) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Cash payments are currently disabled.');
  }

  if (paymentMethod === 'cash') {
    if (worker.restrictions && worker.restrictions.cashBookingsBlocked) {
      throw new ApiError(StatusCodes.FORBIDDEN, 'This technician is not currently accepting cash payments.');
    }
  }

  const feeSnapshot = calculateFeeSnapshot(bookingPrice, platformSettings.commissionRate);

  // ── Interval-overlap conflict check ───────────────────────────────────────
  const bufferMin = platformSettings.travelBufferMin ?? 30;
  const durationMin = resolveDurationMin(
    service || { category: resolvedCategory, estimatedDurationMin: 0 }
  );
  const { start: scheduledStart, end: scheduledEnd } = computeScheduledWindow({
    scheduledDate,
    scheduledTime,
    timezone: worker.timezone || 'Africa/Cairo',
    durationMin,
    bufferMin,
  });
  const paymentDeadline = paymentMethod === 'online'
    ? new Date(Date.now() + 30 * 60 * 1000)
    : undefined;
  const paymentData = await resolvePaymentData(userId, paymentMethod, savedCardId, inputPaymentMeta);

  // ── Type A specific-service price snapshots (P3: graceful degradation when
  // the service's seedRange is not yet configured — holdCeiling falls to 0,
  // estimatedTotal remains set via feeSnapshot above) ─────────────────────
  const seedRange = service
    ? { min: service.seedRange?.min || 0, max: service.seedRange?.max || 0 }
    : { min: 0, max: 0 };
  const startsFromSnapshot = service ? bookingPrice : 0;
  const holdCeiling = seedRange.max || 0;

  // ── Session-wrapped overlap check + create ───────────────────────────────
  const session = await mongoose.startSession();
  let booking;
  try {
    session.startTransaction();

    const enforceOverlap = process.env.OVERLAP_ENFORCEMENT_ENABLED !== 'false';
    if (enforceOverlap) {
      const overlapping = await Booking.findOne({
        worker:         workerId,
        status:         { $in: ACTIVE_SLOT_STATUSES },
        scheduledStart: { $lt: scheduledEnd },
        scheduledEnd:   { $gt: scheduledStart },
      }).session(session);

      if (overlapping) {
        console.info(JSON.stringify({
          event: 'bookings.overlap_rejected',
          workerId: String(workerId),
          requestedStart: scheduledStart.toISOString(),
          requestedEnd:   scheduledEnd.toISOString(),
          conflictingBookingId: String(overlapping._id),
        }));
        throw new ApiError(
          StatusCodes.CONFLICT,
          'This technician already has a job during the selected time. Please choose another slot.'
        );
      }
    }

    try {
      const docs = await Booking.create([{
        user:            userId,
        worker:          workerId,
        service:         serviceId || undefined,
        serviceCategory: resolvedCategory,
        serviceName:     resolvedName,
        scheduledDate:   bookingDateUTC,
        scheduledTime,
        scheduledStart,
        scheduledEnd,
        estimatedDurationMin: durationMin,
        travelBufferMin:      bufferMin,
        address,
        description,
        images,
        totalPrice:      bookingPrice,
        paymentMethod:    paymentData.paymentMethod,
        savedCard:        paymentData.savedCard,
        paymentMeta:      paymentData.paymentMeta,
        paymentStatus:    paymentData.paymentStatus,
        paymentDeadline,
        ...feeSnapshot,
        ...(service ? { startsFromSnapshot, seedRangeSnapshot: seedRange, holdCeiling } : {}),
      }], { session });
      booking = docs[0];
    } catch (err) {
      if (err && err.code === 11000) {
        throw new ApiError(
          StatusCodes.CONFLICT,
          'This time slot is already booked. Please select another.'
        );
      }
      throw err;
    }

    await session.commitTransaction();
  } catch (err) {
    if (session.inTransaction()) {
      await session.abortTransaction();
    }
    throw err;
  } finally {
    session.endSession();
  }

  const populated = await booking.populate(['user', 'worker', 'service', 'savedCard']);
  notifSvc.notifyBookingCreated(populated);
  return populated;
};


async function resolvePaymentData(userId, paymentMethod, savedCardId, inputPaymentMeta) {
  if (paymentMethod === 'cash') {
    return {
      paymentMethod: 'cash',
      savedCard:    undefined,
      paymentMeta:  undefined,
      paymentStatus: 'cash_pending_settlement',
    };
  }

  if (paymentMethod === 'online') {
    // Demo-card path: snapshot card metadata (stripping cvv) and mark demo_pending
    const hasDemoCard = inputPaymentMeta && (inputPaymentMeta.last4 || inputPaymentMeta.cardType || inputPaymentMeta.label);
    if (hasDemoCard) {
      const { cvv, ...safeMeta } = inputPaymentMeta;
      return {
        paymentMethod: 'online',
        savedCard:    undefined,
        paymentMeta:  safeMeta,
        paymentStatus: 'demo_pending',
      };
    }
    return {
      paymentMethod: 'online',
      savedCard:    undefined,
      paymentMeta:  undefined,
      paymentStatus: 'unpaid',
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
    paymentStatus: 'unpaid',
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
      .populate('worker', 'name profileImage averageRating availability availabilityType isAvailable')
      .populate('service', 'title category basePrice priceUnit')
      .populate('savedCard', 'last4 expiry cardType label isDefault')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(Number(limit)),
    Booking.countDocuments(filter),
  ]);

  await autoCancelExpiredBookings(bookings);

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

  await autoCancelExpiredBookings(bookings);

  return { bookings, pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) } };
};

/**
 * GET ALL BOOKINGS (Admin Only)
 * WHAT: Global view of every booking in the system.
 */
const getAllBookings = async ({ status, flagged, page = 1, limit = 10 }) => {
  const filter = {};
  if (status) filter.status = status;
  if (flagged === 'true' || flagged === true) filter.flaggedForReview = true;

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

  await autoCancelExpiredBookings(bookings);

  return { bookings, pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) } };
};

/**
 * UPDATE BOOKING STATUS
 * WHAT: Transitions a booking (pending -> accepted -> in_progress -> completed).
 * WHY:  Enforces rules (e.g., users can cancel, but only workers can accept).
 */
const updateBookingStatus = async (bookingId, newStatus, actorId, actorRole, details = {}) => {
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
  if (actorRole === 'user') {
    if (newStatus === 'cancelled' && booking.status !== 'pending') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'You can only cancel a booking that is still pending.');
    }
    if ((newStatus === 'completed' || newStatus === 'disputed') && booking.status !== 'awaiting_customer_confirmation') {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'You can only confirm or dispute a booking that is awaiting your confirmation.');
    }
  }

  // ── Worker mid-job estimate update (no status transition) ────────────────
  if (actorRole === 'worker' && newStatus === 'in_progress' && booking.status === 'in_progress' && details.estimatedDurationMin) {
    const override = Number(details.estimatedDurationMin);
    if (!Number.isFinite(override) || override < 15 || override > 480) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Estimated duration must be between 15 and 480 minutes.');
    }
    const bufferMin   = booking.travelBufferMin || 30;
    // Anchor on whichever is LATER — early start should not shrink the customer's
    // originally reserved window; late start must push the end out.
    const anchorStart = booking.actualStartedAt && booking.actualStartedAt > booking.scheduledStart
      ? booking.actualStartedAt
      : booking.scheduledStart;
    const newEnd      = new Date(anchorStart.getTime() + (override + bufferMin) * 60_000);
    const collision = await Booking.findOne({
      _id:            { $ne: booking._id },
      worker:         booking.worker,
      status:         { $in: ACTIVE_SLOT_STATUSES },
      scheduledStart: { $lt: newEnd },
      scheduledEnd:   { $gt: anchorStart },
    });
    if (collision) {
      throw new ApiError(
        StatusCodes.CONFLICT,
        'The requested duration would overlap your next booking. Reduce or move it first.'
      );
    }
    booking.estimatedDurationMin = override;
    booking.scheduledEnd         = newEnd;
    if (booking.actualStartedAt) {
      booking.estimatedFinishAt = new Date(booking.actualStartedAt.getTime() + override * 60_000);
    }
    return booking.save();
  }

  if (actorRole === 'worker') {
    const workerFlow = {
      pending: ['accepted', 'rejected'],
      accepted: ['en_route'],
      en_route: ['arrived'],
      arrived: ['in_progress'],
      in_progress: ['awaiting_customer_confirmation'],
    };
    const allowedNext = workerFlow[booking.status] || [];
    if (!allowedNext.includes(newStatus)) {
      throw new ApiError(
        StatusCodes.BAD_REQUEST,
        `Cannot move booking from '${booking.status}' to '${newStatus}'.`
      );
    }
  }

  // ── Worker accept-time duration override ─────────────────────────────────
  if (actorRole === 'worker' && newStatus === 'accepted' && details.estimatedDurationMin) {
    const override = Number(details.estimatedDurationMin);
    if (!Number.isFinite(override) || override < 15 || override > 480) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Estimated duration must be between 15 and 480 minutes.');
    }
    const newEnd = new Date(
      booking.scheduledStart.getTime() + (override + (booking.travelBufferMin || 30)) * 60_000
    );
    const collision = await Booking.findOne({
      _id:            { $ne: booking._id },
      worker:         booking.worker,
      status:         { $in: ACTIVE_SLOT_STATUSES },
      scheduledStart: { $lt: newEnd },
      scheduledEnd:   { $gt: booking.scheduledStart },
    });
    if (collision) {
      throw new ApiError(
        StatusCodes.CONFLICT,
        'The requested duration would overlap your next booking. Reduce or move it first.'
      );
    }
    booking.estimatedDurationMin = override;
    booking.scheduledEnd         = newEnd;
    await booking.save();
  }

  // Payment gate for online bookings (worker non-rejected transitions only)
  if (actorRole === 'worker' && newStatus !== 'rejected') {
    if (booking.paymentMethod === 'online') {
      if (booking.paymentDeadline && Date.now() > new Date(booking.paymentDeadline).getTime()) {
        await Booking.findByIdAndUpdate(bookingId, { status: 'cancelled' }, { runValidators: false });
        throw new ApiError(StatusCodes.GONE, 'Payment deadline expired. Booking has been cancelled.');
      }
      const Payment = require('../payments/payment.model');
      const heldPayment = await Payment.findOne({ booking: bookingId, status: 'held' });
      if (!heldPayment) {
        throw new ApiError(StatusCodes.PAYMENT_REQUIRED, 'Payment must be held before this booking can proceed.');
      }
    }
  }

  // ── Stamp execution timestamps on in_progress transition ─────────────────
  if (newStatus === 'in_progress' && !booking.actualStartedAt) {
    booking.actualStartedAt   = new Date();
    booking.estimatedFinishAt = new Date(
      booking.actualStartedAt.getTime() + (booking.estimatedDurationMin || 60) * 60_000
    );
    await booking.save();
  }

  // ── Stamp actualCompletedAt + compute actualBilledMin + anomaly check ─────
  if (newStatus === 'awaiting_customer_confirmation' && !booking.actualCompletedAt) {
    const completedAt = new Date();
    booking.actualCompletedAt = completedAt;

    if (booking.actualStartedAt) {
      const billedMin = Math.round(
        (completedAt.getTime() - booking.actualStartedAt.getTime()) / 60_000
      );
      booking.actualBilledMin = billedMin;

      // Anomaly check against category cap and estimate multiplier
      const settings = await getPublicPlatformSettings();
      const category  = (booking.serviceCategory || '').toLowerCase();
      const cap       = settings.categoryDurationCaps instanceof Map
        ? settings.categoryDurationCaps.get(category)
        : (settings.categoryDurationCaps?.[category]);
      const multiplier = settings.anomalyMultiplier || 2;
      const estimatedMin = booking.estimatedDurationMin || 60;

      const exceedsCap       = cap && billedMin > cap;
      const exceedsMultiplier = billedMin > estimatedMin * multiplier;

      if (exceedsCap || exceedsMultiplier) {
        booking.flaggedForReview = true;
        booking.needsAdminReview = true;
        booking.flagReason = exceedsCap
          ? `Actual time ${billedMin}min exceeds category cap of ${cap}min for '${category}'`
          : `Actual time ${billedMin}min is ${(billedMin / estimatedMin).toFixed(1)}× the estimate of ${estimatedMin}min`;
      }
    }

    await booking.save();
  }

  const update = { status: newStatus };
  if (newStatus === 'cancelled' && details.cancellationReason) {
    update.cancellationReason = String(details.cancellationReason).trim().slice(0, 240);
  }
  if (newStatus === 'awaiting_customer_confirmation') {
    const workerNotes = String(details.workerNotes || '').trim().slice(0, 400);
    const workerCompletionImages = Array.isArray(details.workerCompletionImages)
      ? details.workerCompletionImages
          .filter(Boolean)
          .map(url => String(url).trim())
          .filter(Boolean)
          .slice(0, 4)
      : [];
    if (workerNotes) update.workerNotes = workerNotes;
    if (workerCompletionImages.length) update.workerCompletionImages = workerCompletionImages;
  }

  const updated = await Booking.findByIdAndUpdate(
    bookingId,
    update,
    { new: true, runValidators: false }
  );

  // Increment worker's completedJobs counter when customer confirms completion
  if (updated && newStatus === 'completed' && updated.worker) {
    User.findByIdAndUpdate(updated.worker, { $inc: { completedJobs: 1 } }).catch(() => {});
  }

  // Fire-and-forget in-app notifications
  if (updated) {
    if      (newStatus === 'accepted')                       notifSvc.notifyBookingAccepted(updated);
    else if (newStatus === 'rejected')                       notifSvc.notifyBookingRejected(updated);
    else if (newStatus === 'en_route')                       notifSvc.notifyBookingEnRoute(updated);
    else if (newStatus === 'arrived')                        notifSvc.notifyBookingArrived(updated);
    else if (newStatus === 'completed')                      notifSvc.notifyBookingCompleted(updated);
    else if (newStatus === 'cancelled')                      notifSvc.notifyBookingCancelled(updated, actorRole);
    else if (newStatus === 'awaiting_customer_confirmation') notifSvc.notifyAwaitingCustomerConfirmation(updated);
    else if (newStatus === 'pending_admin_review')           notifSvc.notifyPendingAdminReview(updated);
  }

  return updated;
};

const rescheduleBooking = async (bookingId, data, actorId, actorRole) => {
  const booking = await Booking.findById(bookingId);
  if (!booking) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found.');
  }

  if (actorRole === 'user' && booking.user.toString() !== actorId.toString()) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'This is not your booking.');
  }
  if (!['user', 'admin'].includes(actorRole)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'You are not allowed to reschedule this booking.');
  }
  if (!['pending', 'accepted'].includes(booking.status)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'This booking can no longer be rescheduled online.');
  }

  const worker = await User.findOne({ _id: booking.worker, role: 'worker', isActive: true, isVerified: true });
  if (!worker) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Worker not found or not available.');
  }

  const { bookingDateUTC, bookingDateStr, scheduledHour } = normalizeSchedule(data);
  assertWorkerAvailableForSchedule(worker, bookingDateUTC, bookingDateStr, scheduledHour);

  const platformSettings = await getPublicPlatformSettings();
  const bufferMin = platformSettings.travelBufferMin ?? 30;

  // Look up service for duration; falls back to category default if not found.
  let serviceDoc = null;
  if (booking.service) {
    serviceDoc = await Service.findById(booking.service);
  }
  const durationMin = (booking.estimatedDurationMin && booking.estimatedDurationMin > 0)
    ? booking.estimatedDurationMin
    : resolveDurationMin(serviceDoc || { category: booking.serviceCategory, estimatedDurationMin: 0 });

  const { start: scheduledStart, end: scheduledEnd } = computeScheduledWindow({
    scheduledDate: data.scheduledDate,
    scheduledTime: data.scheduledTime,
    timezone: worker.timezone || 'Africa/Cairo',
    durationMin,
    bufferMin,
  });

  const session = await mongoose.startSession();
  let updated;
  try {
    session.startTransaction();

    const enforceOverlap = process.env.OVERLAP_ENFORCEMENT_ENABLED !== 'false';
    if (enforceOverlap) {
      const conflict = await Booking.findOne({
        _id:            { $ne: booking._id },
        worker:         booking.worker,
        status:         { $in: ACTIVE_SLOT_STATUSES },
        scheduledStart: { $lt: scheduledEnd },
        scheduledEnd:   { $gt: scheduledStart },
      }).session(session);

      if (conflict) {
        console.info(JSON.stringify({
          event: 'bookings.overlap_rejected',
          workerId: String(booking.worker),
          requestedStart: scheduledStart.toISOString(),
          requestedEnd:   scheduledEnd.toISOString(),
          conflictingBookingId: String(conflict._id),
        }));
        throw new ApiError(
          StatusCodes.CONFLICT,
          'This technician already has a job during the selected time. Please choose another slot.'
        );
      }
    }

    updated = await Booking.findByIdAndUpdate(
      booking._id,
      {
        scheduledDate: bookingDateUTC,
        scheduledTime: data.scheduledTime,
        scheduledStart,
        scheduledEnd,
        estimatedDurationMin: durationMin,
        travelBufferMin: bufferMin,
      },
      { new: true, runValidators: true, session }
    );

    await session.commitTransaction();
  } catch (err) {
    if (session.inTransaction()) {
      await session.abortTransaction();
    }
    throw err;
  } finally {
    session.endSession();
  }

  const populated = await Booking.findById(updated._id)
    .populate('user', 'name email phone profileImage')
    .populate('worker', 'name email phone profileImage averageRating totalReviews location locationLabel serviceArea categories skills services isVerified')
    .populate('service', 'title basePrice category');

  return populated;
};

const getBookingById = async (bookingId, requestingUser) => {
  const booking = await Booking.findById(bookingId)
    .populate('user',    'name email phone profileImage')
    .populate('worker',  'name email phone profileImage averageRating totalReviews location locationLabel serviceArea categories skills services isVerified')
    .populate('service', 'title basePrice category')
    .populate('savedCard', 'last4 expiry cardType label isDefault');

  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');

  const isUser   = booking.user._id.toString() === requestingUser.id.toString();
  const isWorker = booking.worker._id.toString() === requestingUser.id.toString();
  const isAdmin  = requestingUser.role === 'admin';
  if (!isUser && !isWorker && !isAdmin) throw new ApiError(StatusCodes.FORBIDDEN, 'Not authorized to view this booking');

  return booking;
};

const adminSettings = require('../admin/admin-settings.service');

async function markComplete({ bookingId, technicianId, notes, photos = [] }) {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
  if (String(booking.worker) !== String(technicianId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Not your booking');
  }
  if (booking.status !== 'in_progress') {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Must be in_progress (was ${booking.status})`);
  }
  const cfg = await adminSettings.get();
  booking.status = 'awaiting_customer_confirmation';
  booking.customerConfirmAutoAt = new Date(Date.now() + cfg.escrow.autoConfirmHours * 3600 * 1000);
  booking.completionNotes = notes || '';
  booking.completionPhotos = photos;
  await booking.save();
  return booking;
}

async function startWork({ bookingId, technicianId }) {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
  if (String(booking.worker) !== String(technicianId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Not your booking');
  }
  if (!['accepted', 'en_route', 'arrived'].includes(booking.status)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot start from ${booking.status}`);
  }
  booking.status = 'in_progress';
  booking.startedAt = new Date();
  await booking.save();
  return booking;
}

async function acceptBooking({ bookingId, technicianId }) {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new ApiError(StatusCodes.NOT_FOUND, 'Booking not found');
  if (booking.status !== 'pending') {
    throw new ApiError(StatusCodes.BAD_REQUEST, `Cannot accept from ${booking.status}`);
  }
  const tech = await User.findById(technicianId).select('suspendedUntil');
  if (tech?.suspendedUntil && new Date(tech.suspendedUntil) > new Date()) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Account suspended; cannot accept bookings.');
  }
  const { BookingBlockedError } = require('../../utils/ApiError');
  const cashDebtService = require('../payments/cash-debt.service');
  const cfg = await adminSettings.get();
  const debtSummary = await cashDebtService.getWorkerDebtSummary(technicianId);
  if (debtSummary.totalOutstanding >= cfg.debt.absoluteBlockThreshold) {
    throw new BookingBlockedError('absolute_block', {
      debtAmount: debtSummary.totalOutstanding,
      threshold: cfg.debt.absoluteBlockThreshold,
      settleUrl: '/technician-dashboard.html#debts',
    });
  }
  const isCash = booking.paymentType === 'cash' || booking.paymentMethod === 'cash';
  if (isCash && debtSummary.totalOutstanding >= cfg.debt.blockThreshold) {
    throw new BookingBlockedError('cash_block', {
      debtAmount: debtSummary.totalOutstanding,
      threshold: cfg.debt.blockThreshold,
      settleUrl: '/technician-dashboard.html#debts',
    });
  }
  booking.status = 'accepted';
  booking.worker = technicianId;
  booking.acceptedAt = new Date();
  await booking.save();
  return booking;
}

module.exports = { createBooking, getUserBookings, getWorkerBookings, getAllBookings, updateBookingStatus, rescheduleBooking, getBookingById, getPublicPlatformSettings, calculateFeeSnapshot, markComplete, acceptBooking, startWork };
