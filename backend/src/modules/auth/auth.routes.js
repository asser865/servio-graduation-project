// ─── Purpose ──────────────────────────────────────────────────────────────────
// Auth routes wire validation → controller. The validate() middleware runs
// express-validator checks and throws ApiError(422) before the controller
// ever executes, keeping controller logic clean.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }        = require('express');
const { body }          = require('express-validator');
const authController    = require('./auth.controller');
const { validate }      = require('../../middleware/validate.middleware');

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
    .optional()
    .isMobilePhone().withMessage('Please provide a valid phone number'),

  body('role')
    .optional()
    .isIn(['user', 'worker']).withMessage('Role must be either user or worker'),
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

// ── Routes ────────────────────────────────────────────────────────────────────
// POST /api/v1/auth/register
router.post('/register', validate(registerValidation), authController.register);

// POST /api/v1/auth/login
router.post('/login', validate(loginValidation), authController.login);

module.exports = router;
