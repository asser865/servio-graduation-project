// ─── Purpose ──────────────────────────────────────────────────────────────────
// User routes cover: public worker discovery, authenticated profile management,
// and admin user management. Admin analytics is included here to avoid creating
// a separate admin module for just a few routes.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }    = require('express');
const { body }      = require('express-validator');
const userController = require('./user.controller');
const { protect }   = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');
const { validate }  = require('../../middleware/validate.middleware');

const router = Router();

// ── Validation schemas ────────────────────────────────────────────────────────
const profileUpdateValidation = [
  body('name').optional().trim().notEmpty().withMessage('Name cannot be empty'),
  body('phone').optional().trim().matches(/^[+]?[\d\s\-().]{7,20}$/).withMessage('Invalid phone number'),
  body('profileImage').optional().isURL().withMessage('Profile image must be a valid URL'),
  body('address').optional().isObject().withMessage('Address must be an object'),
  body('address.street').optional().trim().isLength({ max: 200 }).withMessage('Street cannot exceed 200 characters'),
  body('address.city').optional().trim().isLength({ max: 100 }).withMessage('City cannot exceed 100 characters'),
  body('address.state').optional().trim().isLength({ max: 100 }).withMessage('State cannot exceed 100 characters'),
  body('address.zipCode').optional().trim().isLength({ max: 30 }).withMessage('Zip code cannot exceed 30 characters'),
  body('bio').optional().trim().isLength({ max: 1000 }).withMessage('Bio cannot exceed 1000 characters'),
  body('hourlyRate').optional().isFloat({ min: 0 }).withMessage('Hourly rate must be a non-negative number'),
  body('locationLabel').optional().trim().isLength({ max: 200 }).withMessage('Location label too long'),
  body('yearsExperience').optional().isInt({ min: 0 }).withMessage('Years of experience must be a non-negative integer'),
  body('availabilityType').optional().isIn(['weekdays', 'weekends', 'both', '']).withMessage('Invalid availability type'),
  body('skills').optional().isArray().withMessage('Skills must be an array'),
  body('skills.*').optional().isString().trim().notEmpty().withMessage('Each skill must be a non-empty string'),
  body('categories').optional().isArray().withMessage('Categories must be an array'),
  body('categories.*').optional().isIn(['plumbing','electrical','painting','flooring','carpentry','cleaning','hvac','other']).withMessage('Invalid category'),
  body('services').optional().isArray().withMessage('Services must be an array'),
  body('services.*').optional().isMongoId().withMessage('Each service must be a valid MongoDB ObjectId'),
];

const emailUpdateValidation = [
  body('newEmail')
    .trim()
    .notEmpty().withMessage('New email is required')
    .isEmail().withMessage('Invalid email address')
    .normalizeEmail(),
  body('currentPassword')
    .isString()
    .notEmpty().withMessage('Current password is required'),
];

const availabilityValidation = [
  body('availability').isArray({ min: 1 }).withMessage('Availability must be an array'),
  body('availability.*.day')
    .isIn(['monday','tuesday','wednesday','thursday','friday','saturday','sunday'])
    .withMessage('Invalid day'),
  body('availability.*.from').notEmpty().withMessage('From time is required'),
  body('availability.*.to').notEmpty().withMessage('To time is required'),
];

// ── Public routes — worker discovery ──────────────────────────────────────────
// GET /api/v1/users/workers — public list of verified, active workers
router.get('/workers', userController.getWorkers);

// GET /api/v1/users/workers/:id — public worker profile + reviews
router.get('/workers/:id', userController.getWorkerProfile);

// ── Authenticated user routes ─────────────────────────────────────────────────
// GET /api/v1/users/me — get own profile
router.get('/me', protect, userController.getMe);

// PATCH /api/v1/users/me — update own profile
router.patch('/me', protect, validate(profileUpdateValidation), userController.updateProfile);

// PATCH /api/v1/users/me/email — update own email and invalidate session
router.patch('/me/email', protect, validate(emailUpdateValidation), userController.updateEmail);

// PATCH /api/v1/users/me/password — update own password
router.patch('/me/password', protect, userController.updatePassword);

// DELETE /api/v1/users/me — delete own profile
router.delete('/me', protect, userController.deleteMe);

// PATCH /api/v1/users/me/availability — worker updates availability
router.patch(
  '/me/availability',
  protect,
  authorize('worker'),
  validate(availabilityValidation),
  userController.updateAvailability
);

// ── Admin user management routes ──────────────────────────────────────────────
// GET /api/v1/users — admin: list all users
router.get('/', protect, authorize('admin'), userController.getAllUsers);

// PATCH /api/v1/users/:id/status — admin: activate/deactivate
router.patch('/:id/status', protect, authorize('admin'), userController.updateUserStatus);

// PATCH /api/v1/users/workers/:id/verify — admin: approve/reject worker
router.patch('/workers/:id/verify', protect, authorize('admin'), userController.verifyWorker);

// DELETE /api/v1/users/:id — admin: permanent delete
router.delete('/:id', protect, authorize('admin'), userController.deleteUser);

// GET /api/v1/users/analytics — admin: counts and stats
router.get('/analytics', protect, authorize('admin'), userController.getAnalytics);

// GET /api/v1/users/analytics/payments — admin: payment revenue and financials
router.get('/analytics/payments', protect, authorize('admin'), userController.getPaymentAnalytics);

module.exports = router;
