const express = require('express');
const controller = require('./contact-message.controller');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');

const router = express.Router();

router.post('/', controller.create);
router.get('/', protect, authorize('admin'), controller.getAll);
router.patch('/:id', protect, authorize('admin'), controller.update);

module.exports = router;
