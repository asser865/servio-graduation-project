import { api } from './client.js';

export async function listMyFavoriteIds() {
  const data = await api.get('/favorites/ids');
  return new Set(data.ids);
}

export async function addFavorite(workerId) {
  return api.post(`/favorites/${workerId}`);
}

export async function removeFavorite(workerId) {
  return api.delete(`/favorites/${workerId}`);
}

export async function listFavorites(params = {}) {
  const qs = new URLSearchParams(
    Object.entries(params).filter(([, v]) => v !== undefined && v !== '' && v !== false)
  ).toString();
  return api.get(`/favorites${qs ? '?' + qs : ''}`);
}

export async function getMyWorkerFavoriteCount() {
  const data = await api.get('/favorites/me/count');
  return data.count;
}
