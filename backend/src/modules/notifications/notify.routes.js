'use strict';

const { Router } = require('express');
const { body }   = require('express-validator');
const notifyController = require('./notify.controller');
const { protect }      = require('../../middleware/auth.middleware');
const { authorize }    = require('../../middleware/role.middleware');
const { validate }     = require('../../middleware/validate.middleware');

const router = Router();

const subscribeValidation = [
  body('serviceCategory').trim().notEmpty().withMessage('serviceCategory is required'),
  body('serviceArea').optional().trim(),
];

router.post(
  '/',
  protect,
  authorize('user'),
  validate(subscribeValidation),
  notifyController.subscribe
);

router.delete(
  '/',
  protect,
  authorize('user'),
  notifyController.unsubscribe
);

module.exports = router;
