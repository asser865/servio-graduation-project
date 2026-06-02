// ─── Purpose ──────────────────────────────────────────────────────────────────
// Booking routes — specific paths first to avoid collision with param routes.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }            = require('express');
const { body }              = require('express-validator');
const bookingController     = require('./booking.controller');
const { protect }           = require('../../middleware/auth.middleware');
const { authorize }         = require('../../middleware/role.middleware');
const { validate }          = require('../../middleware/validate.middleware');

const router = Router();

const createValidation = [
  body('workerId').notEmpty().isMongoId().withMessage('Valid worker ID is required'),
  body('serviceId').optional({ checkFalsy: true }).isMongoId().withMessage('Valid service ID is required'),
  body('serviceCategory').if(body('serviceId').isEmpty()).notEmpty().withMessage('Service category is required if no specific service is selected'),
  body('scheduledDate').notEmpty().isISO8601().withMessage('Scheduled date must be a valid date'),
  body('address').trim().notEmpty().withMessage('Address is required'),
  body('paymentMethod').notEmpty().isIn(['cash', 'card', 'online']).withMessage('Payment method must be cash, card, or online'),
  body('savedCardId').optional({ checkFalsy: true }).isMongoId().withMessage('Valid saved card ID is required'),
  body('paymentMeta').optional().isObject().withMessage('Payment metadata must be an object'),
];

const statusValidation = [
  body('status')
    .notEmpty()
    .isIn(['pending', 'accepted', 'en_route', 'arrived', 'rejected', 'in_progress', 'awaiting_customer_confirmation', 'pending_admin_review', 'completed', 'cancelled', 'disputed'])
    .withMessage('Invalid status value'),
  body('cancellationReason').optional({ checkFalsy: true }).isString().trim().isLength({ max: 240 }).withMessage('Cancellation reason is too long'),
  body('workerNotes').optional({ checkFalsy: true }).isString().trim().isLength({ max: 400 }).withMessage('Completion notes are too long'),
  body('workerCompletionImages').optional().isArray({ max: 4 }).withMessage('Too many completion images'),
  body('workerCompletionImages.*').optional({ checkFalsy: true }).isURL({ require_protocol: true }).withMessage('Completion image must be a valid URL'),
  body('estimatedDurationMin').optional({ checkFalsy: true }).isInt({ min: 15, max: 480 })
    .withMessage('Estimated duration must be 15–480 minutes'),
];

const scheduleValidation = [
  body('scheduledDate').notEmpty().isISO8601().withMessage('Scheduled date must be a valid date'),
  body('scheduledTime')
    .notEmpty()
    .matches(/^(0[0-9]|1[0-9]|2[0-3]):00$/)
    .withMessage('Scheduled time must be a whole-hour slot in HH:00 format'),
];

// POST /api/v1/bookings — authenticated user creates a booking
router.post('/', protect, authorize('user'), validate(createValidation), bookingController.create);

// GET /api/v1/bookings/my — user views own bookings
router.get('/my', protect, bookingController.getMyBookings);

// GET /api/v1/bookings/worker — worker views assigned bookings
router.get('/worker', protect, authorize('worker'), bookingController.getWorkerBookings);

// GET /api/v1/bookings — admin views all bookings
router.get('/', protect, authorize('admin'), bookingController.getAllBookings);

// Admin exception queue for pending customer refusal responses.
router.get('/admin/refusal-verifications', protect, authorize('admin'), bookingController.getRefusalsAwaitingResponse);

// GET /api/v1/bookings/worker/:workerId/slots — get booked time slots for a worker on a date
router.get('/worker/:workerId/slots', protect, bookingController.getWorkerBookedSlots);

router.patch(
  '/:id/schedule',
  protect,
  authorize('user', 'admin'),
  validate(scheduleValidation),
  bookingController.reschedule
);

// PATCH /api/v1/bookings/:id/status — worker or admin changes status
router.patch(
  '/:id/status',
  protect,
  authorize('worker', 'admin', 'user'),
  validate(statusValidation),
  bookingController.updateStatus
);

const cancelValidation = [
  body('reason').optional({ checkFalsy: true }).isString().trim().isLength({ max: 240 }),
];
const noShowValidation = [
  body('note').optional({ checkFalsy: true }).isString().trim().isLength({ max: 240 }),
  body('evidence').optional().isArray({ max: 8 }),
  body('evidence.*').optional({ checkFalsy: true }).isURL({ require_protocol: true }),
];

const completeValidation = [
  body('notes').optional({ checkFalsy: true }).isString().trim().isLength({ max: 400 }),
  body('photos').optional().isArray({ max: 4 }),
  body('photos.*').optional({ checkFalsy: true }).isURL({ require_protocol: true }),
];

// POST /api/v1/bookings/:id/accept — worker accepts booking (runs cash-debt gate)
router.post('/:id/accept', protect, authorize('worker'), bookingController.acceptBooking);

// POST /api/v1/bookings/:id/start — worker starts the job
router.post('/:id/start', protect, authorize('worker'), bookingController.startBooking);

// POST /api/v1/bookings/:id/complete — worker marks job complete
router.post('/:id/complete',
  protect,
  authorize('worker'),
  validate(completeValidation),
  bookingController.completeBooking
);

// POST /api/v1/bookings/:id/completion-outcome — worker submits completion outcome
router.post('/:id/completion-outcome',
  protect,
  authorize('worker'),
  bookingController.submitCompletionOutcome
);

// POST /api/v1/bookings/:id/customer-feedback — customer confirms or reports issue
router.post('/:id/customer-feedback',
  protect,
  authorize('user'),
  bookingController.submitCustomerFeedback
);

router.post('/:id/refusal-verification',
  protect,
  authorize('user'),
  bookingController.respondToRefusalVerification
);

// POST /api/v1/bookings/:id/cancel — customer or worker cancels (Plan 3 Task 6)
router.post('/:id/cancel',
  protect,
  authorize('user', 'worker'),
  validate(cancelValidation),
  bookingController.cancelBooking
);

// POST /api/v1/bookings/:id/no-show/customer — worker reports customer no-show (Plan 3 Task 19)
router.post('/:id/no-show/customer',
  protect,
  authorize('worker'),
  validate(noShowValidation),
  bookingController.markCustomerNoShow
);

// POST /api/v1/bookings/:id/no-show/worker — customer reports worker no-show (Plan 3 Task 19)
router.post('/:id/no-show/worker',
  protect,
  authorize('user'),
  validate(noShowValidation),
  bookingController.markWorkerNoShow
);

// GET /api/v1/bookings/:id — view a single booking (user, worker, or admin)
router.get('/:id', protect, bookingController.getBookingById);

module.exports = router;
