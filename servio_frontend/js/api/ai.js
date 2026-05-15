import { api } from './client.js';

export const smartMatch = ({ prompt, location }) =>
  api.post('/ai/recommend', { prompt, ...(location ? { location } : {}) });

export const recommendService = ({ prompt, description }) =>
  smartMatch({ prompt: prompt || description });
