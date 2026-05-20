const { Router } = require('express');
const { body, param } = require('express-validator');
const ctrl       = require('./message.controller');
const { protect }   = require('../../middleware/auth.middleware');
const { validate }  = require('../../middleware/validate.middleware');

const router = Router();

router.use(protect);

router.post('/',
  validate([
    body('bookingId').optional().isMongoId().withMessage('Valid booking ID required'),
    body('conversationId').optional().isMongoId().withMessage('Valid conversation ID required'),
    body('receiverId').optional().isMongoId().withMessage('Valid receiver ID required'),
    body('workerId').optional().isMongoId().withMessage('Valid worker ID required'),
    body('customerId').optional().isMongoId().withMessage('Valid customer ID required'),
    body('content').optional().trim().isLength({ max: 2000 }).withMessage('Message content cannot exceed 2000 characters'),
    body('body').optional().trim().isLength({ max: 2000 }).withMessage('Message content cannot exceed 2000 characters'),
    body('text').optional().trim().isLength({ max: 2000 }).withMessage('Message content cannot exceed 2000 characters'),
  ]),
  ctrl.send
);

router.post('/conversations/start',
  validate([
    body('bookingId').optional().isMongoId().withMessage('Valid booking ID required'),
    body('receiverId').optional().isMongoId().withMessage('Valid receiver ID required'),
    body('workerId').optional().isMongoId().withMessage('Valid worker ID required'),
    body('customerId').optional().isMongoId().withMessage('Valid customer ID required'),
  ]),
  ctrl.startConversation
);
router.get('/conversations', ctrl.conversations);
router.delete('/conversations/:id',
  validate([
    param('id').isMongoId().withMessage('Valid conversation ID required'),
  ]),
  ctrl.deleteConversation
);
router.get('/conversations/:id', ctrl.list);
router.get('/unread',        ctrl.unread);
router.get('/:id',           ctrl.list);

module.exports = router;
