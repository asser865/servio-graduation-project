const express = require('express');
const controller = require('./problem-report.controller');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');

const router = express.Router();

router.post('/problems', protect, authorize('user'), controller.createReport);
router.get('/problems', protect, authorize('admin'), controller.getAllReports);
router.patch('/problems/:id', protect, authorize('admin'), controller.updateReport);

module.exports = router;
