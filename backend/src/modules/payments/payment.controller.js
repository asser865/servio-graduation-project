const { StatusCodes } = require('http-status-codes');
const paymentService = require('./payment.service');
const disputeService = require('./dispute.service');
const ApiResponse = require('../../utils/ApiResponse');
const ApiError = require('../../utils/ApiError');
const { logEvent } = require('../admin/audit.service');

const confirmCompletion = async (req, res) => {
  const { bookingId } = req.params;
  const payment = await paymentService.releasePaymentToWorker(bookingId, req.user.id);

  return ApiResponse.success(
    res,
    StatusCodes.OK,
    'Service confirmed. Payment released to worker.',
    payment
  );
};

const getMyPayment = async (req, res) => {
  const { bookingId } = req.params;
  const payment = await paymentService.getPaymentByBooking(
    bookingId,
    req.user.id,
    req.user.role
  );

  return ApiResponse.success(res, StatusCodes.OK, 'Payment retrieved.', payment);
};

const getWorkerEarnings = async (req, res) => {
  const result = await paymentService.getWorkerEarnings(req.user.id, req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Earnings retrieved.', result);
};

const adminRefund = async (req, res) => {
  const { paymentId } = req.params;
  const { reason } = req.body;

  if (!reason) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Refund reason is required.');
  }

  const payment = await paymentService.refundPayment(paymentId, req.user.id, reason);
  logEvent({ req, type: 'finance', action: 'Admin refund issued', target: paymentId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.OK, 'Payment refunded successfully.', payment);
};

const openDispute = async (req, res) => {
  const { bookingId, reason, evidence } = req.body;
  if (!bookingId || !reason) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'bookingId and reason are required.');
  }

  const dispute = await disputeService.openDispute(
    bookingId,
    req.user.id,
    reason,
    evidence
  );
  logEvent({ req, type: 'finance', action: 'Dispute opened', target: bookingId, status: 'warn' });
  return ApiResponse.success(res, StatusCodes.CREATED, 'Dispute opened successfully.', dispute);
};

const resolveDispute = async (req, res) => {
  const { id } = req.params;
  const { resolution, decision } = req.body;

  if (!resolution || !decision) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'resolution and decision are required.');
  }

  const dispute = await disputeService.resolveDispute(
    id,
    req.user.id,
    resolution,
    decision
  );
  logEvent({ req, type: 'finance', action: `Dispute resolved: ${decision}`, target: id });
  return ApiResponse.success(res, StatusCodes.OK, 'Dispute resolved.', dispute);
};

const getDisputes = async (req, res) => {
  const result = await disputeService.getDisputesByAdmin(req.query);
  return ApiResponse.success(res, StatusCodes.OK, 'Disputes retrieved.', result);
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
  confirmCompletion,
  getMyPayment,
  getWorkerEarnings,
  adminRefund,
  openDispute,
  resolveDispute,
  getDisputes,
  updatePayoutSettings,
};
