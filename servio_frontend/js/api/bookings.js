import { api } from './client.js';

export const createBooking  = (data)        => api.post('/bookings', data);
export const getMyBookings  = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/bookings/my${qs ? '?' + qs : ''}`);
};
export const getWorkerBookings = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/bookings/worker${qs ? '?' + qs : ''}`);
};
export const getBooking     = (id)          => api.get(`/bookings/${id}`);
export const getAllBookings  = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/bookings${qs ? '?' + qs : ''}`);
};
export const cancelBooking        = (id, cancellationReason) =>
  api.patch(`/bookings/${id}/status`, { status: 'cancelled', ...(cancellationReason ? { cancellationReason } : {}) });
export const updateBookingStatus  = (id, status, details = {}) =>
  api.patch(`/bookings/${id}/status`, { status, ...details });
export const rescheduleBooking    = (id, data)     => api.patch(`/bookings/${id}/schedule`, data);
export const getWorkerBookedSlots = (workerId, date) =>
  api.get(`/bookings/worker/${workerId}/slots?date=${date}`);

// Plan 3 — cancel/no-show endpoints
export const postCancelBooking = (id, { reason } = {}) =>
  api.post(`/bookings/${id}/cancel`, { reason });
export const markCustomerNoShow = (id, { note, evidence = [] } = {}) =>
  api.post(`/bookings/${id}/no-show/customer`, { note, evidence });
export const markWorkerNoShow = (id, { note, evidence = [] } = {}) =>
  api.post(`/bookings/${id}/no-show/worker`, { note, evidence });

// Payments overhaul — worker submits completion outcome (paid / refused / could-not-complete)
export const submitCompletionOutcome = (bookingId, payload) =>
  api.post(`/bookings/${bookingId}/completion-outcome`, payload);

// Customer feedback — confirm or report issue after worker submits completion
export const submitCustomerFeedback = (bookingId, payload) =>
  api.post(`/bookings/${bookingId}/customer-feedback`, payload);

export const verifyRefusal = (bookingId, payload) =>
  api.post(`/bookings/${bookingId}/refusal-verification`, payload);

export const getRefusalsAwaitingResponse = () =>
  api.get('/bookings/admin/refusal-verifications');
