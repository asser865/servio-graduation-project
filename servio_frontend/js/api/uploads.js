export async function uploadPublicFile(file, kind) {
  if (!(file instanceof File)) {
    throw new Error('A valid file is required.');
  }

  const params = new URLSearchParams({
    kind,
    filename: file.name,
  });

  // Include auth token when available (post-login uploads); omit for pre-auth signup uploads
  const token = localStorage.getItem('servio_token');
  const headers = { 'Content-Type': file.type || 'application/octet-stream' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${window.SERVIO_CONFIG.API_BASE}/uploads?${params.toString()}`, {
    method: 'POST',
    headers,
    body: file,
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.message || 'File upload failed.');
  }

  return data?.data || data;
}
