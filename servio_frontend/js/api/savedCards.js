import { api } from './client.js';

export const getSavedCards   = ()     => api.get('/saved-cards');
export const addSavedCard    = (data) => api.post('/saved-cards', data);
export const deleteSavedCard = (id)   => api.delete(`/saved-cards/${id}`);
export const setDefaultCard  = (id)   => api.patch(`/saved-cards/${id}/default`);
