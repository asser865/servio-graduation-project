import { getToken } from '../api/client.js';

export async function uploadImage(file, kind) {
  const compressed = await compress(file);
  const fd = new FormData();
  fd.append('files', compressed, compressed.name);
  const base = window.SERVIO_CONFIG.API_BASE;
  const token = getToken();
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${base}/uploads/${kind}`, { method: 'POST', headers, body: fd });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data?.error?.message || `HTTP ${res.status}`);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data.data.files[0];
}

async function compress(file, maxSide = 1600, quality = 0.85) {
  const img = await loadImage(file);
  const ratio = Math.min(1, maxSide / Math.max(img.width, img.height));
  const w = Math.round(img.width * ratio);
  const h = Math.round(img.height * ratio);
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  canvas.getContext('2d').drawImage(img, 0, 0, w, h);
  const blob = await new Promise((res) => canvas.toBlob(res, 'image/jpeg', quality));
  return new File([blob], file.name.replace(/\.[^.]+$/, '.jpg'), { type: 'image/jpeg' });
}

function loadImage(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = URL.createObjectURL(file);
  });
}
