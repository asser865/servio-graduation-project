const { Router }          = require('express');
const auditController     = require('./audit.controller');
const settingsController  = require('./settings.controller');
const { protect }         = require('../../middleware/auth.middleware');
const { authorize }       = require('../../middleware/role.middleware');

const router = Router();

// GET /api/v1/admin/audit — admin only: paginated, filterable audit log
router.get('/audit', protect, authorize('admin'), auditController.getLogs);

// DELETE /api/v1/admin/audit/:id — admin only
router.delete('/audit/:id', protect, authorize('admin'), auditController.deleteLog);

// GET /api/v1/admin/settings — admin only
router.get('/settings', protect, authorize('admin'), settingsController.getSettings);

// PUT /api/v1/admin/settings — admin only
router.put('/settings', protect, authorize('admin'), settingsController.updateSettings);

module.exports = router;
