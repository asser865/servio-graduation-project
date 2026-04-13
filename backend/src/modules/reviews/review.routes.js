// ─── Purpose ──────────────────────────────────────────────────────────────────
// Review routes — public GET for worker profiles, protected POST for users.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }       = require('express');
const { body }         = require('express-validator');
const reviewController = require('./review.controller');
const { protect }      = require('../../middleware/auth.middleware');
const { authorize }    = require('../../middleware/role.middleware');
const { validate }     = require('../../middleware/validate.middleware');

const router = Router();

const createValidation = [
  body('bookingId').notEmpty().isMongoId().withMessage('Valid booking ID is required'),
  body('rating').notEmpty().isInt({ min: 1, max: 5 }).withMessage('Rating must be between 1 and 5'),
  body('comment').optional().trim().isLength({ max: 1000 }).withMessage('Comment is too long'),
];

// POST /api/v1/reviews — authenticated user only
router.post('/', protect, authorize('user'), validate(createValidation), reviewController.createReview);

// GET /api/v1/reviews/worker/:workerId — public
router.get('/worker/:workerId', reviewController.getWorkerReviews);

// DELETE /api/v1/reviews/:id — admin only
router.delete('/:id', protect, authorize('admin'), reviewController.deleteReview);

module.exports = router;
