const express    = require('express');
const { protect }    = require('../../middleware/auth.middleware');
const { authorize }  = require('../../middleware/role.middleware');
const controller = require('./payment.controller');

const router = express.Router();

// Customer: hold payment in escrow
router.post('/hold/:bookingId', protect, authorize('user'), controller.holdPayment);

// Customer: confirm service complete → pending_admin_review
router.post('/confirm/:bookingId', protect, authorize('user'), controller.confirmCompletion);

// Admin: approve completion (release escrow or create cash debt)
router.post('/admin/approve/:bookingId', protect, authorize('admin'), controller.adminApproveCompletion);

router.patch(
  '/settings',
  protect,
  authorize('worker'),
  controller.updatePayoutSettings
);

// Admin: reject cash booking
router.post('/admin/reject-cash/:bookingId', protect, authorize('admin'), controller.adminRejectCash);

// Admin: list bookings pending approval
router.get('/admin/pending-approvals', protect, authorize('admin'), controller.getPendingApprovals);

// Admin: list cash debts
router.get('/admin/cash-debts', protect, authorize('admin'), controller.getCashDebts);

// Admin: mark cash debt paid (full or partial)
router.patch('/admin/cash-debts/:id/mark-paid', protect, authorize('admin'), controller.markCashDebtPaid);

// Worker: view own cash debts
router.get('/my-debts', protect, authorize('worker'), controller.getMyDebts);

// Read / existing
router.get('/booking/:bookingId', protect, authorize('user', 'worker', 'admin'), controller.getMyPayment);
router.get('/earnings', protect, authorize('worker'), controller.getWorkerEarnings);
router.post('/refund/:paymentId', protect, authorize('admin'), controller.adminRefund);
router.post('/disputes', protect, authorize('user'), controller.openDispute);
router.patch('/disputes/:id/resolve', protect, authorize('admin'), controller.resolveDispute);
router.get('/disputes', protect, authorize('admin'), controller.getDisputes);

module.exports = router;
