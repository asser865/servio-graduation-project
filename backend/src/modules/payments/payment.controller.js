const { StatusCodes } = require('http-status-codes');
const paymentService  = require('./payment.service');
const cashDebtService = require('./cash-debt.service');
const disputeService  = require('./dispute.service');
const ApiResponse     = require('../../utils/ApiResponse');
const ApiError        = require('../../utils/ApiError');
const { logEvent }    = require('../admin/audit.service');

const holdPayment = async (req, res) => {
  const { bookingId } = req.params;
  const { savedCardId } = req.body;
  const payment = await paymentService.holdPayment(bookingId, req.user.id, { savedCardId });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment held in escrow.', payment);
};

const confirmCompletion = async (req, res) => {
  const { bookingId } = req.params;
  const booking = await paymentService.requestReleaseByCustomer(bookingId, req.user.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Completion confirmed. Pending admin review.', booking);
};

const adminApproveCompletion = async (req, res) => {
  const { bookingId } = req.params;
  const result = await paymentService.adminApproveCompletion(bookingId, req.user.id);
  logEvent({ req, type: 'finance', action: 'Admin approved payment release', target: bookingId });
  return ApiResponse.success(res, StatusCodes.OK, 'Booking approved and payment processed.', result);
};

const adminRejectCash = async (req, res) => {
  const { bookingId } = req.params;
  const { reason } = req.body;
  if (!reason) throw new ApiError(StatusCodes.BAD_REQUEST, 'Rejection reason is required.');
  const result = await paymentService.adminRejectCash(bookingId, req.user.id, reason);
  logEvent({ req, type: 'finance', action: 'Admin rejected cash booking', target: bookingId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.OK, 'Cash booking rejected.', result);
};

const getPendingApprovals = async (req, res) => {
  const result = await paymentService.getPendingApprovals(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Pending approvals retrieved.', result);
};

const getCashDebts = async (req, res) => {
  const result = await cashDebtService.getAdminDebts(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Cash debts retrieved.', result);
};

const markCashDebtPaid = async (req, res) => {
  const { id } = req.params;
  const { amount, adminNote } = req.body;
  if (!amount) throw new ApiError(StatusCodes.BAD_REQUEST, 'amount is required.');
  const result = await cashDebtService.markCashDebtManuallyPaid(id, req.user.id, { amount: Number(amount), adminNote });
  logEvent({ req, type: 'finance', action: 'Admin marked cash debt paid', target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Cash debt payment recorded.', result);
};

const getMyDebts = async (req, res) => {
  const result = await cashDebtService.getWorkerDebts(req.user.id);
  return ApiResponse.success(res, StatusCodes.OK, 'Your cash debts retrieved.', result);
};

const getMyPayment = async (req, res) => {
  const { bookingId } = req.params;
  const payment = await paymentService.getPaymentByBooking(bookingId, req.user.id, req.user.role);
  return ApiResponse.success(res, StatusCodes.OK, 'Payment retrieved.', payment);
};

const getWorkerEarnings = async (req, res) => {
  const result = await paymentService.getWorkerEarnings(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Earnings retrieved.', result);
};

const adminRefund = async (req, res) => {
  const { paymentId } = req.params;
  const { reason } = req.body;
  if (!reason) throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund reason is required.');
  const payment = await paymentService.refundPayment(paymentId, req.user.id, reason);
  logEvent({ req, type: 'finance', action: 'Admin refund issued', target: paymentId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment refunded successfully.', payment);
};

const openDispute = async (req, res) => {
  const { bookingId, reason, evidence, category } = req.body;
  if (!bookingId || !reason) throw new ApiError(StatusCodes.BAD_REQUEST, 'bookingId and reason are required.');
  const dispute = await disputeService.openDispute(bookingId, req.user.id, reason, evidence, category);
  logEvent({ req, type: 'finance', action: 'Dispute opened', target: bookingId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.CREATED, 'Dispute opened successfully.', dispute);
};

const resolveDispute = async (req, res) => {
  const { id } = req.params;
  const { resolution, decision } = req.body;
  if (!resolution || !decision) throw new ApiError(StatusCodes.BAD_REQUEST, 'resolution and decision are required.');
  const dispute = await disputeService.resolveDispute(id, req.user.id, resolution, decision);
  logEvent({ req, type: 'finance', action: `Dispute resolved: ${decision}`, target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute resolved.', dispute);
};

const markDisputeReviewing = async (req, res) => {
  const { id } = req.params;
  const dispute = await disputeService.markDisputeReviewing(id);
  logEvent({ req, type: 'finance', action: 'Dispute marked reviewing', target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute marked as reviewing.', dispute);
};

const getDisputes = async (req, res) => {
  const result = await disputeService.getDisputesByAdmin(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Disputes retrieved.', result);
};

const getMyDisputes = async (req, res) => {
  const result = await disputeService.getDisputesForCustomer(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Your disputes retrieved.', result);
};

const updatePayoutSettings = async (req, res) => {
  const payload = req.body;

  if (!payload || typeof payload !== 'object' || Array.isArray(payload) || !Object.keys(payload).length) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'At least one payout setting is required.');
  }

  if (payload.payoutDetails && (typeof payload.payoutDetails !== 'object' || Array.isArray(payload.payoutDetails))) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'payoutDetails must be an object.');
  }

  const result = await paymentService.updateWorkerPayoutSettings(req.user.id, payload);
  return ApiResponse.success(res, StatusCodes.OK, 'Payout settings updated.', result);
};

module.exports = {
  holdPayment,
  confirmCompletion,
  adminApproveCompletion,
  adminRejectCash,
  getPendingApprovals,
  getCashDebts,
  markCashDebtPaid,
  getMyDebts,
  getMyPayment,
  getWorkerEarnings,
  adminRefund,
  openDispute,
  resolveDispute,
  markDisputeReviewing,
  getDisputes,
  getMyDisputes,
  updatePayoutSettings,
};
