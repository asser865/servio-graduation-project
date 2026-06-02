/* ═══════════════════════════════════════════════════════════
   notif-bell.js — Customer-facing notification bell
   Injected into .header__right for logged-in users.
   ═══════════════════════════════════════════════════════════ */
import { getNotifications, getUnreadCount, markOneRead, markAllRead, clearAll } from '../api/notifications.js';

function getSession() {
  try {
    return JSON.parse(sessionStorage.getItem('servio_session') || localStorage.getItem('servio_session') || 'null');
  } catch { return null; }
}

function timeAgo(dateStr) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1)  return 'Just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 7)  return `${d}d ago`;
  return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

const TYPE_ICON = {
  booking_created:    { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="3" y1="10" x2="21" y2="10"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="16" y1="2" x2="16" y2="6"/></svg>', color: 'notif-icon--job' },
  booking_accepted:   { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>', color: 'notif-icon--success' },
  booking_rejected:   { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>', color: 'notif-icon--warn' },
  booking_en_route:   { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>', color: 'notif-icon--job' },
  booking_arrived:    { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>', color: 'notif-icon--job' },
  booking_in_progress:{ svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>', color: 'notif-icon--job' },
  booking_completed:  { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>', color: 'notif-icon--success' },
  booking_cancelled:  { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>', color: 'notif-icon--warn' },
  tech_available:     { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>', color: 'notif-icon--job' },
  review_received:    { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" stroke="none"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>', color: 'notif-icon--star' },
  system:             { svg: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>', color: 'notif-icon--system' },
};

  function normalizeNotifUrl(raw) {
    if (!raw) return null;
    try {
      const u = new URL(raw, window.location.href);
      return u.pathname + u.search + u.hash;
    } catch {
      return raw;
    }
  }

  function navigateToNotif(viewUrl) {
    if (!viewUrl) return;
    try {
      const target = new URL(viewUrl, window.location.href);
      if (target.pathname === window.location.pathname && target.hash) {
        if (window.location.hash === target.hash) {
          window.dispatchEvent(new HashChangeEvent('hashchange'));
        } else {
          window.location.hash = target.hash;
        }
        return;
      }
    } catch (_) {}
    window.location.href = viewUrl;
  }

function renderItem(n) {
  const icon = TYPE_ICON[n.type] || TYPE_ICON.system;
  const unread = !n.isRead ? ' notif-item--unread' : '';
  const safeUrl = normalizeNotifUrl(n.referenceUrl);
  const clickable = safeUrl ? ` data-url="${safeUrl}"` : '';
  return `
    <div class="notif-item${unread}" data-id="${n._id}"${clickable} role="button" tabindex="0">
      <span class="notif-icon ${icon.color}">${icon.svg}</span>
      <div class="notif-item__body">
        <p class="notif-item__title">${n.title}</p>
        <p class="notif-item__body-text">${n.body}</p>
        <span class="notif-item__time">${timeAgo(n.createdAt)}</span>
      </div>
      ${!n.isRead ? '<span class="notif-item__dot" aria-hidden="true"></span>' : ''}
    </div>`;
}

function groupByDate(notifications) {
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1);
  const groups = { Today: [], Yesterday: [], Earlier: [] };
  notifications.forEach(n => {
    const d = new Date(n.createdAt); d.setHours(0, 0, 0, 0);
    if (d >= today)              groups.Today.push(n);
    else if (d >= yesterday)     groups.Yesterday.push(n);
    else                         groups.Earlier.push(n);
  });
  return groups;
}

export function initNotifBell() {
  const session = getSession();
  if (!session) return;

  // Only show for customers (workers have their own bell in the dashboard)
  if (session.role === 'technician' || session.role === 'admin') return;

  const headerRight = document.querySelector('.header__right');
  if (!headerRight) return;

  // Build bell wrapper
  const wrapper = document.createElement('div');
  wrapper.className = 'notif-bell';
  wrapper.id = 'headerNotifBell';
  wrapper.innerHTML = `
    <button class="notif-bell__btn" type="button" aria-label="Notifications" aria-haspopup="true" aria-expanded="false" id="notifBellBtn">
      <svg class="notif-bell__icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
        <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
      </svg>
      <span class="notif-bell__badge" id="notifBadge" hidden aria-live="polite">0</span>
    </button>

    <div class="notif-panel" id="notifPanel" role="dialog" aria-label="Notifications">
      <div class="notif-panel__header">
        <span class="notif-panel__title">Notifications</span>
        <div class="notif-panel__actions">
          <button class="notif-panel__action-btn" type="button" id="notifMarkAll">Mark all read</button>
          <button class="notif-panel__action-btn notif-panel__action-btn--danger" type="button" id="notifClearAll">Clear all</button>
        </div>
      </div>
      <div class="notif-panel__body" id="notifPanelBody">
        <div class="notif-empty" id="notifEmpty">
          <svg viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          </svg>
          <p>No notifications yet</p>
        </div>
      </div>
    </div>`;

  // Insert before theme button
  const themeBtn = headerRight.querySelector('.btn--header-theme');
  if (themeBtn) headerRight.insertBefore(wrapper, themeBtn);
  else headerRight.prepend(wrapper);

  const btn    = wrapper.querySelector('#notifBellBtn');
  const panel  = wrapper.querySelector('#notifPanel');
  const badge  = wrapper.querySelector('#notifBadge');
  const body   = wrapper.querySelector('#notifPanelBody');
  const empty  = wrapper.querySelector('#notifEmpty');

  let notifications = [];
  let loading = false;

  async function fetchAndRender() {
    if (loading) return;
    loading = true;
    try {
      const res = await getNotifications(50);
      notifications = res.notifications || [];
      const unread  = res.unreadCount ?? notifications.filter(n => !n.isRead).length;
      updateBadge(unread);
      renderList();
    } catch (_) {}
    loading = false;
  }

  function updateBadge(count) {
    if (count > 0) {
      badge.textContent = count > 99 ? '99+' : String(count);
      badge.hidden = false;
    } else {
      badge.hidden = true;
    }
  }

  function renderList() {
    if (!notifications.length) {
      empty.hidden = false;
      // Remove any previously rendered groups
      body.querySelectorAll('.notif-group').forEach(g => g.remove());
      return;
    }
    empty.hidden = true;
    body.querySelectorAll('.notif-group').forEach(g => g.remove());

    const groups = groupByDate(notifications);
    const frag = document.createDocumentFragment();

    Object.entries(groups).forEach(([label, items]) => {
      if (!items.length) return;
      const section = document.createElement('div');
      section.className = 'notif-group';
      section.innerHTML = `<p class="notif-group__label">${label}</p>` + items.map(renderItem).join('');
      frag.appendChild(section);
    });

    body.appendChild(frag);
    attachItemListeners();
  }

  function attachItemListeners() {
    body.querySelectorAll('.notif-item').forEach(item => {
      item.addEventListener('click', () => handleItemClick(item));
      item.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') handleItemClick(item); });
    });
  }

  async function handleItemClick(item) {
    const id  = item.dataset.id;
    const url = item.dataset.url;

    if (item.classList.contains('notif-item--unread')) {
      item.classList.remove('notif-item--unread');
      item.querySelector('.notif-item__dot')?.remove();
      try { await markOneRead(id); } catch (_) {}
      const n = notifications.find(x => x._id === id);
      if (n) n.isRead = true;
      const unread = notifications.filter(x => !x.isRead).length;
      updateBadge(unread);
    }

    if (url) {
      closePanel();
      navigateToNotif(normalizeNotifUrl(url) || url);
    }
  }

  function isPanelOpen() { return panel.classList.contains('is-open'); }
  function openPanel()  { panel.classList.add('is-open');    btn.setAttribute('aria-expanded', 'true'); }
  function closePanel() { panel.classList.remove('is-open'); btn.setAttribute('aria-expanded', 'false'); }

  // Toggle panel
  btn.addEventListener('click', async e => {
    e.stopPropagation();
    if (isPanelOpen()) {
      closePanel();
    } else {
      openPanel();
      await fetchAndRender();
    }
  });

  // Mark all read
  document.getElementById('notifMarkAll')?.addEventListener('click', async () => {
    try {
      await markAllRead();
      notifications.forEach(n => n.isRead = true);
      updateBadge(0);
      body.querySelectorAll('.notif-item--unread').forEach(el => {
        el.classList.remove('notif-item--unread');
        el.querySelector('.notif-item__dot')?.remove();
      });
    } catch (_) {}
  });

  // Clear all
  document.getElementById('notifClearAll')?.addEventListener('click', async () => {
    try {
      await clearAll();
      notifications = [];
      updateBadge(0);
      body.querySelectorAll('.notif-group').forEach(g => g.remove());
      empty.hidden = false;
    } catch (_) {}
  });

  // Close on outside click / Escape
  document.addEventListener('click', e => {
    if (!wrapper.contains(e.target)) closePanel();
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && isPanelOpen()) {
      closePanel();
      btn.focus();
    }
  });

  // Poll unread count every 60s
  async function pollBadge() {
    try {
      const res = await getUnreadCount();
      updateBadge(res.unreadCount ?? 0);
    } catch (_) {}
  }
  pollBadge();
  setInterval(pollBadge, 20_000);
}
