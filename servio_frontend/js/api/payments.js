import { api } from './client.js';

export const createPaymentIntent = (bookingId)  => api.post('/payments/intent', { bookingId });
export const confirmPayment      = (bookingId)  => api.post(`/payments/${bookingId}/confirm`);
export const releasePayment      = (bookingId)  => api.post(`/payments/${bookingId}/release`);
export const refundPayment       = (bookingId)  => api.post(`/payments/${bookingId}/refund`);
export const getWallet           = ()           => api.get('/payments/wallet');
export const getTransactions     = ()           => api.get('/payments/transactions');
