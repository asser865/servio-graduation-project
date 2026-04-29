import { api } from './client.js';

export const sendMessage      = (bookingId, content)  => api.post('/messages/', { bookingId, content });
export const getMessages      = (bookingId)            => api.get(`/messages/${bookingId}`);
export const getUnreadCount   = ()                     => api.get('/messages/unread');
export const getConversations = ()                     => api.get('/messages/conversations');
