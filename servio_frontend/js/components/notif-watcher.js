import { getNotifications } from '../api/notifications.js';

const POLL_INTERVAL = 20_000;
const POPUP_DURATION = 4500;
const SESSION_KEY = 'servio_notif_seen_ids';

function getSession() {
  try {
    return JSON.parse(localStorage.getItem('servio_session') || 'null');
  } catch { return null; }
}

function getSeenIds() {
  try { return new Set(JSON.parse(sessionStorage.getItem(SESSION_KEY) || '[]')); }
  catch { return new Set(); }
}

function saveSeenIds(set) {
  sessionStorage.setItem(SESSION_KEY, JSON.stringify([...set]));
}

function normalizeNotifUrl(raw) {
  if (!raw) return null;
  try {
    const u = new URL(raw, window.location.href);
    return u.pathname + u.search + u.hash;
  } catch { return raw; }
}

function injectStyles() {
  if (document.getElementById('notif-watcher-styles')) return;
  const style = document.createElement('style');
  style.id = 'notif-watcher-styles';
  style.textContent = `
    .nw-popup {
      position: fixed;
      bottom: 1.5rem;
      right: 1.5rem;
      z-index: 9999;
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
      max-width: min(360px, calc(100vw - 2rem));
      pointer-events: none;
    }
    .nw-toast {
      background: var(--color-surface-container-high, #2a2a2e);
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 12px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.35);
      color: var(--color-on-surface, #e4e4e7);
      display: flex;
      align-items: flex-start;
      gap: 0.75rem;
      padding: 0.85rem 1rem;
      pointer-events: all;
      animation: nw-slide-in 0.3s ease;
    }
    .nw-toast__body { flex: 1; min-width: 0; }
    .nw-toast__title { font-weight: 600; font-size: 0.875rem; margin: 0 0 0.2rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .nw-toast__body-text { font-size: 0.8125rem; opacity: 0.8; margin: 0; line-height: 1.4; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
    .nw-toast__actions { display: flex; gap: 0.5rem; margin-top: 0.5rem; }
    .nw-toast__btn { background: rgba(255,255,255,0.08); border: none; border-radius: 6px; color: inherit; cursor: pointer; font: inherit; font-size: 0.75rem; padding: 0.25rem 0.6rem; }
    .nw-toast__btn:hover { background: rgba(255,255,255,0.14); }
    .nw-toast__close { background: none; border: none; color: inherit; cursor: pointer; flex-shrink: 0; font-size: 1rem; line-height: 1; opacity: 0.5; padding: 0; }
    .nw-toast__close:hover { opacity: 1; }
    [data-theme="light"] .nw-toast { background: #ffffff; border-color: rgba(0,0,0,0.08); box-shadow: 0 8px 32px rgba(0,0,0,0.12); color: #1a1a1a; }
    [data-theme="light"] .nw-toast__btn { background: rgba(0,0,0,0.06); }
    [data-theme="light"] .nw-toast__btn:hover { background: rgba(0,0,0,0.1); }
    @keyframes nw-slide-in { from { transform: translateY(1rem); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
    @media (max-width: 480px) { .nw-popup { bottom: 1rem; right: 1rem; left: 1rem; max-width: 100%; } }
  `;
  document.head.appendChild(style);
}

function showPopup(notif) {
  let container = document.querySelector('.nw-popup');
  if (!container) {
    container = document.createElement('div');
    container.className = 'nw-popup';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  toast.className = 'nw-toast';
  const viewUrl = normalizeNotifUrl(notif.referenceUrl);

  toast.innerHTML = `
    <div class="nw-toast__body">
      <p class="nw-toast__title">${notif.title}</p>
      <p class="nw-toast__body-text">${notif.body}</p>
      ${viewUrl ? `<div class="nw-toast__actions"><button class="nw-toast__btn" data-nw-view="${viewUrl}">View</button></div>` : ''}
    </div>
    <button class="nw-toast__close" aria-label="Dismiss">&#x2715;</button>`;

  container.appendChild(toast);

  function dismiss() {
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.2s';
    setTimeout(() => toast.remove(), 200);
  }

  const timer = setTimeout(dismiss, POPUP_DURATION);

  toast.querySelector('.nw-toast__close').addEventListener('click', () => {
    clearTimeout(timer);
    dismiss();
  });

  const viewBtn = toast.querySelector('[data-nw-view]');
  if (viewBtn) {
    viewBtn.addEventListener('click', () => {
      clearTimeout(timer);
      window.location.href = viewBtn.dataset.nwView;
    });
  }
}

let seeded = false;

async function poll() {
  try {
    const res = await getNotifications(50);
    const notifs = res.notifications || [];
    const seenIds = getSeenIds();

    if (!seeded) {
      notifs.forEach(n => seenIds.add(n._id));
      saveSeenIds(seenIds);
      seeded = true;
      return;
    }

    const newUnread = notifs.filter(n => !n.isRead && !seenIds.has(n._id));
    newUnread.forEach(n => {
      seenIds.add(n._id);
      showPopup(n);
    });
    if (newUnread.length) saveSeenIds(seenIds);
  } catch (_) {}
}

export function initNotifWatcher() {
  const session = getSession();
  if (!session) return;

  injectStyles();
  poll();
  setInterval(poll, POLL_INTERVAL);
}
