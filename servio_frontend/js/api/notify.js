import { api } from './client.js';

/**
 * Subscribe the authenticated user to availability notifications.
 * @param {string} serviceCategory - e.g. 'plumbing'
 * @param {string} [serviceArea]   - optional area label
 */
export const subscribeNotify = (serviceCategory, serviceArea = '') =>
  api.post('/notify', { serviceCategory, serviceArea });

/**
 * Cancel an active availability subscription.
 * @param {string} serviceCategory
 */
export const unsubscribeNotify = (serviceCategory) =>
  api.delete('/notify', { serviceCategory });
