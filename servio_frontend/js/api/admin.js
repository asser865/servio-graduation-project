import { api } from './client.js';

export function getAuditLogs(params = {}) {
  const qs = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => { if (v !== '' && v != null) qs.set(k, v); });
  const query = qs.toString();
  return api.get(`/admin/audit${query ? '?' + query : ''}`);
}

export function deleteAuditLog(id) {
  return api.delete(`/admin/audit/${id}`);
}

export const getAdminSettings = () => api.get('/admin/settings');
export const updateAdminSettings = (data) => api.put('/admin/settings', data);
export const getAnalytics = () => api.get('/users/analytics');
