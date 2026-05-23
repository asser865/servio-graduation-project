import { api } from './client.js';

export const getNotifications  = (limit = 50, skip = 0)  => api.get(`/notifications?limit=${limit}&skip=${skip}`);
export const getUnreadCount    = ()                       => api.get('/notifications/unread-count');
export const markOneRead       = (id)                     => api.patch(`/notifications/${id}/read`);
export const markAllRead       = ()                       => api.patch('/notifications/read-all');
export const clearAll          = ()                       => api.delete('/notifications');
export const deleteOne         = (id)                     => api.delete(`/notifications/${id}`);

export const getNotificationPreferences = ()              => api.get('/notifications/preferences');
export const updateNotificationPreferences = (channels)   => api.put('/notifications/preferences', { channels });
