import { api } from './client.js';

export const getPlatformSettings = () => api.get('/platform-settings');
