// ─── Purpose ──────────────────────────────────────────────────────────────────
// Service routes — public GET routes for browsing, admin-only mutation routes.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }           = require('express');
const { body }             = require('express-validator');
const serviceController    = require('./service.controller');
const { protect }          = require('../../middleware/auth.middleware');
const { authorize }        = require('../../middleware/role.middleware');
const { validate }         = require('../../middleware/validate.middleware');

const router = Router();

const serviceValidation = [
  body('title').trim().notEmpty().withMessage('Title is required'),
  body('description').trim().notEmpty().withMessage('Description is required'),
  body('category')
    .isIn(['plumbing', 'electrical', 'painting', 'flooring', 'carpentry', 'cleaning', 'hvac', 'other'])
    .withMessage('Invalid category'),
  body('basePrice').isFloat({ min: 0 }).withMessage('Base price must be a positive number'),
  body('priceUnit')
    .isIn(['per_hour', 'per_sqm', 'fixed'])
    .withMessage('Price unit must be per_hour, per_sqm, or fixed'),
];

// ── Public routes ─────────────────────────────────────────────────────────────
router.get('/',    serviceController.getAll);
router.get('/:id', serviceController.getOne);

// GET /api/v1/services/:serviceId/technicians — list workers assigned to a service
router.get('/:serviceId/technicians', serviceController.getTechnicians);

// ── Admin-only routes ─────────────────────────────────────────────────────────
router.post(
  '/',
  protect,
  authorize('admin'),
  validate(serviceValidation),
  serviceController.create
);

router.put(
  '/:id',
  protect,
  authorize('admin'),
  validate(serviceValidation),
  serviceController.update
);

router.delete('/:id', protect, authorize('admin'), serviceController.remove);

module.exports = router;
