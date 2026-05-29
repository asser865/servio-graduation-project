import { api } from './client.js';

export const holdPayment = (bookingId, body) =>
  api.post(`/payments/hold/${bookingId}`, body);

export const confirmCompletion = (bookingId) =>
  api.post(`/payments/confirm/${bookingId}`);

export const adminApprovePayment = (bookingId, body = {}) =>
  api.post(`/payments/admin/approve/${bookingId}`, { reasonCode: 'customer_confirmed', ...body });

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

export const confirmBooking = (bookingId, body) =>
  api.post(`/payments/confirm/${bookingId}`, body);

export const adminPartialRefund = (bookingId, body) =>
  api.post(`/payments/admin/partial-refund/${bookingId}`, body);

export const adminListPayments = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/admin/payments${qs ? '?' + qs : ''}`);
};

export const adminPaymentDetail = (paymentId) =>
  api.get(`/payments/admin/payments/${paymentId}/detail`);

export const adminPaymentsStats = () =>
  api.get('/payments/admin/payments/stats');

export const getMyCredits = () =>
  api.get('/payments/me/credits');

// Plan 3 — customer history, invoices, receipts, admin credits
export const getCustomerHistory = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/me/history${qs ? '?' + qs : ''}`);
};
export const getMyInvoices = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/me/invoices${qs ? '?' + qs : ''}`);
};
export const downloadReceiptUrl = (paymentId) =>
  `/api/v1/payments/${paymentId}/receipt`;
export const adminIssueCredit = (body) =>
  api.post('/payments/admin/credits/issue', body);

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

export const reviewDispute = (id) =>
  api.patch(`/payments/disputes/${id}/review`, {});

export const getDisputeById = (id) =>
  api.get(`/payments/disputes/${id}`);

export const assignDispute = (id, body = {}) =>
  api.patch(`/payments/disputes/${id}/assign`, body);

export const addDisputeNote = (id, note) =>
  api.post(`/payments/disputes/${id}/notes`, { note });

export const requestDisputeEvidence = (id, target, message) =>
  api.post(`/payments/disputes/${id}/request-evidence`, { target, message });

export const addDisputeEvidence = (id, files) =>
  api.post(`/payments/disputes/${id}/evidence`, { files });

export const appealDispute = (id, appealReason) =>
  api.post(`/payments/disputes/${id}/appeal`, { appealReason });

export const resolveDisputeAppeal = (id, outcome, note) =>
  api.patch(`/payments/disputes/${id}/appeal`, { outcome, note });

export const getDisputes = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/disputes${qs ? '?' + qs : ''}`);
};

export const getMyDisputes = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/disputes/my${qs ? '?' + qs : ''}`);
};

export const getWorkerDisputes = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/disputes/worker-mine${qs ? '?' + qs : ''}`);
};

export const getPartyDisputeById = (id) =>
  api.get(`/payments/disputes/party/${id}`);

// ─── Plan 2: debts + settlements + payouts ──────────────────────────────
export const getMyDebtsV2      = (opts = {}) => api.get('/payments/my-debts/v2', opts);
export const settleMyDebt      = (body) => api.post('/payments/my-debts/settle', body);
export const getMySettlements  = () => api.get('/payments/my-settlements');
export const requestPayout     = (body) => api.post('/payments/payout-request', body);
export const getMyPayouts      = (opts = {}) => api.get('/payments/my-payouts', opts);

export const adminListSettlements = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/admin/settlements${qs ? '?' + qs : ''}`);
};
export const adminVerifySettlement = (id) => api.patch(`/payments/admin/settlements/${id}/verify`);
export const adminRejectSettlement = (id, body) => api.patch(`/payments/admin/settlements/${id}/reject`, body);
export const adminListCashDebtsGrouped = () => api.get('/payments/admin/cash-debts/grouped');
export const adminWorkerDebts = (workerId) => api.get(`/payments/admin/cash-debts/by-worker/${workerId}`);

export const adminListPayouts = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/payments/admin/payout-requests${qs ? '?' + qs : ''}`);
};
export const adminApprovePayout    = (id, body = {}) => api.patch(`/payments/admin/payout-requests/${id}/approve`, body);
export const adminMarkPayoutPaid   = (id, body)      => api.patch(`/payments/admin/payout-requests/${id}/mark-paid`, body);
export const adminRejectPayout     = (id, body)      => api.patch(`/payments/admin/payout-requests/${id}/reject`, body);

export const adminForceRelease = (paymentId, body) => api.post(`/payments/admin/${paymentId}/force-release`, body);
export const adminForceLock    = (paymentId, body) => api.post(`/payments/admin/${paymentId}/force-lock`, body);
export const adminForceUnlock  = (paymentId, body) => api.post(`/payments/admin/${paymentId}/force-unlock`, body);

export const getMyTransactions = (params = {}) => {
  const qs = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
  return api.get(`/payments/my-transactions${qs ? '?' + qs : ''}`);
};
