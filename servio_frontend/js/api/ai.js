import { api } from './client.js';

export const recommendService = ({ description, location, budget }) =>
  api.post('/ai/recommend', { description, location, budget });
