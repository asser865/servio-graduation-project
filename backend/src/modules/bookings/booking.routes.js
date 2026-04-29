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
  body('serviceId').notEmpty().isMongoId().withMessage('Valid service ID is required'),
  body('scheduledDate').notEmpty().isISO8601().withMessage('Scheduled date must be a valid date'),
  body('address').trim().notEmpty().withMessage('Address is required'),
];

const statusValidation = [
  body('status')
    .notEmpty()
    .isIn(['pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled', 'disputed'])
    .withMessage('Invalid status value'),
];

// POST /api/v1/bookings — authenticated user creates a booking
router.post('/', protect, authorize('user'), validate(createValidation), bookingController.create);

// GET /api/v1/bookings/my — user views own bookings
router.get('/my', protect, bookingController.getMyBookings);

// GET /api/v1/bookings/worker — worker views assigned bookings
router.get('/worker', protect, authorize('worker'), bookingController.getWorkerBookings);

// GET /api/v1/bookings — admin views all bookings
router.get('/', protect, authorize('admin'), bookingController.getAllBookings);

// PATCH /api/v1/bookings/:id/status — worker or admin changes status
router.patch(
  '/:id/status',
  protect,
  authorize('worker', 'admin', 'user'),
  validate(statusValidation),
  bookingController.updateStatus
);

// GET /api/v1/bookings/:id — view a single booking (user, worker, or admin)
router.get('/:id', protect, bookingController.getBookingById);

module.exports = router;
