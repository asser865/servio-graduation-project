const { Router } = require('express');
const { body }   = require('express-validator');
const ctrl       = require('./message.controller');
const { protect }   = require('../../middleware/auth.middleware');
const { validate }  = require('../../middleware/validate.middleware');

const router = Router();

router.use(protect);

router.post('/',
  validate([
    body('bookingId').notEmpty().isMongoId().withMessage('Valid booking ID required'),
    body('content').trim().notEmpty().withMessage('Message content required'),
  ]),
  ctrl.send
);

router.get('/conversations', ctrl.conversations);
router.get('/unread',        ctrl.unread);
router.get('/:bookingId',    ctrl.list);

module.exports = router;
