import { api } from './client.js';

export const getMe          = ()            => api.get('/users/me');
export const updateMe       = (data)        => api.patch('/users/me', data);
export const updatePassword = (data)        => api.patch('/users/me/password', data);
export const deleteMe           = ()                   => api.delete('/users/me');
export const updateAvailability = (availability)       => api.patch('/users/me/availability', { availability });
export const getWorkers     = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/users/workers${qs ? '?' + qs : ''}`);
};
export const getWorker      = (id)          => api.get(`/users/workers/${id}`);
export const getAllUsers     = (params = {}) => {
  const qs = new URLSearchParams(params).toString();
  return api.get(`/users${qs ? '?' + qs : ''}`);
};
export const updateUser     = (id, data)    => api.patch(`/users/${id}`, data);
export const deleteUser     = (id)          => api.delete(`/users/${id}`);

// Admin specific
export const updateUserStatus = (id, isActive) => api.patch(`/users/${id}/status`, { isActive });
export const verifyWorker     = (id, isVerified) => api.patch(`/users/workers/${id}/verify`, { isVerified });
export const reviewWorker     = (id, data)       => api.patch(`/users/workers/${id}/verify`, data);
