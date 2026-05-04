import { api } from './client.js';

export const getServices    = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/services${qs ? '?' + qs : ''}`);
};
export const getService     = (id)          => api.get(`/services/${id}`);
export const createService  = (data)        => api.post('/services', data);
export const updateService  = (id, data)    => api.put(`/services/${id}`, data);
export const deleteService  = (id)          => api.delete(`/services/${id}`);
