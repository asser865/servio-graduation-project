const express = require('express');
const { protect } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/role.middleware');
const controller = require('./payment.controller');

const router = express.Router();

router.post(
  '/confirm/:bookingId',
  protect,
  authorize('user'),
  controller.confirmCompletion
);

router.get(
  '/booking/:bookingId',
  protect,
  authorize('user', 'worker', 'admin'),
  controller.getMyPayment
);

router.get(
  '/earnings',
  protect,
  authorize('worker'),
  controller.getWorkerEarnings
);

router.patch(
  '/settings',
  protect,
  authorize('worker'),
  controller.updatePayoutSettings
);

router.post(
  '/refund/:paymentId',
  protect,
  authorize('admin'),
  controller.adminRefund
);

router.post(
  '/disputes',
  protect,
  authorize('user'),
  controller.openDispute
);

router.patch(
  '/disputes/:id/resolve',
  protect,
  authorize('admin'),
  controller.resolveDispute
);

router.get(
  '/disputes',
  protect,
  authorize('admin'),
  controller.getDisputes
);

module.exports = router;
