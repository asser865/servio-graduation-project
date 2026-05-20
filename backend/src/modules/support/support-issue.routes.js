const express = require('express');
const controller = require('./support-issue.controller');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');

const router = express.Router();

router.post('/issues', protect, authorize('user'), controller.createIssue);
router.get('/issues/my', protect, authorize('user'), controller.getMyIssues);
router.get('/issues/admin', protect, authorize('admin'), controller.getAdminIssues);
router.patch('/issues/:id/status', protect, authorize('admin'), controller.updateStatus);
router.patch('/issues/:id/resolve', protect, authorize('admin'), controller.resolveIssue);
router.patch('/issues/:id/escalate-dispute', protect, authorize('admin'), controller.escalateToDispute);

module.exports = router;
