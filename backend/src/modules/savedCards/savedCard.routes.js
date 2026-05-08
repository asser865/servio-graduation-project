const express = require('express');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');
const ctrl = require('./savedCard.controller');

const router = express.Router();

router.get('/', protect, authorize('user'), ctrl.getCards);
router.post('/', protect, authorize('user'), ctrl.addCard);
router.delete('/:id', protect, authorize('user'), ctrl.deleteCard);
router.patch('/:id/default', protect, authorize('user'), ctrl.setDefault);

module.exports = router;
