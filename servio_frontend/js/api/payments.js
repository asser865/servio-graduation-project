import { api } from './client.js';

export const holdPayment = (bookingId, body) =>
  api.post(`/payments/hold/${bookingId}`, body);

export const confirmCompletion = (bookingId) =>
  api.post(`/payments/confirm/${bookingId}`);

export const adminApprovePayment = (bookingId) =>
  api.post(`/payments/admin/approve/${bookingId}`);

export const adminRejectCash = (bookingId, body) =>
  api.post(`/payments/admin/reject-cash/${bookingId}`, body);

export const getPendingApprovals = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/admin/pending-approvals${qs ? '?' + qs : ''}`);
};

export const getCashDebts = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/admin/cash-debts${qs ? '?' + qs : ''}`);
};

export const markCashDebtPaid = (debtId, body) =>
  api.patch(`/payments/admin/cash-debts/${debtId}/mark-paid`, body);

export const getMyDebts = () =>
  api.get('/payments/my-debts');

export const getPaymentByBooking = (bookingId) =>
  api.get(`/payments/booking/${bookingId}`);

export const getWorkerEarnings = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/earnings${qs ? '?' + qs : ''}`);
};

export const adminRefund = (paymentId, body) =>
  api.post(`/payments/refund/${paymentId}`, body);

export const openDispute = (body) =>
  api.post('/payments/disputes', body);

export const resolveDispute = (id, body) =>
  api.patch(`/payments/disputes/${id}/resolve`, body);

export const getDisputes = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/disputes${qs ? '?' + qs : ''}`);
};
