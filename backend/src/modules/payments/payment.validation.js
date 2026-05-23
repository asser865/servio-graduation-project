const { body, param } = require('express-validator');

const objectId = (field) => param(field).isMongoId().withMessage(`${field} invalid`);

const confirmBooking = [
  objectId('bookingId'),
  body('rating').optional().isInt({ min: 1, max: 5 }),
  body('comment').optional().isString().isLength({ max: 1000 }),
  body('tags').optional().isArray({ max: 10 }),
];

const openDispute = [
  objectId('bookingId'),
  body('reasonCategory').isIn(['work_not_done', 'quality', 'price_mismatch', 'damage', 'other']),
  body('details').isString().isLength({ min: 20, max: 2000 }),
  body('photos').optional().isArray({ max: 4 }),
];

const holdPayment = [
  objectId('bookingId'),
  body('savedCardId').optional().isMongoId(),
];

const refundPayment = [
  objectId('paymentId'),
  body('reason').optional().isString().isLength({ max: 500 }),
  body('amount').optional().isFloat({ gt: 0 }),
];

module.exports = { confirmBooking, openDispute, holdPayment, refundPayment };
