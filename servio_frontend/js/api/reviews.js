import { api } from './client.js';

export const getMyReviews = () =>
  api.get('/reviews/my').then(r => r?.reviews || []);

export const createReview = (bookingId, rating, comment) =>
  api.post('/reviews', { bookingId, rating, comment: comment || undefined });

export const getWorkerReviews = (workerId) =>
  api.get(`/reviews/worker/${workerId}`).then(r => {
    if (Array.isArray(r)) return r;
    return r?.reviews || r?.data || [];
  });
