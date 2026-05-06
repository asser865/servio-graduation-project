// Central API client — all fetch calls go through here

const base = () => window.SERVIO_CONFIG.API_BASE;

function getToken() {
  return localStorage.getItem('servio_token');
}

function getSession() {
  const raw = localStorage.getItem('servio_session');
  return raw ? JSON.parse(raw) : null;
}

function saveSession(token, user) {
  localStorage.setItem('servio_token', token);
  localStorage.setItem('servio_session', JSON.stringify(user));
}

function clearSession() {
  localStorage.removeItem('servio_token');
  localStorage.removeItem('servio_session');
}

// Backend sends 'user'/'worker'/'admin'; frontend uses 'customer'/'technician'/'admin'
function mapRoleFromBackend(backendRole) {
  if (backendRole === 'user')   return 'customer';
  if (backendRole === 'worker') return 'technician';
  return backendRole; // 'admin' stays
}

function mapRoleToBackend(frontendRole) {
  if (frontendRole === 'customer')   return 'user';
  if (frontendRole === 'technician') return 'worker';
  return frontendRole;
}

async function request(method, path, body, opts = {}) {
  const headers = { 'Content-Type': 'application/json' };
  const token = getToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const fetchOpts = { method, headers };
  if (body !== undefined) fetchOpts.body = JSON.stringify(body);

  const res = await fetch(`${base()}${path}`, fetchOpts);
  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    const err = new Error(data.message || `HTTP ${res.status}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  
  if (data && typeof data === 'object' && data.success !== undefined && data.data !== undefined) {
    return data.data;
  }
  
  return data;
}

const api = {
  get:    (path)        => request('GET',    path),
  post:   (path, body)  => request('POST',   path, body),
  put:    (path, body)  => request('PUT',    path, body),
  patch:  (path, body)  => request('PATCH',  path, body),
  delete: (path, body)  => request('DELETE', path, body),
};

export { api, getToken, getSession, saveSession, clearSession, mapRoleFromBackend, mapRoleToBackend };
