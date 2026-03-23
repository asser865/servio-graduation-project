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
  body('phone').optional().isMobilePhone().withMessage('Invalid phone number'),
  body('profileImage').optional().isURL().withMessage('Profile image must be a valid URL'),
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
// PATCH /api/v1/users/me — update own profile
router.patch('/me', protect, validate(profileUpdateValidation), userController.updateProfile);

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

// GET /api/v1/users/analytics — admin: counts and stats
router.get('/analytics', protect, authorize('admin'), userController.getAnalytics);

module.exports = router;
