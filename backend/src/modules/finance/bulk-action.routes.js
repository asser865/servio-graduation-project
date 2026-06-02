const express = require('express');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');
const { permission } = require('../../middleware/permission.middleware');
const PERMS = require('../../constants/permissions');
const controller = require('./bulk-action.controller');

const ADMINS = ['admin', 'superadmin'];
const router = express.Router();

router.post(
  '/bulk/release',
  protect,
  authorize(...ADMINS),
  permission(PERMS.PAYMENTS_RELEASE),
  controller.releaseLowRiskBookings
);

module.exports = router;
