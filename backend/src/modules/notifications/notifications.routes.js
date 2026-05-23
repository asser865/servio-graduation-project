'use strict';

const express    = require('express');
const { protect } = require('../../middleware/auth.middleware');
const ctrl = require('./notifications.controller');

const router = express.Router();

// All routes require auth
router.use(protect);

router.get('/preferences',    ctrl.getPreferences);
router.put('/preferences',    ctrl.updatePreferences);

router.get('/',               ctrl.getNotifications);
router.get('/unread-count',   ctrl.getUnreadCount);
router.patch('/read-all',     ctrl.markAllRead);
router.patch('/:id/read',     ctrl.markOneRead);
router.delete('/',            ctrl.clearAll);
router.delete('/:id',         ctrl.deleteOne);

module.exports = router;
