// ─── Purpose ──────────────────────────────────────────────────────────────────
// Auth routes wire validation → controller. The validate() middleware runs
// express-validator checks and throws ApiError(422) before the controller
// ever executes, keeping controller logic clean.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }        = require('express');
const { body }          = require('express-validator');
const authController    = require('./auth.controller');
const { validate }      = require('../../middleware/validate.middleware');
const { protect }       = require('../../middleware/auth.middleware');
const userController    = require('../users/user.controller');

const router = Router();

// ── Validation rules ──────────────────────────────────────────────────────────
const registerValidation = [
  body('name')
    .trim()
    .notEmpty().withMessage('Name is required')
    .isLength({ max: 100 }).withMessage('Name cannot exceed 100 characters'),

  body('email')
    .trim()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Please provide a valid email address')
    .normalizeEmail(),

  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/\d/).withMessage('Password must contain at least one number'),

  body('phone')
    .optional({ checkFalsy: true })
    .isMobilePhone('any').withMessage('Please provide a valid phone number'),

  body('role')
    .optional()
    .isIn(['user', 'worker', 'customer', 'technician']).withMessage('Role must be either user or worker'),

  body('services')
    .optional()
    .isArray().withMessage('Services must be an array'),

  body('services.*')
    .optional()
    .isMongoId().withMessage('Each service must be a valid MongoDB ObjectId'),

  body('serviceArea')
    .optional({ checkFalsy: true })
    .trim()
    .isLength({ max: 200 }).withMessage('Service area cannot exceed 200 characters'),

  body('coverageAreas')
    .optional()
    .isArray().withMessage('Coverage areas must be an array'),

  body('coverageAreas.*')
    .optional()
    .isString().trim().notEmpty().isLength({ max: 100 }).withMessage('Each coverage area must be a non-empty string up to 100 characters'),
];

const loginValidation = [
  body('email')
    .trim()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Please provide a valid email address')
    .normalizeEmail(),

  body('password')
    .notEmpty().withMessage('Password is required'),
];

const forgotValidation = [
  body('email')
    .trim()
    .notEmpty().withMessage('Email is required')
    .isEmail().withMessage('Please provide a valid email address')
    .normalizeEmail(),
];

const resetValidation = [
  body('password')
    .notEmpty().withMessage('Password is required')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/\d/).withMessage('Password must contain at least one number'),
];

// ── Routes ────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/register
router.post('/register', validate(registerValidation), authController.register);

// POST /api/v1/auth/login
router.post('/login', validate(loginValidation), authController.login);

// POST /api/v1/auth/forgot-password
router.post('/forgot-password', validate(forgotValidation), authController.forgotPassword);

// POST /api/v1/auth/reset-password/:token
router.post('/reset-password/:token', validate(resetValidation), authController.resetPassword);

// GET /api/v1/auth/me — return current user (session restore)
router.get('/me', protect, userController.getMe);

module.exports = router;
