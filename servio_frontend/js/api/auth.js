import { api, saveSession, clearSession, mapRoleFromBackend } from './client.js';

export async function login(email, password) {
  const res = await api.post('/auth/login', { email, password });
  const user = { ...res.user, role: mapRoleFromBackend(res.user.role) };
  saveSession(res.token, user);
  return user;
}

export async function register(data) {
  // data.role comes from frontend ('customer'/'technician') — no mapping needed at register,
  // the backend field is 'role' accepting 'user'/'worker' — map it
  const payload = { ...data };
  if (payload.role === 'customer')   payload.role = 'user';
  if (payload.role === 'technician') payload.role = 'worker';
  const res = await api.post('/auth/register', payload);
  if (!res || !res.token || !res.user) {
    throw new Error('Unexpected response from server. Please try again.');
  }
  const user = { ...res.user, role: mapRoleFromBackend(res.user.role) };
  saveSession(res.token, user);
  return user;
}

export async function forgotPassword(email) {
  return api.post('/auth/forgot-password', { email });
}

export async function resetPassword(token, password) {
  return api.post(`/auth/reset-password/${token}`, { password });
}

export async function logout() {
  clearSession();
}
