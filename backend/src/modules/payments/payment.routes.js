const express    = require('express');
const { protect }    = require('../../middleware/auth.middleware');
const { authorize }  = require('../../middleware/role.middleware');
const { permission } = require('../../middleware/permission.middleware');
const PERMS = require('../../constants/permissions');
const controller = require('./payment.controller');

const ADMINS = ['admin', 'superadmin'];

const router = express.Router();

// Customer: hold payment in escrow
router.post('/hold/:bookingId', protect, authorize('user'), controller.holdPayment);

// Customer: confirm service complete → pending_admin_review
router.post('/confirm/:bookingId', protect, authorize('user'), controller.confirmCompletion);

// Admin: approve completion for held card/online escrow only.
router.post('/admin/approve/:bookingId', protect, authorize(...ADMINS), permission(PERMS.PAYMENTS_RELEASE), controller.adminApproveCompletion);

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

// Admin: grouped cash debts (Plan 2 Task 11)
router.get('/admin/cash-debts/grouped', protect, authorize('admin'), controller.adminListCashDebtsGrouped);
router.get('/admin/cash-debts/by-worker/:workerId', protect, authorize('admin'), controller.adminListWorkerDebts);

// Admin: send debt reminder notification to worker
router.post('/admin/cash-debts/remind/:workerId', protect, authorize(...ADMINS), permission(PERMS.CASH_DEBTS_WRITE), controller.adminSendDebtReminder);

// Admin: mark cash debt paid (full or partial)
router.patch('/admin/cash-debts/:id/mark-paid', protect, authorize(...ADMINS), permission(PERMS.CASH_DEBTS_WRITE), controller.markCashDebtPaid);

// Worker: view own cash debts
router.get('/my-debts', protect, authorize('worker'), controller.getMyDebts);

// Worker: new debt + settlement endpoints
router.get('/my-debts/v2', protect, authorize('worker'), controller.getMyDebtsV2);
router.post('/my-debts/settle', protect, authorize('worker'), controller.settleMyDebt);
router.get('/my-settlements', protect, authorize('worker'), controller.getMySettlements);

// Admin: settlements
router.get('/admin/settlements/history.csv', protect, authorize('admin'), controller.adminSettlementHistoryCsv);
router.get('/admin/settlements', protect, authorize('admin'), controller.adminListSettlements);
router.patch('/admin/settlements/:id/verify', protect, authorize(...ADMINS), permission(PERMS.SETTLEMENTS_VERIFY), controller.adminVerifySettlement);
router.patch('/admin/settlements/:id/reject', protect, authorize(...ADMINS), permission(PERMS.SETTLEMENTS_REJECT), controller.adminRejectSettlement);

// Payouts
router.post('/payout-request', protect, authorize('worker'), controller.createPayoutRequest);
router.get('/my-payouts', protect, authorize('worker'), controller.myPayouts);
router.get('/admin/payout-requests', protect, authorize('admin'), controller.adminListPayouts);
router.patch('/admin/payout-requests/:id/approve', protect, authorize(...ADMINS), permission(PERMS.PAYOUTS_APPROVE), controller.adminApprovePayout);
router.patch('/admin/payout-requests/:id/mark-paid', protect, authorize(...ADMINS), permission(PERMS.PAYOUTS_MARK_PAID), controller.adminMarkPayoutPaid);
router.patch('/admin/payout-requests/:id/reject', protect, authorize(...ADMINS), permission(PERMS.PAYOUTS_REJECT), controller.adminRejectPayout);

// Worker: own transaction history (Plan 2 Task 20)
router.get('/my-transactions', protect, authorize('worker'), controller.getMyTransactions);

// Customer: unified transaction history (Plan 3 Task 16)
router.get('/me/history', protect, authorize('user'), controller.getCustomerHistory);

// Customer credits (Plan 3 Tasks 9, 11)
router.get('/me/credits', protect, authorize('user'), controller.getMyCustomerCredits);
router.post('/admin/credits/issue', protect, authorize(...ADMINS), permission(PERMS.CREDITS_ISSUE), controller.adminIssueCustomerCredit);

// Invoices (Plan 3 Task 15 — list mine)
router.get('/me/invoices', protect, authorize('user', 'worker'), controller.getMyInvoices);

// Receipt download (Plan 3 Task 15)
router.get('/:id/receipt', protect, authorize('user', 'worker', 'admin'), controller.downloadReceipt);

// Read / existing
router.get('/booking/:bookingId', protect, authorize('user', 'worker', 'admin'), controller.getMyPayment);
router.get('/earnings/history', protect, authorize('worker'), controller.getWorkerEarningsHistory);
router.get('/earnings', protect, authorize('worker'), controller.getWorkerEarnings);
router.post('/refund/:paymentId', protect, authorize(...ADMINS), permission(PERMS.PAYMENTS_REFUND), controller.adminRefund);

// Emergency admin actions (Plan 4 Task 4)
router.post('/admin/:id/force-release', protect, authorize(...ADMINS), permission(PERMS.PAYMENTS_EMERGENCY), controller.adminForceRelease);
router.post('/admin/:id/force-lock',    protect, authorize(...ADMINS), permission(PERMS.PAYMENTS_EMERGENCY), controller.adminForceLock);
router.post('/admin/:id/force-unlock',  protect, authorize(...ADMINS), permission(PERMS.PAYMENTS_EMERGENCY), controller.adminForceUnlock);
router.post('/admin/partial-refund/:bookingId', protect, authorize(...ADMINS), permission(PERMS.PAYMENTS_REFUND), controller.adminPartialRefund);
router.get('/admin/payments',       protect, authorize('admin'), controller.adminListPayments);
router.get('/admin/payments/:id/detail', protect, authorize('admin'), controller.adminPaymentDetail);
router.get('/admin/payments/stats', protect, authorize('admin'), controller.adminPaymentsStats);
router.post('/disputes', protect, authorize('user'), controller.openDispute);
router.get('/disputes/my', protect, authorize('user'), controller.getMyDisputes);
router.get('/disputes/worker-mine', protect, authorize('worker'), controller.getMyWorkerDisputes);
router.get('/disputes', protect, authorize('admin'), controller.getDisputes);
router.get('/disputes/party/:id', protect, authorize('user', 'worker', 'admin'), controller.getDisputeByIdForParty);
router.get('/disputes/:id', protect, authorize('admin'), controller.getDisputeById);
router.patch('/disputes/:id/review', protect, authorize('admin'), controller.markDisputeReviewing);
router.patch('/disputes/:id/resolve', protect, authorize(...ADMINS), permission(PERMS.PAYMENTS_DISPUTE), controller.resolveDispute);
router.patch('/disputes/:id/assign', protect, authorize('admin'), controller.assignDisputeAdmin);
router.post('/disputes/:id/notes', protect, authorize('admin'), controller.addDisputeInternalNote);
router.post('/disputes/:id/request-evidence', protect, authorize('admin'), controller.requestDisputeEvidence);
router.post('/disputes/:id/evidence', protect, authorize('user', 'worker', 'admin'), controller.addDisputeEvidence);
router.post('/disputes/:id/appeal', protect, authorize('user', 'worker'), controller.appealDispute);
router.patch('/disputes/:id/appeal', protect, authorize('admin'), controller.resolveDisputeAppeal);

module.exports = router;
