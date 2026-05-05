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
export const cancelBooking  = (id)          => api.patch(`/bookings/${id}/status`, { status: 'cancelled' });
export const getWorkerBookedSlots = (workerId, date) =>
  api.get(`/bookings/worker/${workerId}/slots?date=${date}`);
