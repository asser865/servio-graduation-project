/* ═══════════════════════════════════════════════════════════
   customer-dashboard.js
   ═══════════════════════════════════════════════════════════ */
import { showToast } from '../components/toast.js';
import { revealAll } from '../components/scroll-reveal.js';
import { getInitials } from '../utils/string.js';
import { getMe, updateMe, updateEmail, deleteMe, updatePassword, addAddress, updateAddress, deleteAddress } from '../api/users.js';
import { clearSession } from '../api/client.js';
import { uploadPublicFile } from '../api/uploads.js';
import { getMyBookings, cancelBooking } from '../api/bookings.js';
import { getMyReviews, createReview } from '../api/reviews.js';
import { getSavedCards, addSavedCard, deleteSavedCard, setDefaultCard } from '../api/savedCards.js';

const STAR_SVG = (fill = '#F59E0B', size = 14) =>
  `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="${fill}" stroke="${fill}" stroke-width="0"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;

const EMPTY_STAR_SVG = (size = 14) =>
  `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="#d1d5db" stroke-width="1.5"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`;

const TAB_KEY = 'servio_activeTab_customer';
let _bookingSnapshotBuilt = false;
let _historyLoaded = false;

// Holds the uploaded avatar URL between file-select and form-save
let _pendingPhotoUrl = null;

function getSession() {
  try {
    return JSON.parse(sessionStorage.getItem('servio_session') || localStorage.getItem('servio_session') || 'null');
  } catch { return null; }
}

// ── Auth Guard ──────────────────────────────────────────
const session = getSession();
const isPreview = localStorage.getItem('servio_preview_mode') === 'true';

if (!session) {
  window.location.href = './login.html';
} else if (session.role === 'admin' && !isPreview) {
  window.location.href = './admin-dashboard.html';
} else if (session.role === 'technician') {
  window.location.href = './technician-dashboard.html';
}

function getAccount() {
  try {
    return JSON.parse(localStorage.getItem('servio_account') || 'null');
  } catch { return null; }
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function getErrorMessage(err, fallback) {
  return err?.data?.errors?.[0]?.message
    || err?.data?.message
    || err?.message
    || fallback;
}

/* ── Payment Methods ────────────────────────────────────── */
const PM_CARD_ICONS = {
  visa:       '<svg viewBox="0 0 48 16" width="34" height="12" fill="none" aria-hidden="true"><text x="0" y="12" font-size="12" font-weight="800" fill="#1a1f71" font-family="Arial">VISA</text></svg>',
  mastercard: '<svg viewBox="0 0 32 20" width="28" height="18" aria-hidden="true"><circle cx="12" cy="10" r="10" fill="#eb001b"/><circle cx="20" cy="10" r="10" fill="#f79e1b" fill-opacity="0.85"/></svg>',
  amex:       '<svg viewBox="0 0 48 16" width="34" height="12" fill="none" aria-hidden="true"><text x="0" y="12" font-size="10" font-weight="700" fill="#2e77bc" font-family="Arial">AMEX</text></svg>',
  other:      '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>',
};

function detectPmCardType(num) {
  const first = num.replace(/\D/g, '')[0];
  if (first === '4') return 'visa';
  if (first === '5') return 'mastercard';
  if (first === '3') return 'amex';
  return 'other';
}

function initPaymentMethods() {
  const list        = document.getElementById('pm-card-list');
  const empty       = document.getElementById('pm-empty');
  const addBtn      = document.getElementById('pm-add-btn');
  const formWrap    = document.getElementById('pm-add-form-wrap');
  const cancelBtn   = document.getElementById('pm-cancel-add-btn');
  const saveBtn     = document.getElementById('pm-save-card-btn');
  const formError   = document.getElementById('pm-form-error');

  if (!list) return;

  let _cardOpInFlight = false;

  function renderCards(cards) {
    list.innerHTML = '';
    const atLimit = cards.length >= 3;

    if (addBtn) {
      addBtn.disabled = atLimit;
      addBtn.title    = atLimit ? 'Maximum 3 cards reached' : '';
    }

    if (cards.length === 0) {
      if (empty) empty.style.display = 'block';
      return;
    }
    if (empty) empty.style.display = 'none';

    cards.forEach(card => {
      const icon = PM_CARD_ICONS[card.cardType] || PM_CARD_ICONS.other;
      const tile = document.createElement('div');
      tile.style.cssText = `
        display:flex;align-items:center;gap:14px;padding:14px 16px;
        background:#111;border:1px solid #2a2a2a;border-radius:12px;
      `;
      tile.innerHTML = `
        <span style="flex-shrink:0">${icon}</span>
        <div style="flex:1;min-width:0">
          <div style="font-weight:600;font-size:14px">•••• •••• •••• ${card.last4}</div>
          <div style="font-size:12px;color:#aaa;margin-top:3px">
            ${card.label ? card.label + ' · ' : ''}Exp ${card.expiry}
          </div>
        </div>
        ${card.isDefault
          ? '<span style="font-size:11px;background:rgba(245,166,35,.15);color:#f5a623;border:1px solid rgba(245,166,35,.3);border-radius:4px;padding:2px 8px;flex-shrink:0">Default</span>'
          : `<button class="btn btn--sm btn--outline pm-set-default" data-id="${card._id}" style="font-size:12px;padding:4px 10px;flex-shrink:0">Set Default</button>`
        }
        <button class="btn btn--sm btn--ghost pm-delete" data-id="${card._id}" aria-label="Delete card" style="flex-shrink:0;color:#e74c3c;padding:6px;">
          <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/></svg>
        </button>
      `;
      list.appendChild(tile);
    });

    list.querySelectorAll('.pm-set-default').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (_cardOpInFlight) return;
        _cardOpInFlight = true;
        btn.disabled = true;
        try {
          await setDefaultCard(btn.dataset.id);
          const res = await getSavedCards();
          renderCards(res.data || res || []);
          showToast('Default card updated.', 'success');
        } catch {
          showToast('Failed to update default card.', 'error');
          btn.disabled = false;
        } finally {
          _cardOpInFlight = false;
        }
      });
    });

    list.querySelectorAll('.pm-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (_cardOpInFlight) return;
        if (!confirm('Remove this card from your saved cards?')) return;
        _cardOpInFlight = true;
        btn.disabled = true;
        try {
          await deleteSavedCard(btn.dataset.id);
          const res = await getSavedCards();
          renderCards(res.data || res || []);
          showToast('Card removed.', 'success');
        } catch {
          showToast('Failed to remove card.', 'error');
          btn.disabled = false;
        } finally {
          _cardOpInFlight = false;
        }
      });
    });
  }

  function showAddForm() {
    if (formWrap) formWrap.style.display = 'block';
    if (formError) { formError.style.display = 'none'; formError.textContent = ''; }
    ['pm-card-holder', 'pm-card-number', 'pm-expiry', 'pm-cvv', 'pm-label'].forEach(id => {
      const el = document.getElementById(id);
      if (el) el.value = '';
    });
    document.getElementById('pm-card-holder')?.focus();
  }

  function hideAddForm() {
    if (formWrap) formWrap.style.display = 'none';
  }

  addBtn?.addEventListener('click', () => { if (!addBtn.disabled) showAddForm(); });
  cancelBtn?.addEventListener('click', hideAddForm);

  document.getElementById('pm-card-number')?.addEventListener('input', (e) => {
    const raw = e.target.value.replace(/\D/g, '').slice(0, 16);
    e.target.value = raw.replace(/(.{4})/g, '$1 ').trim();
  });

  document.getElementById('pm-expiry')?.addEventListener('input', (e) => {
    const raw = e.target.value.replace(/\D/g, '').slice(0, 4);
    e.target.value = raw.length > 2 ? raw.slice(0, 2) + ' / ' + raw.slice(2) : raw;
  });

  saveBtn?.addEventListener('click', async () => {
    const name   = document.getElementById('pm-card-holder')?.value.trim() || '';
    const rawNum = (document.getElementById('pm-card-number')?.value || '').replace(/\s/g, '');
    const exp    = document.getElementById('pm-expiry')?.value.trim() || '';
    const cvv    = document.getElementById('pm-cvv')?.value.trim() || '';
    const label  = document.getElementById('pm-label')?.value.trim() || '';

    if (!name) { if (formError) { formError.textContent = 'Cardholder name is required.'; formError.style.display = 'block'; } return; }
    if (rawNum.length !== 16 || !/^\d+$/.test(rawNum)) { if (formError) { formError.textContent = 'Please enter a valid 16-digit card number.'; formError.style.display = 'block'; } return; }
    if (!/^\d{2}\s*\/\s*\d{2}$/.test(exp)) { if (formError) { formError.textContent = 'Please enter a valid expiry (MM / YY).'; formError.style.display = 'block'; } return; }
    if (cvv.length < 3 || !/^\d+$/.test(cvv)) { if (formError) { formError.textContent = 'Please enter a valid CVV.'; formError.style.display = 'block'; } return; }

    if (formError) formError.style.display = 'none';
    saveBtn.disabled = true;
    saveBtn.textContent = 'Saving…';

    try {
      await addSavedCard({
        last4:    rawNum.slice(-4),
        cardType: detectPmCardType(rawNum),
        expiry:   exp.replace(/\s/g, ''),
        label,
      });
      const res = await getSavedCards();
      renderCards(res.data || res || []);
      hideAddForm();
      showToast('Card saved successfully.', 'success');
    } catch (err) {
      const msg = err?.data?.message || err?.message || 'Failed to save card.';
      if (formError) { formError.textContent = msg; formError.style.display = 'block'; }
    } finally {
      saveBtn.disabled = false;
      saveBtn.textContent = 'Save Card';
    }
  });

  getSavedCards()
    .then(res => renderCards(res.data || res || []))
    .catch(() => renderCards([]));
}

/* ── Tab switching ──────────────────────────────────────── */
function initTabs() {
  const tabs = document.querySelectorAll('[data-tab]');
  const panels = document.querySelectorAll('[data-panel]');
  const mobileTabs = document.querySelector('[data-mobile-tabs]');

  // Build mobile tab strip
  if (mobileTabs) {
    tabs.forEach(tab => {
      const btn = document.createElement('button');
      btn.className = 'dash-mobile-tab';
      btn.type = 'button';
      btn.textContent = tab.textContent.trim();
      btn.dataset.mobileTab = tab.dataset.tab;
      mobileTabs.appendChild(btn);
    });
  }

  function showTab(id) {
    tabs.forEach(t => {
      const active = t.dataset.tab === id;
      t.classList.toggle('is-active', active);
      t.setAttribute('aria-selected', String(active));
    });
    document.querySelectorAll('.dash-mobile-tab').forEach(t => {
      t.classList.toggle('is-active', t.dataset.mobileTab === id);
    });
    panels.forEach(p => {
      const active = p.dataset.panel === id;
      p.classList.toggle('is-active', active);
      p.hidden = !active;
      if (active) revealAll(p);
    });
    sessionStorage.setItem(TAB_KEY, id);
  }

  tabs.forEach(tab => tab.addEventListener('click', () => {
    showTab(tab.dataset.tab);
    if (tab.dataset.tab === 'history' && !_historyLoaded) {
      _historyLoaded = true;
      loadHistoryData().catch(err => {
        console.error('[History]', err);
        const root = document.getElementById('historyListRoot');
        if (root) root.innerHTML = '<div class="history-error-state"><p>Failed to load history. Please refresh.</p></div>';
      });
    }
  }));
  document.querySelectorAll('.dash-mobile-tab').forEach(btn => {
    btn.addEventListener('click', () => {
      showTab(btn.dataset.mobileTab);
      if (btn.dataset.mobileTab === 'history' && !_historyLoaded) {
        _historyLoaded = true;
        loadHistoryData().catch(err => {
          console.error('[History]', err);
          const root = document.getElementById('historyListRoot');
          if (root) root.innerHTML = '<div class="history-error-state"><p>Failed to load history. Please refresh.</p></div>';
        });
      }
    });
  });

  // data-tab-link buttons (Quick Actions → Bookings, Favourites, etc.)
  document.querySelectorAll('[data-tab-link]').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.tabLink));
  });

  // Cancel booking with contextual confirmation
  document.querySelectorAll('[data-cancel-booking]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const bookingId = btn.dataset.cancelBooking;
      const type = btn.dataset.cancelType || 'confirmed';
      const msg =
        type === 'pending'
          ? (typeof window.t === 'function' ? window.t('confirm_withdraw') : 'Withdraw this pending request? You can submit a new booking anytime.')
          : (typeof window.t === 'function' ? window.t('confirm_cancel') : 'Cancel this confirmed visit? You may need to book a new slot if you still need the service.');
      if (!window.confirm(msg)) return;
      try {
        if (bookingId) await cancelBooking(bookingId);
        const card = btn.closest('.dash-card, .booking-card');
        if (card) {
          card.style.transition = 'opacity 0.3s, transform 0.3s';
          card.style.opacity = '0';
          card.style.transform = 'translateX(8px)';
          setTimeout(() => {
            card.remove();
            if (typeof window.applyBookingFilter === 'function') window.applyBookingFilter();
          }, 300);
        }
        showToast(typeof window.t === 'function'
          ? (type === 'pending' ? window.t('toast_request_withdrawn') : window.t('toast_booking_cancelled'))
          : (type === 'pending' ? 'Request withdrawn.' : 'Booking cancelled.'), 'info');
      } catch (err) {
        showToast(err.message || 'Failed to cancel booking', 'error');
      }
    });
  });

  // Restore saved tab
  const saved = sessionStorage.getItem(TAB_KEY) || 'overview';
  showTab(saved);
  if (saved === 'history' && !_historyLoaded) {
    _historyLoaded = true;
    loadHistoryData().catch(err => {
      console.error('[History]', err);
      const root = document.getElementById('historyListRoot');
      if (root) root.innerHTML = '<div class="history-error-state"><p>Failed to load history. Please refresh.</p></div>';
    });
  }
  updateNotifBadge();
}

/* ── Populate profile info ──────────────────────────────── */
function populateProfile() {
  const session = getSession();
  const account = getAccount();
  if (!session) {
    const currentPath = window.location.pathname;
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
    const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
    window.location.href = './login.html?redirect=' + redirectParam;
    return;
  }

  const name = session.name || 'User';
  const initials = getInitials(name);

  document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = initials; });
  const nameEl = document.querySelector('[data-dash-name]');
  const emailEl = document.querySelector('[data-dash-email]');
  const welcomeEl = document.querySelector('[data-dash-welcome]');
  if (nameEl) {
    nameEl.textContent = name;
    nameEl.removeAttribute('data-i18n'); // real name set — prevent lang.js from re-translating to "Loading…"
  }
  if (emailEl) {
    const email = session.email || '';
    emailEl.textContent = email || '—';
  }
  const settingsEmailInput = document.getElementById('settings-email');
  if (settingsEmailInput) settingsEmailInput.value = session.email || '';
  const firstName = name.split(' ')[0];
  document.querySelectorAll('[data-dash-firstname]').forEach(el => {
    el.textContent = firstName;
    el.removeAttribute('data-i18n'); // real name set — prevent lang.js from re-translating to placeholder
  });
  if (welcomeEl) {
    welcomeEl.textContent = typeof window.t === 'function' ? window.t('cust_welcome_sub_text') : 'Your overview';
    welcomeEl.removeAttribute('data-i18n');
  }

  // Pre-fill settings form from account data
  if (account) {
    document.querySelectorAll('[data-settings-field]').forEach(f => {
      if (account[f.dataset.settingsField] != null) {
        f.value = account[f.dataset.settingsField];
      }
    });
  }

  // Render avatar — photo takes priority over initials
  function renderAvatar(photoUrl) {
    const preview  = document.querySelector('[data-avatar-preview]');
    const topbar   = document.getElementById('topbar-avatar');
    const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
    if (preview) {
      preview.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : `<span data-dash-initials>${initials}</span>`;
    }
    if (topbar) {
      topbar.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : initials[0] || 'U';
    }
  }

  // Show photo from session immediately (no flash)
  renderAvatar(session.profileImage || null);

  // Enrich profile from real API
  getMe().then(res => {
    const user = res;
    if (!user) return;
    const apiInitials = getInitials(user.name || '');
    document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = apiInitials; });

    // Update avatar with server photo if available
    if (user.profileImage) {
      renderAvatar(user.profileImage);
      // Keep session in sync
      const s = getSession();
      if (s && s.profileImage !== user.profileImage) {
        s.profileImage = user.profileImage;
        localStorage.setItem('servio_session', JSON.stringify(s));
      }
    }

    document.querySelectorAll('[data-dash-name], [data-cust-name], [data-dash-firstname]').forEach(el => {
      if (el.dataset.dashFirstname !== undefined) {
        el.textContent = (user.name || '').split(' ')[0] || '—';
      } else {
        el.textContent = user.name || '—';
      }
      el.removeAttribute('data-i18n');
    });
    const apiName = user.name || '';
    document.querySelectorAll('[data-dash-email], [data-cust-email]').forEach(el => {
      el.textContent = user.email || '—';
      el.removeAttribute('data-i18n');
    });

    // Pre-fill settings fields
    window.__servio_profile_email = user.email || '';
    try {
      const storedAccount = getAccount() || {};
      const syncedAccount = {
        ...storedAccount,
        name: apiName,
        fullName: apiName,
        email: user.email || '',
        phone: user.phone || '',
      };
      delete syncedAccount.city;
      localStorage.setItem('servio_account', JSON.stringify(syncedAccount));
    } catch (_) {}

    const fieldsMap = { name: apiName, fullName: apiName, email: user.email || '', phone: user.phone || '' };
    Object.entries(fieldsMap).forEach(([key, val]) => {
      const f = document.querySelector(`[data-settings-field="${key}"], input[name="${key}"]`);
      if (f) f.value = val;
    });
    const settingsEmail = document.getElementById('settings-email');
    if (settingsEmail) settingsEmail.value = user.email || '';

    window.__servio_user_addresses = Array.isArray(user.addresses) ? user.addresses : [];
    renderAddressList();

    const firstAddr = window.__servio_user_addresses[0];
    if (firstAddr) {
      const full = [firstAddr.street, firstAddr.city, firstAddr.state].filter(Boolean).join(', ');
      const addrProfEl = document.getElementById('profile-address');
      if (addrProfEl && full) addrProfEl.textContent = full;
    }

    // Update session in localStorage with fresh data
    try {
      const sess = JSON.parse(localStorage.getItem('servio_session') || '{}');
      localStorage.setItem('servio_session', JSON.stringify({ ...sess, name: apiName, email: user.email }));
    } catch (_) {}
    updateProfileCompleteness();
    if (typeof window.__servio_refreshProfileEditState === 'function') {
      window.__servio_refreshProfileEditState();
    }
  }).catch((err) => {
    console.error('Failed to load profile:', err);
    showToast(getErrorMessage(err, 'Failed to load the latest profile details.'), 'error');
  });
}

/* ── Live bookings & reviews data from API ──────────────── */
async function loadBookingsData() {
  const activePane = document.querySelector('#bookings-stab-bar .stab-btn--active')?.dataset.stab || 'bookings-active';
  try {
    const res = await getMyBookings({ limit: 200 });
    const bookings = res?.bookings || [];

    if (!_bookingSnapshotBuilt) {
      _buildSnapshot(bookings);
      _bookingSnapshotBuilt = true;
    } else {
      _diffAndNotify(bookings);
    }

    renderBookingsTab(bookings);
    populateStats(bookings);
    _restoreSubTab(activePane);
  } catch (err) {
    console.error('[Bookings]', err);
    const pane = document.getElementById('stab-bookings-active');
    if (pane) pane.innerHTML = `<div class="bookings-error-state"><p>Failed to load bookings. Please refresh.</p></div>`;
  }
}

function _buildSnapshot(bookings) {
  const snap = {};
  bookings.forEach(b => { if (b._id) snap[b._id] = b.status; });
  try { localStorage.setItem('servio_booking_snapshot', JSON.stringify(snap)); } catch (_) {}
}

function _diffAndNotify(bookings) {
  let snap;
  try { snap = JSON.parse(localStorage.getItem('servio_booking_snapshot') || '{}'); } catch { snap = {}; }

  const NOTIF_MAP = {
    accepted:    { type: 'booking_confirmed',   title: 'Booking Confirmed',   body: (svc, tech) => `${svc} with ${tech} is confirmed` },
    in_progress: { type: 'booking_in_progress', title: 'Technician En Route', body: (svc, tech) => `${tech} is on the way` },
    completed:   { type: 'booking_completed',   title: 'Service Completed',   body: (svc) => `Tap to rate your ${svc} experience` },
    cancelled:   { type: 'booking_cancelled',   title: 'Booking Cancelled',   body: (svc) => `${svc} has been cancelled` },
    rejected:    { type: 'booking_rejected',    title: 'Request Declined',    body: (svc) => `${svc} request was not accepted` },
  };

  let notifs = _getStoredNotifications();
  let changed = false;

  bookings.forEach(b => {
    if (!b._id) return;
    const newStatus = b.status;
    const oldStatus = snap[b._id];
    if (newStatus === oldStatus) return;

    const cfg = NOTIF_MAP[newStatus];
    if (!cfg) { snap[b._id] = newStatus; return; }

    const notifId = `${b._id}_${newStatus}`;
    if (notifs.some(n => n.id === notifId)) { snap[b._id] = newStatus; return; }

    const svc = b.service?.title || b.serviceCategory || 'Service';
    const tech = b.worker?.name || 'your technician';

    notifs.unshift({
      id: notifId,
      type: cfg.type,
      title: cfg.title,
      body: cfg.body(svc, tech),
      bookingId: b._id,
      status: newStatus,
      timestamp: new Date().toISOString(),
      read: false,
    });
    notifs.splice(50);
    snap[b._id] = newStatus;
    changed = true;
  });

  _saveNotifications(notifs);
  try { localStorage.setItem('servio_booking_snapshot', JSON.stringify(snap)); } catch (_) {}

  if (changed) {
    renderNotifications();
    updateNotifBadge();
  }
}

async function loadHistoryData() {
  const root = document.getElementById('historyListRoot');
  if (!root) return;
  root.innerHTML = '<div class="bookings-loading-state">Loading history…</div>';

  const [bookings, reviews] = await Promise.all([
    getMyBookings({ status: 'completed,cancelled,rejected', limit: 200 }).then(r => r?.bookings || []),
    getMyReviews().catch(() => []),
  ]);

  root.innerHTML = '';
  if (!bookings.length) {
    root.innerHTML = '<div class="history-empty-state"><p>No completed bookings yet.</p></div>';
    return;
  }

  bookings.forEach(b => {
    const review = reviews.find(r => r.booking?.toString() === b._id?.toString());
    const card = buildHistoryCard(b, review);
    root.appendChild(card);
  });

  // Update stats
  const countEl = document.getElementById('histStatCount');
  if (countEl) countEl.textContent = bookings.length;
  const spentEl = document.getElementById('histStatSpent');
  if (spentEl) spentEl.textContent = bookings.reduce((s, b) => s + (b.totalPrice || 0), 0) + ' EGP';
  const topEl = document.getElementById('histStatTopCategory');
  if (topEl) {
    const freq = {};
    bookings.forEach(b => { const c = b.serviceCategory || b.service?.category || ''; if (c) freq[c] = (freq[c] || 0) + 1; });
    const top = Object.entries(freq).sort((a, b) => b[1] - a[1])[0];
    if (top) { topEl.textContent = top[0]; topEl.removeAttribute('data-i18n'); }
  }

  revealAll(root);

  // Wire invoice toggles
  root.querySelectorAll('[data-invoice-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
      const card = btn.closest('.history-card-v2');
      if (!card) return;
      card.classList.toggle('is-expanded');
    });
  });

  // Wire rating submit buttons
  root.querySelectorAll('[data-submit-review]').forEach(btn => {
    const rateBlock = btn.closest('[data-rate-block]');
    if (!rateBlock) return;
    rateBlock.querySelectorAll('input[type="radio"]').forEach(radio => {
      radio.addEventListener('change', () => { btn.disabled = false; });
    });
    btn.addEventListener('click', () => submitReview(btn));
  });
}

function buildHistoryCard(b, review) {
  const category = b.service?.category || b.serviceCategory || '';
  const title    = b.service?.title || b.serviceCategory || 'Service';
  const workerName = b.worker?.name || '—';
  const dateStr  = b.scheduledDate
    ? new Date(b.scheduledDate).toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' })
    : '—';
  const priceRaw     = b.totalPrice != null ? String(b.totalPrice).replace('$', '').trim() : '—';
  const paymentMethod = b.paymentMethod === 'cash' ? 'Cash' : 'Credit Card';
  const ref          = `#${(b._id || '').slice(-6).toUpperCase()}`;
  const isCompleted  = b.status === 'completed';
  const isCancelled  = b.status === 'cancelled' || b.status === 'rejected';
  const rating       = review?.rating ?? 0;
  const comment      = review?.comment || '';

  // Service icon — inline SVGs matching the services marketplace page
  const CAT_ICON_SVG = {
    plumb:  `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"/><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"/></svg>`,
    electr: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>`,
    clean:  `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/><path d="M20 3v4"/><path d="M22 5h-4"/><path d="M4 17v2"/><path d="M5 18H3"/></svg>`,
    carp:   `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"/></svg>`,
    ac:     `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h20"/><path d="M12 2v20"/><path d="m20 16-4-4 4-4"/><path d="m4 8 4 4-4 4"/><path d="m16 4-4 4-4-4"/><path d="m8 20 4-4 4 4"/></svg>`,
    appli:  `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="20" x="3" y="2" rx="2"/><circle cx="12" cy="13" r="5"/><path d="M6 6h.01"/><path d="M9 6h.01"/></svg>`,
  };
  const catLow   = category.toLowerCase();
  const catKey   = Object.keys(CAT_ICON_SVG).find(k => catLow.includes(k));
  const iconHtml = CAT_ICON_SVG[catKey] || `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`;

  // Static star display for rated bookings
  const staticStars = rating
    ? Array.from({ length: 5 }, (_, i) =>
        i < rating ? STAR_SVG('var(--color-accent)', 22) : EMPTY_STAR_SVG(22)
      ).join('')
    : '';

  // Rating section markup
  let ratingSection = '';
  if (isCompleted && rating) {
    ratingSection = `
      <div class="history-v2__comment-block">
        <div class="history-v2__rating-stars" aria-label="${rating} out of 5 stars">${staticStars}</div>
        ${comment ? `<p class="history-v2__comment-text">"${comment}"</p>` : ''}
      </div>`;
  } else if (isCompleted && !rating) {
    // Interactive rating widget — CSS-only star picker (RTL trick: reversed flex + sibling combinator)
    const uid = (b._id || Math.random().toString(36).slice(2)).slice(-8);
    ratingSection = `
      <div class="history-v2__rate-block" data-rate-block>
        <span class="history-v2__rate-label">Rate this service</span>
        <div class="history-v2__rate-block-col">
          <div class="history-v2__stars-picker" role="radiogroup" aria-label="Star rating">
            ${[5,4,3,2,1].map(n => `
              <input type="radio" name="rating-${uid}" id="star-${uid}-${n}" value="${n}" />
              <label for="star-${uid}-${n}" aria-label="${n} star${n > 1 ? 's' : ''}">
                ${EMPTY_STAR_SVG(28)}
              </label>`).join('')}
          </div>
          <textarea class="history-v2__comment-input" placeholder="Share your experience (optional)" rows="2" maxlength="1000"></textarea>
          <button class="history-v2__submit-btn" data-submit-review data-booking-id="${b._id}" disabled>Submit Review</button>
        </div>
      </div>`;
  }

  // Payment icon SVG
  const payIcon = paymentMethod === 'Cash'
    ? `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M22 10H2"/></svg>`
    : `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>`;

  const el = document.createElement('article');
  el.className = 'history-card-v2';
  el.dataset.category = category;
  el.dataset.payment  = paymentMethod;
  el.dataset.date     = b.scheduledDate || '';
  el.dataset.rating   = String(rating);
  el.dataset.cat      = catKey || 'default';

  el.innerHTML = `
    <div class="history-v2__top-row">
      <div class="history-v2__main">
        <div class="history-v2__icon">${iconHtml}</div>
        <div class="history-v2__info">
          <div class="history-v2__title-row">
            <h4 class="history-v2__title">${title}</h4>
            <small class="history-v2__id">${ref}</small>
            ${isCancelled ? `<span class="history-v2__status-badge badge-cancelled">Cancelled</span>` : ''}
            ${isCompleted && !isCancelled ? `<span class="history-v2__status-badge badge-completed">Completed</span>` : ''}
          </div>
          <p class="history-v2__provider">
            <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            ${workerName}
            <span class="dot-sep"></span>
            <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
            ${dateStr}
          </p>
        </div>
      </div>
      <div class="history-v2__meta">
        <div class="history-v2__price">${priceRaw !== '—' ? priceRaw + ' EGP' : '—'}</div>
        <span class="history-v2__payment-badge">
          <span class="history-v2__payment-icon">${payIcon}</span>
          ${paymentMethod}
        </span>
      </div>
      <div class="history-v2__actions">
        <button class="btn btn--sm btn--outline" data-invoice-toggle>
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          View Invoice
        </button>
      </div>
    </div>
    ${ratingSection ? `<div class="history-v2__review-section">${ratingSection}</div>` : ''}
    <div class="history-v2__expanded">
      <div class="history-v2__expanded-inner">
        <div class="invoice-grid">
          <div class="invoice-breakdown">
            <h5 class="invoice-breakdown__title">Cost Breakdown</h5>
            <div class="invoice-item"><span>${title}</span><span>${priceRaw !== '—' ? priceRaw + ' EGP' : '—'}</span></div>
            <div class="invoice-item is-total"><span>Total Paid</span><span>${priceRaw !== '—' ? priceRaw + ' EGP' : '—'}</span></div>
          </div>
          <div class="invoice-details">
            <h5 class="invoice-breakdown__title">Payment</h5>
            <div class="payment-method-footer">
              <div class="payment-method-box">
                <span class="history-v2__payment-icon">${payIcon}</span>
                <p>Paid with ${paymentMethod}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>`;

  return el;
}

async function submitReview(btn) {
  const card       = btn.closest('.history-card-v2');
  const rateBlock  = card.querySelector('[data-rate-block]');
  if (!rateBlock) return;
  const bookingId  = btn.dataset.bookingId;
  const ratingInput = rateBlock.querySelector('input[type="radio"]:checked');
  const textarea   = rateBlock.querySelector('.history-v2__comment-input');

  if (!ratingInput) return;

  const rating  = parseInt(ratingInput.value, 10);
  const comment = textarea.value.trim();

  btn.disabled = true;
  btn.textContent = 'Submitting…';

  try {
    await createReview(bookingId, rating, comment);

    const staticStars = Array.from({ length: 5 }, (_, i) =>
      i < rating ? STAR_SVG('var(--color-accent)', 22) : EMPTY_STAR_SVG(22)
    ).join('');

    rateBlock.outerHTML = `
      <div class="history-v2__comment-block">
        <div class="history-v2__rating-stars" aria-label="${rating} out of 5 stars">${staticStars}</div>
        ${comment ? `<p class="history-v2__comment-text">"${comment}"</p>` : ''}
      </div>`;

    card.dataset.rating = String(rating);
    showToast('Review submitted. Thank you!', 'success');
  } catch (err) {
    btn.disabled = false;
    btn.textContent = 'Submit Review';
    if (err.status === 409) {
      showToast('You already reviewed this booking.', 'info');
    } else {
      showToast(err.message || 'Failed to submit review.', 'error');
    }
  }
}

function renderBookingsTab(bookings) {
  const STATUS_TO_PANE = {
    accepted: 'stab-bookings-active', in_progress: 'stab-bookings-active',
    pending: 'stab-bookings-pending',
  };
  const paneIds = ['stab-bookings-active', 'stab-bookings-pending'];
  const EMPTY = {
    'stab-bookings-active': 'No active bookings.',
    'stab-bookings-pending': 'No pending bookings.',
  };

  const openInvoiceIds = new Set();
  const panes = {};
  paneIds.forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      // Find open invoices before wiping
      el.querySelectorAll('.booking-card').forEach(card => {
        const panel = card.querySelector('.booking-card__invoice-panel');
        if (panel && panel.classList.contains('is-open') && card.dataset.bookingId) {
          openInvoiceIds.add(card.dataset.bookingId);
        }
      });
      el.innerHTML = ''; 
      panes[id] = el;
    }
  });

  bookings.forEach(b => {
    const paneId = STATUS_TO_PANE[b.status];
    const pane = paneId && panes[paneId];
    if (!pane) return;
    const card = buildBookingCard(b);
    if (card) {
      if (openInvoiceIds.has(b._id)) {
        const panel = card.querySelector('.booking-card__invoice-panel');
        const btn = card.querySelector('[data-invoice-toggle]');
        if (panel) panel.classList.add('is-open');
        if (btn) btn.textContent = 'Hide Invoice';
      }
      pane.appendChild(card);
    }
  });

  paneIds.forEach(id => {
    const pane = panes[id];
    if (!pane) return;
    if (!pane.children.length) {
      pane.innerHTML = `<div class="bookings-empty-state"><p>${EMPTY[id]}</p></div>`;
    } else {
      wireBookingCardEvents(pane);
      revealAll(pane);
    }
  });
}

function getServiceIconSVG(category) {
  const c = (category || '').toLowerCase();
  if (c.includes('plumb') || c.includes('pipe') || c.includes('water')) {
    return `<svg width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"/><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"/></svg>`;
  }
  if (c.includes('elec') || c.includes('wiring') || c.includes('power')) {
    return `<svg width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>`;
  }
  if (c.includes('hvac') || c.includes('ac') || c.includes('air') || c.includes('cool') || c.includes('heat')) {
    return `<svg width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/><line x1="9.5" y1="9.5" x2="14.5" y2="14.5"/><line x1="14.5" y1="9.5" x2="9.5" y2="14.5"/></svg>`;
  }
  if (c.includes('clean')) {
    return `<svg width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>`;
  }
  return `<svg width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`;
}

function buildBookingCard(b) {
  if (!b._id) return null;

  const STATUS_FILTER = {
    pending: 'pending', accepted: 'confirmed', in_progress: 'confirmed',
    completed: 'completed', cancelled: 'cancelled', rejected: 'cancelled'
  };
  const BADGE_CONFIG = {
    pending:     { label: 'Booked',      style: 'background:rgba(234,179,8,0.1);color:#eab308;border-color:rgba(234,179,8,0.3)' },
    accepted:    { label: 'Confirmed',   style: '' },
    in_progress: { label: 'In Progress', style: 'background:rgba(180,160,50,0.1);color:#eab308;border-color:#eab308' },
    completed:   { label: 'Completed',   style: 'background:rgba(34,197,94,0.1);color:#22c55e;border-color:rgba(34,197,94,0.3)' },
    cancelled:   { label: 'Cancelled',   style: 'background:rgba(156,163,175,0.1);color:#9ca3af;border-color:rgba(156,163,175,0.3)' },
    rejected:    { label: 'Declined',    style: 'background:rgba(156,163,175,0.1);color:#9ca3af;border-color:rgba(156,163,175,0.3)' }
  };
  const STEPPER_CONFIG = {
    pending:     { done: 0, active: 0, fill: '0%' },
    accepted:    { done: 1, active: 1, fill: '33%' },
    in_progress: { done: 2, active: 2, fill: '66%' },
    completed:   { done: 4, active: -1, fill: '100%' }
  };

  const status = b.status || 'pending';
  const isCancelled = status === 'cancelled' || status === 'rejected';
  const badge = BADGE_CONFIG[status] || BADGE_CONFIG.pending;
  const stepperCfg = STEPPER_CONFIG[status] || null;
  const filterStatus = STATUS_FILTER[status] || 'pending';

  const title = b.service?.title || b.serviceCategory || 'Service';
  const category = b.service?.category || b.serviceCategory || '';
  const workerName = b.worker?.name || '—';
  const formattedDate = b.scheduledDate
    ? new Date(b.scheduledDate).toLocaleDateString('en-US', { weekday: 'short', month: 'long', day: 'numeric', year: 'numeric' })
    : '—';
  const priceRaw = b.totalPrice != null ? String(b.totalPrice).replace('$', '').trim() : '—';
  const price = priceRaw;
  const paymentMethod = b.paymentMethod === 'cash' ? 'Cash' : 'Credit Card';
  const bookingRef = `#${b._id.slice(-6).toUpperCase()}`;

  // Avatar
  let avatarHTML;
  if (b.worker?.profileImage) {
    avatarHTML = `<img src="${b.worker.profileImage}" alt="${workerName}" class="provider-avatar">`;
  } else if (b.worker?.name) {
    const initials = b.worker.name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase();
    avatarHTML = `<span class="provider-avatar provider-avatar--initials">${initials}</span>`;
  } else {
    avatarHTML = '';
  }

  // View profile link
  const workerId = (b.worker && typeof b.worker === 'object' ? (b.worker._id || b.worker.id) : b.worker) || '';

  const viewProfileHTML = workerId
    ? `<a href="./technician-profile.html?id=${workerId}" class="provider-view-profile">View Profile</a>`
    : '';

  // PIN
  const pinStr = b.pin ? String(b.pin) : '----';
  const pinHTML = pinStr.split('').slice(0, 4).map(d => `<span class="pin-code__digit">${d}</span>`).join('');

  // Stepper
  const checkSVG = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14"><polyline points="20 6 9 17 4 12"/></svg>`;
  const STEP_LABELS = ['Booked', 'Confirmed', 'En Route', 'Completed'];
  let stepperHTML;
  if (!stepperCfg) {
    stepperHTML = `<div class="booking-card__progress-wrap"><p style="color:var(--color-text-muted,#9ca3af);font-size:0.8rem;font-weight:600;padding:8px 0;margin:0;">Booking ${badge.label}</p></div>`;
  } else {
    const stepsHTML = STEP_LABELS.map((lbl, i) => {
      const isDone = i < stepperCfg.done;
      const isActive = stepperCfg.active !== -1 && i === stepperCfg.active && !isDone;
      const cls = `tracking-step${isDone ? ' is-done' : isActive ? ' is-active' : ''}`;
      return `<div class="${cls}"><div class="step-marker">${isDone ? checkSVG : ''}</div><span class="step-label">${lbl}</span></div>`;
    }).join('');
    stepperHTML = `<div class="booking-card__progress-wrap"><div class="tracking-status"><div class="tracking-track"><div class="tracking-track-fill" style="width:${stepperCfg.fill}"></div></div><div class="tracking-steps">${stepsHTML}</div></div></div>`;
  }

  // Cancel button
  let cancelHTML = '';
  if (status === 'pending' || status === 'accepted') {
    const cancelType = status === 'pending' ? 'pending' : 'confirmed';
    const cancelLabel = status === 'pending' ? 'Withdraw Request' : 'Cancel Booking';
    cancelHTML = `<button class="btn btn--cancel" type="button" data-cancel-booking="${b._id}" data-cancel-type="${cancelType}">${cancelLabel}</button>`;
  }

  // Invoice panel
  const invoiceHTML = !isCancelled ? `<div class="booking-card__invoice-panel"><div class="invoice-content"><p class="invoice-content__title">Invoice ${bookingRef}</p><div class="invoice-table"><div class="invoice-table__row"><span>${title}</span><span>${price !== '—' ? price + ' EGP' : '—'}</span></div><div class="invoice-table__row"><span>Service Date</span><span>${formattedDate}</span></div><div class="invoice-table__row"><span>Platform Fee</span><span>0 EGP</span></div><div class="invoice-table__row is-total"><span>Total</span><span>${price !== '—' ? price + ' EGP' : '—'}</span></div></div><div class="booking-card__invoice-footer"><p>Payment Method: <strong>${paymentMethod}</strong></p></div></div></div>` : '';

  const div = document.createElement('div');
  div.className = 'booking-card';
  div.dataset.bookingId = b._id;
  div.dataset.bookingCard = '';
  div.dataset.bookingStatus = filterStatus;
  if (b.scheduledDate) div.dataset.bookingDate = b.scheduledDate;

  div.innerHTML = `
    <div class="booking-card__inner">
      <div class="booking-card__body">
        <div class="booking-card__header">
          <div class="booking-card__title-grp">
            <div class="booking-card__service-row">
              <div class="booking-card__header-icon">${getServiceIconSVG(category)}</div>
              <h3 class="booking-card__title">${title}</h3>
            </div>
            <div class="booking-card__provider-wrap">
              ${avatarHTML}
              <div class="booking-card__provider-info">
                <span class="provider-tech-label">Technician</span>
                <span class="provider-name">${workerName}</span>
              </div>
              ${viewProfileHTML}
            </div>
          </div>
          <span class="booking-card__status-badge"${badge.style ? ` style="${badge.style}"` : ''}>${badge.label}</span>
        </div>
        <div class="booking-card__grid">
          <div class="booking-grid-box">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
            <div><span class="booking-grid-box__label">Service Date</span><span class="booking-grid-box__value">${formattedDate}</span></div>
          </div>
          <div class="booking-grid-box">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            <div><span class="booking-grid-box__label">Time Slot</span><span class="booking-grid-box__value">${b.scheduledTime || '—'}</span></div>
          </div>
          <div class="booking-grid-box booking-grid-box--full">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
            <div><span class="booking-grid-box__label">Service Address</span><span class="booking-grid-box__value">${b.address || '—'}</span></div>
          </div>
        </div>
        ${stepperHTML}
      </div>
      <div class="booking-card__sidebar">
        <div class="sidebar-box">
          <div class="sidebar-box__header">Your PIN</div>
          <div class="pin-code">${pinHTML}</div>
        </div>
        <div class="sidebar-box sidebar-box--amount">
          <div class="sidebar-box__header">Amount</div>
          <div class="price-display">
            <span class="price-display__value">${price}</span>
            ${price !== '—' ? `<span class="price-display__currency">EGP</span>` : ''}
          </div>
        </div>
        <div class="booking-card__actions">
          <a class="btn btn--view-details" href="./booking-details.html?id=${b._id}">View Details</a>
          ${!isCancelled ? `<button class="btn btn--invoice" type="button" data-invoice-toggle>View Invoice</button>` : ''}
          ${!isCancelled ? `<a class="btn btn--chat" href="./messages.html?booking=${b._id}">Chat</a>` : ''}
          ${cancelHTML}
        </div>
      </div>
    </div>
    ${invoiceHTML}`;
  return div;
}

function wireBookingCardEvents(root) {
  if (root.dataset.eventsWired === 'true') return;
  root.dataset.eventsWired = 'true';

  root.addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-cancel-booking]');
    if (!btn) return;
    const bookingId = btn.dataset.cancelBooking;
    const type = btn.dataset.cancelType || 'confirmed';
    const msg = type === 'pending'
      ? (typeof window.t === 'function' ? window.t('confirm_withdraw') : 'Withdraw this pending request? You can submit a new booking anytime.')
      : (typeof window.t === 'function' ? window.t('confirm_cancel') : 'Cancel this confirmed visit? You may need to book a new slot if you still need the service.');
    if (!confirm(msg)) return;
    btn.disabled = true;
    try {
      await cancelBooking(bookingId);
      const card = btn.closest('.booking-card');
      if (card) {
        card.style.transition = 'opacity 0.3s, transform 0.3s';
        card.style.opacity = '0';
        card.style.transform = 'translateX(8px)';
        setTimeout(() => { card.remove(); }, 300);
      }
      showToast(type === 'pending' ? 'Request withdrawn.' : 'Booking cancelled.', 'info');
    } catch (err) {
      btn.disabled = false;
      showToast(err.message || 'Failed to cancel booking.', 'error');
    }
  });

  root.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-invoice-toggle]');
    if (!btn) return;
    const panel = btn.closest('.booking-card')?.querySelector('.booking-card__invoice-panel');
    if (!panel) return;
    const isOpen = panel.classList.toggle('is-open');
    btn.textContent = isOpen ? 'Hide Invoice' : 'View Invoice';
  });
}

/* ── Stats ──────────────────────────────────────────────── */
async function populateStats(bookings = null) {
  try {
    if (!bookings) {
      const res = await getMyBookings({ limit: 100 });
      bookings = res?.bookings || [];
    }

    const total     = bookings.length;
    const active    = bookings.filter(b => ['pending','accepted','in_progress'].includes(b.status)).length;
    const completed = bookings.filter(b => b.status === 'completed').length;
    const totalSpent = bookings
      .filter(b => b.status === 'completed' && b.totalPrice)
      .reduce((sum, b) => sum + (b.totalPrice || 0), 0);

    const goalTotal = 5;
    const pct = Math.min(Math.round((completed / goalTotal) * 100), 100);

    const tEl = document.querySelector('[data-stat="total-bookings"]');
    const aEl = document.querySelector('[data-stat="active-bookings"]');
    if (tEl) tEl.textContent = total;
    if (aEl) aEl.textContent = active;

    const spentEl = document.querySelector('[data-stat="total-spent"]');
    if (spentEl) spentEl.textContent = totalSpent + ' EGP';

    const ctxE = document.querySelector('.dash-stat-card__context[data-i18n-html]');
    if (ctxE) {
      ctxE.setAttribute('data-i18n-pct', String(pct));
      if (window.applyLanguage && window.__lang) window.applyLanguage(window.__lang);
    }
    const barFill = document.querySelector('[data-stat-goal-bar="total"]');
    if (barFill) barFill.style.width = pct + '%';
  } catch {
    // silently fallback — stats not critical
  }
}

/* ── Time-aware welcome text ────────────────────────────── */
function updateWelcomeText() {
  const timeLabel = document.querySelector('.dash-welcome__time-label');
  if (timeLabel) {
    const hour = new Date().getHours();
    const greetingKey = hour < 12 ? 'greeting_morning' : hour < 17 ? 'greeting_afternoon' : 'greeting_evening';
    timeLabel.textContent = typeof window.t === 'function' ? window.t(greetingKey) : (hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening');
  }
  const subEl = document.querySelector('.dash-welcome__sub');
  if (subEl) {
    const activeCount = parseInt(document.querySelector('[data-stat="active-bookings"]')?.textContent, 10) || 0;
    if (typeof window.t === 'function') {
      subEl.textContent =
        activeCount === 0
          ? window.t('cust_no_visits')
          : activeCount === 1
            ? window.t('cust_one_booking')
            : window.t('cust_n_bookings', { n: activeCount });
    } else {
      subEl.textContent =
        activeCount === 0
          ? 'No visits in progress — book when you\'re ready.'
          : activeCount === 1
            ? 'You have 1 booking in progress; details are under Bookings.'
            : `You have ${activeCount} bookings in progress — see the Bookings tab for status.`;
    }
  }
}

/* ── Notifications: localStorage persistence ─────────── */
function _getStoredNotifications() {
  try { return JSON.parse(localStorage.getItem('servio_notifications') || '[]'); } catch { return []; }
}

function _saveNotifications(arr) {
  try {
    localStorage.setItem('servio_notifications', JSON.stringify(arr));
  } catch (e) {
    if (e.name === 'QuotaExceededError') {
      arr.splice(25);
      try { localStorage.setItem('servio_notifications', JSON.stringify(arr)); } catch (_) {}
    }
  }
}

function _setBadge(el, count) {
  if (!el) return;
  let badge = el.querySelector('.notif-badge');
  if (!badge) {
    badge = document.createElement('span');
    badge.className = 'notif-badge';
    el.appendChild(badge);
  }
  badge.textContent = count;
  badge.hidden = count === 0;
}

function updateNotifBadge() {
  const notifs = _getStoredNotifications();
  const unread = notifs.filter(n => !n.read).length;
  _setBadge(document.getElementById('tab-notifications'), unread);
  const mobileBtn = document.querySelector('[data-mobile-tab="notifications"]');
  if (mobileBtn) _setBadge(mobileBtn, unread);
}

function renderNotifications() {
  const list = document.getElementById('notif-list');
  if (!list) return;
  const notifs = _getStoredNotifications();

  if (!notifs.length) {
    list.innerHTML = '<div class="notif-empty-state"><p>No notifications yet.</p></div>';
    return;
  }

  const TYPE_ICON = {
    booking_confirmed:   `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#22A05A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`,
    booking_in_progress: `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#6E56CF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`,
    booking_completed:   `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#22c55e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`,
    booking_cancelled:   `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#ef4444" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`,
    booking_rejected:    `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#ef4444" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`,
  };

  const STATUS_TO_SUBTAB = {
    accepted: 'bookings-active', in_progress: 'bookings-active',
    pending: 'bookings-pending', completed: 'bookings-completed',
    cancelled: 'bookings-cancelled', rejected: 'bookings-cancelled',
  };

  list.innerHTML = '';
  notifs.forEach(n => {
    const el = document.createElement('div');
    el.className = `notif-card-v2${n.read ? '' : ' is-unread'}`;
    el.dataset.notifId = n.id;

    const timeStr = n.timestamp ? new Date(n.timestamp).toLocaleString() : '';
    const icon = TYPE_ICON[n.type] || TYPE_ICON.booking_confirmed;
    const subtab = STATUS_TO_SUBTAB[n.status] || 'bookings-active';

    el.innerHTML = `
      <div class="notif-card-v2__icon notif-card-v2__icon--booking">${icon}</div>
      <div class="notif-card-v2__body">
        <p class="notif-card-v2__title">${n.title}</p>
        <p class="notif-card-v2__desc">${n.body}</p>
        <div class="notif-card-v2__actions">
          <button class="btn btn--sm" type="button" data-notif-view-booking="${subtab}">View Booking</button>
          <button class="btn btn--sm btn--danger-ghost" type="button" data-notif-dismiss="${n.id}">Dismiss</button>
        </div>
        <p class="notif-card-v2__time">${timeStr}</p>
      </div>`;
    list.appendChild(el);
  });

  list.addEventListener('click', (e) => {
    const viewBtn = e.target.closest('[data-notif-view-booking]');
    if (viewBtn) {
      const subtab = viewBtn.dataset.notifViewBooking;
      document.querySelector('[data-tab="bookings"]')?.click();
      setTimeout(() => {
        const btn = document.querySelector(`#bookings-stab-bar [data-stab="${subtab}"]`);
        btn?.click();
      }, 50);
      return;
    }
    const dismissBtn = e.target.closest('[data-notif-dismiss]');
    if (dismissBtn) {
      const id = dismissBtn.dataset.notifDismiss;
      let notifs = _getStoredNotifications();
      notifs = notifs.filter(n => n.id !== id);
      _saveNotifications(notifs);
      dismissBtn.closest('.notif-card-v2')?.remove();
      if (!list.querySelector('.notif-card-v2')) {
        list.innerHTML = '<div class="notif-empty-state"><p>No notifications yet.</p></div>';
      }
      updateNotifBadge();
    }
  }, { once: false });
}

function initNotifications() {
  const markAllBtn = document.getElementById('mark-all-read');
  if (markAllBtn) {
    markAllBtn.addEventListener('click', () => {
      const notifs = _getStoredNotifications().map(n => ({ ...n, read: true }));
      _saveNotifications(notifs);
      renderNotifications();
      updateNotifBadge();
      showToast(typeof window.t === 'function' ? window.t('toast_notif_read') : 'All notifications marked as read.', 'success');
    });
  }
  renderNotifications();
  updateNotifBadge();
}

/* ── Settings: photo upload ─────────────────────────────── */
function initSettingsForm() {
  const photoUploadInput = document.getElementById('photo-upload-input');
  const changePhotoBtn   = document.getElementById('btn-change-photo');
  const preview          = document.querySelector('[data-avatar-preview]');
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const form             = document.querySelector('[data-settings-form]');
  const editBtn          = document.getElementById('btn-profile-edit');
  const cancelBtn        = document.getElementById('btn-profile-cancel');
  const editActions      = form?.querySelector('[data-profile-edit-actions]');
  const editableFields   = form ? Array.from(form.querySelectorAll('[data-settings-field]')) : [];
  const emailInput       = document.getElementById('settings-email');
  const submitBtn        = form?.querySelector('button[type="submit"]');

  let isProfileEditing = false;
  let profileSnapshot = {};

  function setError(input, message) {
    if (!input) return;
    input.classList.add('is-invalid');
    input.classList.remove('is-valid');
    const host = input.closest('.form-field') || input.parentElement;
    let err = host?.querySelector('.field-error');
    if (!err && host) {
      err = document.createElement('p');
      err.className = 'field-error';
      host.appendChild(err);
    }
    if (err) {
      err.textContent = message;
      err.classList.add('is-visible');
    }
  }

  function clearError(input) {
    if (!input) return;
    input.classList.remove('is-invalid');
    const host = input.closest('.form-field') || input.parentElement;
    const err = host?.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  function clearProfileErrors() {
    form?.querySelectorAll('.is-invalid, .is-valid').forEach(el => {
      el.classList.remove('is-invalid', 'is-valid');
    });
    form?.querySelectorAll('.field-error').forEach(el => el.classList.remove('is-visible'));
  }

  function snapshotProfileFields() {
    profileSnapshot = {};
    editableFields.forEach(field => {
      profileSnapshot[field.dataset.settingsField] = field.value;
    });
    profileSnapshot.photoUrl = _pendingPhotoUrl || getSession()?.profileImage || null;
  }

  function renderProfilePreview(photoUrl) {
    const currentSession = getSession() || {};
    const initials = getInitials(currentSession.name || profileSnapshot.fullName || 'User');
    const topbar = document.getElementById('topbar-avatar');
    const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
    if (preview) {
      preview.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : `<span data-dash-initials>${initials}</span>`;
    }
    if (topbar) {
      topbar.innerHTML = photoUrl
        ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
        : initials[0] || 'U';
    }
  }

  function restoreProfileSnapshot() {
    editableFields.forEach(field => {
      const key = field.dataset.settingsField;
      if (profileSnapshot[key] !== undefined) field.value = profileSnapshot[key];
    });
    _pendingPhotoUrl = null;
    renderProfilePreview(profileSnapshot.photoUrl || getSession()?.profileImage || null);
    clearProfileErrors();
  }

  function setProfileEditMode(enabled, options = {}) {
    isProfileEditing = enabled;
    form?.classList.toggle('is-editing', enabled);
    if (enabled) {
      snapshotProfileFields();
    } else if (options.reset) {
      restoreProfileSnapshot();
    }

    editableFields.forEach(field => {
      field.readOnly = !enabled;
      field.setAttribute('aria-readonly', enabled ? 'false' : 'true');
    });

    if (changePhotoBtn) {
      changePhotoBtn.disabled = !enabled;
      changePhotoBtn.setAttribute('aria-disabled', String(!enabled));
    }
    if (editActions) editActions.hidden = !enabled;
    if (editBtn) {
      editBtn.setAttribute('aria-pressed', String(enabled));
      editBtn.disabled = enabled;
    }
  }

  window.__servio_refreshProfileEditState = () => {
    if (!isProfileEditing) {
      snapshotProfileFields();
      setProfileEditMode(false);
    }
  };

  editableFields.forEach(field => {
    field.addEventListener('input', () => {
      clearError(field);
    });
  });
  editBtn?.addEventListener('click', () => setProfileEditMode(true));
  cancelBtn?.addEventListener('click', () => {
    setProfileEditMode(false, { reset: true });
    showToast(_t('toast_profile_edit_cancelled') || 'Profile edits discarded.', 'info');
  });

  if (changePhotoBtn && photoUploadInput) {
    changePhotoBtn.addEventListener('click', () => {
      if (!isProfileEditing) return;
      photoUploadInput.click();
    });
  }

  if (photoUploadInput && preview) {
    photoUploadInput.addEventListener('change', async () => {
      if (!isProfileEditing) {
        photoUploadInput.value = '';
        return;
      }
      const file = photoUploadInput.files[0];
      if (!file) return;

      if (file.size > 2 * 1024 * 1024) {
        showToast(_t('toast_photo_error') || 'Image must be under 2 MB.', 'error');
        photoUploadInput.value = '';
        return;
      }

      // Show local preview immediately
      const reader = new FileReader();
      reader.onload = (evt) => {
        const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
        preview.innerHTML = `<img src="${evt.target.result}" alt="Profile photo" style="${imgStyle}" />`;
        const topbar = document.getElementById('topbar-avatar');
        if (topbar) topbar.innerHTML = `<img src="${evt.target.result}" alt="Profile photo" style="${imgStyle}" />`;
      };
      reader.readAsDataURL(file);

      // Upload to server
      changePhotoBtn.disabled = true;
      changePhotoBtn.textContent = _t('toast_photo_uploading') || 'Uploading…';
      try {
        const result = await uploadPublicFile(file, 'avatar');
        _pendingPhotoUrl = result.url;
        showToast(_t('toast_photo_uploaded') || 'Photo uploaded.', 'success');
      } catch {
        showToast(_t('toast_photo_error') || 'Failed to upload photo.', 'error');
        _pendingPhotoUrl = null;
        renderProfilePreview(profileSnapshot.photoUrl || getSession()?.profileImage || null);
      } finally {
        changePhotoBtn.disabled = !isProfileEditing;
        changePhotoBtn.setAttribute('aria-disabled', String(!isProfileEditing));
        changePhotoBtn.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg><span data-i18n="cust_change_photo">${_t('cust_change_photo') || 'Change Photo'}</span>`;
      }
    });
  }

  if (!form) return;
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!isProfileEditing) {
      showToast(_t('toast_profile_locked') || 'Click Edit before changing profile details.', 'info');
      return;
    }

    clearProfileErrors();
    let reqOk = true;
    form.querySelectorAll('input[data-required]').forEach(input => {
      if (!input.value.trim()) {
        reqOk = false;
        setError(input, _t('toast_fill_required') || 'Please fill all required fields.');
      }
    });
    if (!reqOk) {
      showToast(_t('toast_fill_required') || 'Please fill all required fields.', 'info');
      return;
    }

    const fullName = document.getElementById('settings-fullname')?.value.trim() || '';
    const phone = document.getElementById('settings-phone')?.value.trim() || '';
    const phoneOk = /^[+]?[\d\s\-().]{7,20}$/.test(phone);

    if (!phoneOk) {
      const phoneInput = document.getElementById('settings-phone');
      setError(phoneInput, _t('err_invalid_phone') || 'Please enter a valid phone number.');
      phoneInput?.focus();
      return;
    }

    let savedProfile = false;
    try {
      if (submitBtn) submitBtn.disabled = true;
      const updatePayload = { name: fullName, phone };
      const currentSession = getSession();
      const photoUrl = _pendingPhotoUrl || currentSession?.profileImage || null;
      if (photoUrl) updatePayload.profileImage = photoUrl;

      const updatedUser = await updateMe(updatePayload);
      const savedName = updatedUser?.name || fullName;
      const savedEmail = updatedUser?.email || emailInput?.value || getSession()?.email || '';
      const savedPhone = updatedUser?.phone || phone;

      const account = {
        ...(getAccount() || {}),
        name: savedName,
        fullName: savedName,
        email: savedEmail,
        phone: savedPhone,
      };
      delete account.city;
      localStorage.setItem('servio_account', JSON.stringify(account));

      if (currentSession) {
        currentSession.name = savedName;
        currentSession.email = savedEmail;
        if (photoUrl) currentSession.profileImage = photoUrl;
        localStorage.setItem('servio_session', JSON.stringify(currentSession));
      }
      if (_pendingPhotoUrl) _pendingPhotoUrl = null;

      document.getElementById('settings-fullname').value = savedName;
      if (emailInput) emailInput.value = savedEmail;
      document.getElementById('settings-phone').value = savedPhone;
      window.__servio_profile_email = savedEmail;
      snapshotProfileFields();
      setProfileEditMode(false);
      showToast(_t('toast_settings_saved') || 'Your changes have been saved.', 'success');
      savedProfile = true;
    } catch (err) {
      const msg = getErrorMessage(err, 'Failed to save settings.');
      showToast(msg, 'error');
    } finally {
      if (submitBtn) submitBtn.disabled = false;
    }
    if (savedProfile) {
      populateProfile();
      updateWelcomeText();
    }
    updateProfileCompleteness();
  });
}

/* ── Fix 3: Delete account button ──────────────────────── */
function initEmailChangeModal() {
  const modal = document.getElementById('modal-change-email');
  const openBtn = document.getElementById('btn-change-email');
  const closeBtn = document.getElementById('btn-close-change-email');
  const cancelBtn = document.getElementById('btn-change-email-cancel');
  const form = document.getElementById('change-email-form');
  const newEmailInput = document.getElementById('change-email-new');
  const passwordInput = document.getElementById('change-email-password');
  const submitBtn = document.getElementById('btn-change-email-confirm');
  const profileEmail = document.getElementById('settings-email');
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  if (!modal || !openBtn || !form) return;

  function setError(input, message) {
    if (!input) return;
    input.classList.add('is-invalid');
    input.classList.remove('is-valid');
    const host = input.closest('.form-field') || input.parentElement;
    let err = host?.querySelector('.field-error');
    if (!err && host) {
      err = document.createElement('p');
      err.className = 'field-error';
      host.appendChild(err);
    }
    if (err) {
      err.textContent = message;
      err.classList.add('is-visible');
    }
  }

  function clearError(input) {
    if (!input) return;
    input.classList.remove('is-invalid', 'is-valid');
    const host = input.closest('.form-field') || input.parentElement;
    const err = host?.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  function clearForm() {
    [newEmailInput, passwordInput].forEach(clearError);
    if (newEmailInput) newEmailInput.value = '';
    if (passwordInput) passwordInput.value = '';
  }

  function openModal() {
    clearForm();
    if (newEmailInput) {
      newEmailInput.placeholder = profileEmail?.value || 'new@email.com';
    }
    modal.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    newEmailInput?.focus();
  }

  function closeModal() {
    modal.setAttribute('hidden', '');
    document.body.style.overflow = '';
    clearForm();
  }

  openBtn.addEventListener('click', openModal);
  closeBtn?.addEventListener('click', closeModal);
  cancelBtn?.addEventListener('click', closeModal);
  modal.addEventListener('click', (event) => {
    if (event.target === modal) closeModal();
  });

  [newEmailInput, passwordInput].forEach(input => {
    input?.addEventListener('input', () => clearError(input));
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const newEmail = normalizeEmail(newEmailInput?.value);
    const currentPassword = passwordInput?.value || '';
    const currentEmail = normalizeEmail(profileEmail?.value || window.__servio_profile_email || getSession()?.email);

    let valid = true;
    if (!newEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) {
      setError(newEmailInput, _t('err_invalid_email') || 'Please enter a valid email address.');
      valid = false;
    } else if (newEmail === currentEmail) {
      setError(newEmailInput, _t('err_email_same') || 'New email must be different from your current email.');
      valid = false;
    }
    if (!currentPassword) {
      setError(passwordInput, _t('toast_email_current_pw_required') || 'Enter your current password to change your email address.');
      valid = false;
    }
    if (!valid) return;

    try {
      if (submitBtn) submitBtn.disabled = true;
      const result = await updateEmail({ newEmail, currentPassword });
      if (profileEmail && result?.email) profileEmail.value = result.email;
      showToast(_t('toast_email_updated_relogin') || 'Email updated. Please log in again with your new email.', 'success');
      closeModal();
      clearSession();
      setTimeout(() => {
        window.location.href = './login.html';
      }, 1200);
    } catch (err) {
      const msg = getErrorMessage(err, 'Failed to update email.');
      if (err.status === 409) setError(newEmailInput, msg);
      else if (err.status === 401) setError(passwordInput, msg);
      else if (Array.isArray(err?.data?.errors)) {
        err.data.errors.forEach(error => {
          if (error.field === 'newEmail') setError(newEmailInput, error.message);
          if (error.field === 'currentPassword') setError(passwordInput, error.message);
        });
      }
      showToast(msg, 'error');
    } finally {
      if (submitBtn) submitBtn.disabled = false;
    }
  });
}

function initDeleteAccount() {
  const btn = document.getElementById('btn-delete-account');
  if (!btn) return;
  btn.addEventListener('click', () => {
    showToast(typeof window.t === 'function' ? window.t('toast_delete_demo') : 'Account deletion is not available in demo mode.', 'info');
  });
}

/* ── Fix 6: Password field show/hide toggle ─────────────── */
function initPasswordToggles() {
  document.querySelectorAll('.btn-toggle-password').forEach(btn => {
    btn.addEventListener('click', () => {
      const wrap = btn.closest('.input-password-wrap');
      const input = wrap?.querySelector('input');
      if (!input) return;
      const isPassword = input.type === 'password';
      input.type = isPassword ? 'text' : 'password';
      btn.querySelector('.eye-icon--open').style.display = isPassword ? 'none' : '';
      btn.querySelector('.eye-icon--closed').style.display = isPassword ? '' : 'none';
      const showLabel = typeof window.t === 'function' ? window.t('pw_show') : 'Show password';
      const hideLabel = typeof window.t === 'function' ? window.t('pw_hide') : 'Hide password';
      btn.setAttribute('aria-label', isPassword ? hideLabel : showLabel);
    });
  });
}

/* ── Fix 7: Required field indicators & inline validation ── */
function initSettingsValidation() {
  const form = document.querySelector('#tab-settings form, .settings-form, [data-settings-form]');
  if (!form) return;

  function setError(input, message) {
    input.classList.add('is-invalid');
    input.classList.remove('is-valid');
    let err = input.parentElement.querySelector('.field-error');
    if (!err) { err = document.createElement('p'); err.className = 'field-error'; input.parentElement.appendChild(err); }
    err.textContent = message;
    err.classList.add('is-visible');
  }

  function clearError(input) {
    input.classList.remove('is-invalid');
    let err = input.parentElement.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  function setValid(input) {
    input.classList.remove('is-invalid');
    input.classList.add('is-valid');
    let err = input.parentElement.querySelector('.field-error');
    if (err) err.classList.remove('is-visible');
  }

  // Clear on input
  form.querySelectorAll('input').forEach(input => {
    input.addEventListener('input', () => clearError(input));
  });

  /* Required fields on submit are handled in initSettingsForm (toast + return). */
}

/* ── Logout ─────────────────────────────────────────────── */
function initDashLogout() {
  const btn = document.querySelector('[data-dash-logout]');
  if (!btn) return;
  btn.addEventListener('click', () => {
    try {
      localStorage.removeItem('servio_session');
      localStorage.removeItem('servio_notifications');
      localStorage.removeItem('servio_booking_snapshot');
    } catch (_) { /* ignore */ }
    window.location.href = './login.html?redirect=' + encodeURIComponent(window.location.pathname + window.location.search);
  });
}

/* ── Booking filter & sort ─────────────────────────────── */
function applyBookingFilter() {
  const activeBtn = document.querySelector('[data-booking-filter].is-active');
  const filter = activeBtn?.dataset.bookingFilter || 'all';
  document.querySelectorAll('[data-booking-group]').forEach(group => {
    let any = false;
    group.querySelectorAll('[data-booking-card]').forEach(card => {
      const st = card.dataset.bookingStatus;
      const show = filter === 'all' || st === filter;
      card.hidden = !show;
      if (show) any = true;
    });
    group.hidden = !any;
    // Also toggle the section title preceding the group
    const title = group.previousElementSibling;
    if (title && title.classList.contains('dash-section-title')) {
      title.hidden = !any;
    }
  });
}

function sortBookingCards() {
  const select = document.querySelector('[data-booking-sort]');
  if (!select) return;
  const mode = select.value;
  const order = { active: 0, pending: 1, completed: 2 };
  document.querySelectorAll('[data-booking-group] .booking-group__cards').forEach(container => {
    const cards = Array.from(container.querySelectorAll('[data-booking-card]'));
    cards.sort((a, b) => {
      const da = new Date(a.dataset.bookingDate || 0).getTime();
      const db = new Date(b.dataset.bookingDate || 0).getTime();
      if (mode === 'date-asc') return da - db;
      if (mode === 'date-desc') return db - da;
      if (mode === 'status') return (order[a.dataset.bookingStatus] ?? 9) - (order[b.dataset.bookingStatus] ?? 9);
      return da - db;
    });
    cards.forEach(c => container.appendChild(c));
  });
}

function initBookingFilter() {
  const filterBtns = document.querySelectorAll('[data-booking-filter]');
  if (!filterBtns.length) return;
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('is-active'));
      btn.classList.add('is-active');
      applyBookingFilter();
    });
  });
  const sortSel = document.querySelector('[data-booking-sort]');
  sortSel?.addEventListener('change', () => sortBookingCards());
  applyBookingFilter();
  window.applyBookingFilter = applyBookingFilter;
}

/* ── History: expand, date range, sort ─────────────────── */
/* ── History: Filters & Invoices ────────────────────────── */
function initHistoryPanel() {
  const filterRoot = document.getElementById('historyListRoot');
  const filters = document.querySelectorAll('[data-hist-filter]');
  const clearBtn = document.getElementById('clearHistFilters');

  function applyHistoryFilters() {
    if (!filterRoot) return;
    const cards = filterRoot.querySelectorAll('.history-card-v2');
    const vals = {};
    filters.forEach(f => { vals[f.dataset.histFilter] = f.value; });

    const now = Date.now();

    cards.forEach(card => {
      // Date-based timeframe logic
      let dateMatch = true;
      if (vals.date) {
        const cardTs = new Date(card.dataset.date || 0).getTime();
        const daysAgo = parseInt(vals.date, 10);
        dateMatch = cardTs >= (now - (daysAgo * 24 * 60 * 60 * 1000));
      }

      const match =
        (!vals.category || card.dataset.category === vals.category) &&
        (!vals.payment  || card.dataset.payment  === vals.payment)  &&
        (!vals.rating   || parseInt(card.dataset.rating || 0) >= parseInt(vals.rating)) &&
        dateMatch;

      card.classList.toggle('is-hidden', !match);
    });
  }

  filters.forEach(f => f.addEventListener('change', applyHistoryFilters));
  clearBtn?.addEventListener('click', () => {
    filters.forEach(f => { f.value = ''; });
    applyHistoryFilters();
  });

  // Localize history cards (Price, Currency, Payment Badge, Date)
  function localizeHistoryCards() {
    const _t = typeof window.t === 'function' ? window.t : (k) => k;
    const lang = localStorage.getItem('servio_lang') || 'en';

    document.querySelectorAll('.history-card-v2').forEach(card => {
      // 1. Payment Badge - map data-payment to i18n key
      const badge = card.querySelector('.history-v2__payment-badge');
      if (badge) {
        const payVal = card.dataset.payment; 
        const payKey = payVal === 'Credit Card' ? 'cust_pay_card' : (payVal === 'Cash' ? 'cust_pay_cash' : null);
        if (payKey) badge.textContent = _t(payKey);
      }

      // 2. Price/Currency - parse value and localize
      const priceEl = card.querySelector('.history-v2__price');
      if (priceEl) {
        const raw = priceEl.textContent.replace(/[^\d.,]/g, '').trim();
        if (lang === 'ar') {
           priceEl.textContent = `${raw} ${_t('currency_egp')}`;
        } else {
           priceEl.textContent = `${raw} EGP`;
        }
      }

      // 3. Date translation
      const dateEl = card.querySelector('.history-v2__provider .dot-sep + span');
      if (dateEl) {
        if (!dateEl.dataset.origText) dateEl.dataset.origText = dateEl.textContent;
        dateEl.textContent = translateDateTime(dateEl.dataset.origText);
      }
    });
  }

  localizeHistoryCards();
  document.addEventListener('langchange', localizeHistoryCards);

  // Invoice toggles (History & Bookings)
  document.querySelectorAll('[data-invoice-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
       const card = btn.closest('.history-card-v2, .booking-card');
       if (!card) return;
       const _t = typeof window.t === 'function' ? window.t : (k) => k;
       if (card.classList.contains('history-card-v2')) {
         const isExpanded = card.classList.toggle('is-expanded');
         btn.textContent = isExpanded ? _t('cust_hide_invoice') : _t('cust_view_invoice');
       } else {
         // For Booking Cards: toggle the .is-open class for smooth transition
         const panel = card.querySelector('.booking-card__invoice-panel');
         if (panel) {
           const isOpen = panel.classList.toggle('is-open');
           btn.textContent = isOpen ? _t('cust_hide_invoice') : _t('cust_view_invoice');
         }
       }
    });
  });
}

/* ── Favourites: filter, reorder, remove ───────────────── */
function initFavouritesPanel() {
  const grid = document.querySelector('[data-fav-list]');
  document.querySelectorAll('[data-fav-filter]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('[data-fav-filter]').forEach(b => b.classList.remove('is-active'));
      btn.classList.add('is-active');
      const cat = btn.dataset.favFilter;
      document.querySelectorAll('[data-fav-card]').forEach(card => {
        const c = card.dataset.favCategory || '';
        card.hidden = cat !== 'all' && c !== cat;
      });
    });
  });

  grid?.querySelectorAll('[data-fav-up]').forEach(btn => {
    btn.addEventListener('click', () => {
      const card = btn.closest('[data-fav-card]');
      const prev = card?.previousElementSibling;
      if (card && prev?.matches?.('[data-fav-card]')) grid.insertBefore(card, prev);
    });
  });
  grid?.querySelectorAll('[data-fav-down]').forEach(btn => {
    btn.addEventListener('click', () => {
      const card = btn.closest('[data-fav-card]');
      const next = card?.nextElementSibling;
      if (card && next?.matches?.('[data-fav-card]')) grid.insertBefore(next, card);
    });
  });

  grid?.querySelectorAll('[data-fav-remove]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      if (!confirm(_t('confirm_remove_fav'))) return;
      const card = btn.closest('[data-fav-card]');
      card?.remove();
      showToast(_t('toast_removed_fav'), 'info');
    });
  });
}

/* ── Notifications: quick actions & prefs ──────────────── */
function initNotificationActions() {
  const tabHandlers = {
    'view-bookings': 'bookings',
    'open-settings': 'settings',
  };
  document.querySelectorAll('[data-notif-action]').forEach(btn => {
    btn.addEventListener('click', () => {
      const action = btn.dataset.notifAction;
      const tab = tabHandlers[action];
      if (tab) {
        document.querySelector(`[data-tab="${tab}"]`)?.click();
        return;
      }
      const messages = {
        reschedule: 'Opening reschedule flow (demo)…',
        'cancel-booking': 'Cancel from the Bookings tab to confirm.',
        confirm: 'Slot confirmed (demo).',
        message: 'Messaging opens in a full release.',
      };
      showToast(messages[action] || 'Action recorded (demo).', 'info');
    });
  });

  document.querySelectorAll('[data-notif-pref]').forEach(cb => {
    cb.addEventListener('change', () => {
      showToast('Preference saved for this session (demo).', 'success');
    });
  });
}

/* ── Sidebar toggle (click to expand/collapse) ──────────── */
/* ── Init ───────────────────────────────────────────────── */
populateProfile();
loadBookingsData();
let _custPollInterval = null;
const startCustPolling = () => {
  if (_custPollInterval) clearInterval(_custPollInterval);
  _custPollInterval = setInterval(() => loadBookingsData(), 30000);
};
const stopCustPolling = () => { if (_custPollInterval) clearInterval(_custPollInterval); _custPollInterval = null; };
startCustPolling();
document.addEventListener('visibilitychange', () => { document.hidden ? stopCustPolling() : startCustPolling(); });
populateStats();
updateWelcomeText();

initTabs();
initBookingSubTabs();
initHistoryPanel();
initFavouritesPanel();
initNotificationActions();
initNotifications();
initSettingsForm();
initEmailChangeModal();
initDeleteAccount();
initPasswordToggles();
initSettingsValidation();
initSettingsTabs();
initSecurityForm();
initOtpField();
initPasswordStrength();
initSettingToggles();
initLanguageCards();
initThemeCards();
initAddressTab();
initAccountTab();
initDashLogout();

/* ── Bookings sub-tab switching ─────────────────────────── */
function initBookingSubTabs() {
  const bar = document.getElementById('bookings-stab-bar');
  if (!bar) return;
  bar.addEventListener('click', (e) => {
    const btn = e.target.closest('.stab-btn');
    if (!btn) return;
    const target = btn.dataset.stab;
    bar.querySelectorAll('.stab-btn').forEach(b => {
      b.classList.toggle('stab-btn--active', b === btn);
      b.setAttribute('aria-selected', b === btn ? 'true' : 'false');
    });
    document.querySelectorAll('#panel-bookings .stab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
  });
}

function _restoreSubTab(stabValue) {
  const bar = document.getElementById('bookings-stab-bar');
  if (!bar || !stabValue) return;
  const btn = bar.querySelector(`[data-stab="${stabValue}"]`);
  if (!btn) return;
  bar.querySelectorAll('.stab-btn').forEach(b => {
    b.classList.toggle('stab-btn--active', b === btn);
    b.setAttribute('aria-selected', b === btn ? 'true' : 'false');
  });
  document.querySelectorAll('#panel-bookings .stab-pane').forEach(p => {
    const isTarget = p.id === 'stab-' + stabValue;
    p.classList.toggle('stab-pane--active', isTarget);
    if (isTarget) p.removeAttribute('hidden');
    else p.setAttribute('hidden', '');
  });
}

/* ── Settings horizontal tab switching ─────────────────── */
function initSettingsTabs() {
  const bar = document.getElementById('settings-tab-bar');
  if (!bar) return;
  bar.addEventListener('click', (e) => {
    const btn = e.target.closest('.stab-btn');
    if (!btn) return;
    const target = btn.dataset.stab;
    bar.querySelectorAll('.stab-btn').forEach(b => {
      b.classList.toggle('stab-btn--active', b === btn);
      b.setAttribute('aria-selected', b === btn ? 'true' : 'false');
    });
    document.querySelectorAll('#panel-settings .stab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
    if (target === 'profile') updateProfileCompleteness();
  });
  // Run once on load so the bar shows the correct percentage immediately
  updateProfileCompleteness();

  let _pmInitialized = false;
  document.getElementById('stab-btn-payment-methods')?.addEventListener('click', () => {
    if (!_pmInitialized) {
      _pmInitialized = true;
      initPaymentMethods();
    }
  });
}

/* ── Security form — Change Password ─────────────────────── */
function initSecurityForm() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  // Eye-toggle for all password fields in this form
  document.querySelectorAll('#change-password-form .btn-toggle-password').forEach(btn => {
    btn.addEventListener('click', () => {
      const wrap = btn.closest('.input-password-wrap');
      const input = wrap?.querySelector('input');
      if (!input) return;
      const show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      btn.querySelector('.eye-icon--show').style.display = show ? 'none' : '';
      btn.querySelector('.eye-icon--hide').style.display = show ? '' : 'none';
    });
  });

  // Strength segments + requirements checklist
  const newPwInput   = document.getElementById('cp-new');
  const strengthLabel = document.getElementById('cp-strength-label');
  const segs = [1,2,3,4].map(i => document.getElementById(`cp-seg-${i}`));
  const COLORS = ['#ef4444', '#f97316', '#eab308', '#22c55e'];
  const LABELS = ['Weak', 'Fair', 'Good', 'Strong'];

  const REQS = {
    'req-len':     v => v.length >= 8,
    'req-upper':   v => /[A-Z]/.test(v),
    'req-num':     v => /[0-9]/.test(v),
    'req-special': v => /[^A-Za-z0-9]/.test(v),
  };

  function updateStrength(val) {
    let score = 0;
    Object.entries(REQS).forEach(([id, test]) => {
      const met = test(val);
      if (met) score++;
      const el = document.getElementById(id);
      if (el) el.classList.toggle('met', met);
    });

    const color = val ? (COLORS[score - 1] || COLORS[0]) : 'var(--color-border)';
    segs.forEach((seg, i) => {
      if (!seg) return;
      const active = val && i < score;
      seg.classList.toggle('active', active);
      seg.style.setProperty('--pw-seg-color', color);
    });

    if (strengthLabel) {
      strengthLabel.textContent = val ? (LABELS[score - 1] || LABELS[0]) : 'Enter a password';
      strengthLabel.style.color = val ? color : '';
    }
  }

  if (newPwInput) {
    newPwInput.addEventListener('input', () => updateStrength(newPwInput.value));
  }

  const form      = document.getElementById('change-password-form');
  const errEl     = document.getElementById('cp-error');
  const submitBtn = document.getElementById('cp-submit');

  if (!form) return;

  form.addEventListener('reset', () => {
    // Reset strength UI on Clear button click
    setTimeout(() => updateStrength(''), 0);
  });

  form.addEventListener('submit', async e => {
    e.preventDefault();
    if (errEl) errEl.hidden = true;

    const currentPw = document.getElementById('cp-current')?.value?.trim() || '';
    const newPw     = document.getElementById('cp-new')?.value             || '';
    const confirmPw = document.getElementById('cp-confirm')?.value         || '';

    if (!currentPw || !newPw || !confirmPw) {
      if (errEl) { errEl.textContent = 'Please fill in all password fields.'; errEl.hidden = false; }
      return;
    }
    if (newPw.length < 8) {
      if (errEl) { errEl.textContent = 'New password must be at least 8 characters.'; errEl.hidden = false; }
      return;
    }
    if (!/[0-9]/.test(newPw)) {
      if (errEl) { errEl.textContent = 'New password must contain at least one number.'; errEl.hidden = false; }
      return;
    }
    if (!/[^A-Za-z0-9]/.test(newPw)) {
      if (errEl) { errEl.textContent = 'New password must contain at least one special character.'; errEl.hidden = false; }
      return;
    }
    if (newPw === currentPw) {
      if (errEl) { errEl.textContent = 'New password must be different from your current password.'; errEl.hidden = false; }
      return;
    }
    if (newPw !== confirmPw) {
      if (errEl) { errEl.textContent = 'New passwords do not match.'; errEl.hidden = false; }
      return;
    }

    try {
      if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = 'Updating…'; }
      await updatePassword({ currentPassword: currentPw, newPassword: newPw });
      showToast(_t('toast_password_changed') || 'Password updated. Please sign in again.', 'success');
      form.reset();
      updateStrength('');
      setTimeout(() => {
        localStorage.removeItem('servio_token');
        localStorage.removeItem('servio_session');
        window.location.href = './login.html';
      }, 1500);
    } catch (err) {
      const msg = err?.data?.message || err?.message || 'Failed to update password. Check your current password and try again.';
      if (errEl) { errEl.textContent = msg; errEl.hidden = false; }
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = 'Update Password'; }
    }
  });
}

/* ── OTP field visibility (show when phone changes in edit mode) ─ */
function initOtpField() {
  const phoneInput = document.getElementById('settings-phone');
  const otpWrap    = document.getElementById('otp-field-wrap');
  const sendOtpBtn = document.getElementById('btn-send-otp');
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  if (!phoneInput || !otpWrap) return;

  let originalPhone = phoneInput.value;

  // Show OTP field when the phone value changes during editing
  phoneInput.addEventListener('input', () => {
    const changed = phoneInput.value.trim() !== originalPhone.trim();
    otpWrap.hidden = !changed;
  });

  // Re-snapshot original when edit mode is activated
  document.getElementById('btn-profile-edit')?.addEventListener('click', () => {
    originalPhone = phoneInput.value;
    otpWrap.hidden = true;
    if (document.getElementById('settings-phone-otp')) {
      document.getElementById('settings-phone-otp').value = '';
    }
  });

  // Cancel restores original, hides OTP
  document.getElementById('btn-profile-cancel')?.addEventListener('click', () => {
    otpWrap.hidden = true;
    if (document.getElementById('settings-phone-otp')) {
      document.getElementById('settings-phone-otp').value = '';
    }
  });

  if (!sendOtpBtn) return;
  sendOtpBtn.addEventListener('click', () => {
    const phone = phoneInput.value.trim();
    if (!/^[+]?[\d\s\-().]{7,20}$/.test(phone)) {
      showToast('Please enter a valid phone number first.', 'error');
      return;
    }
    // Simulate sending OTP (wire to backend when endpoint is available)
    showToast(_t('toast_otp_sent') || `Verification code sent to ${phone}`, 'success');
    sendOtpBtn.disabled = true;
    let sec = 60;
    sendOtpBtn.textContent = `Resend in ${sec}s`;
    const interval = setInterval(() => {
      sec--;
      sendOtpBtn.textContent = sec > 0 ? `Resend in ${sec}s` : 'Send Code';
      if (sec <= 0) { clearInterval(interval); sendOtpBtn.disabled = false; }
    }, 1000);
  });
}

/* ── Password strength meter + live checklist ────────────── */
function initPasswordStrength() {
  // Handled inside initSecurityForm for the change-password form.
}

/* ── Profile completeness bar ────────────────────────────── */
function updateProfileCompleteness() {
  const account = getAccount ? getAccount() : null;
  const fields = ['fullName', 'email', 'phone'];
  const filled = fields.filter(f => account && account[f] && account[f].trim()).length;
  const avatar = document.querySelector('.settings-avatar-preview img');
  const total  = fields.length + 1; // +1 for photo
  const score  = Math.round(((filled + (avatar ? 1 : 0)) / total) * 100);
  const pct = document.getElementById('profile-complete-pct');
  const bar = document.getElementById('profile-complete-bar');
  const fill = document.getElementById('profile-complete-fill');
  if (pct) pct.textContent = score + '%';
  if (bar) bar.setAttribute('aria-valuenow', score);
  if (fill) fill.style.width = score + '%';
}

/* ── Settings toggles (notifications, 2FA) ──────────────── */
function initSettingToggles() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const prefs = JSON.parse(localStorage.getItem('servio_notif_prefs') || '{}');

  document.querySelectorAll('.stab-toggle[data-pref]').forEach(btn => {
    const key = btn.dataset.pref;
    // Restore saved state (if we have it, otherwise keep HTML default)
    if (key in prefs) {
      const on = prefs[key];
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
    }
    btn.addEventListener('click', () => {
      const on = btn.getAttribute('aria-checked') !== 'true';
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
      prefs[key] = on;
      localStorage.setItem('servio_notif_prefs', JSON.stringify(prefs));
      showToast(_t('toast_notif_saved'), 'success');
    });
  });
}

/* ── Language cards ─────────────────────────────────────── */
function initLanguageCards() {
  const cards = document.getElementById('lang-cards');
  if (!cards) return;

  function syncCards() {
    const current = localStorage.getItem('servio_lang') || 'en';
    cards.querySelectorAll('.lang-card').forEach(c => {
      const active = c.dataset.lang === current;
      c.setAttribute('aria-checked', active ? 'true' : 'false');
    });
  }
  syncCards();

  cards.addEventListener('click', (e) => {
    const card = e.target.closest('.lang-card');
    if (!card) return;
    const lang = card.dataset.lang;
    // Trigger the existing lang.js switch
    const switcher = document.querySelector('[data-lang-switcher], [data-lang-switch]');
    if (switcher) {
      switcher.value = lang;
      switcher.dispatchEvent(new Event('change'));
    } else if (typeof window.setLang === 'function') {
      window.setLang(lang);
    } else {
      localStorage.setItem('servio_lang', lang);
      location.reload();
    }
    syncCards();
  });

  document.addEventListener('langchange', syncCards);
}

/* ── Theme cards ─────────────────────────────────────────── */
function initThemeCards() {
  const cards = document.getElementById('theme-cards');
  if (!cards) return;

  function syncCards() {
    const current = localStorage.getItem('servio_theme') || 'system';
    cards.querySelectorAll('.theme-card').forEach(c => {
      const active = c.dataset.themeChoice === current;
      c.setAttribute('aria-checked', active ? 'true' : 'false');
    });
  }
  syncCards();

  cards.addEventListener('click', (e) => {
    const card = e.target.closest('.theme-card');
    if (!card) return;
    const choice = card.dataset.themeChoice;
    localStorage.setItem('servio_theme', choice);

    let apply = choice;
    if (choice === 'system') {
      apply = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    document.documentElement.setAttribute('data-theme', apply);
    // Also try the existing dashboard toggle if present
    const toggle = document.querySelector('[data-theme-toggle]');
    if (toggle) toggle.checked = apply === 'dark';
    syncCards();
  });
}

/* ── Addresses tab ──────────────────────────────────────── */
function renderAddressList() {
  const list = document.getElementById('addr-list');
  if (!list) return;
  const addresses = window.__servio_user_addresses || [];
  if (addresses.length === 0) {
    list.innerHTML = '<p class="settings-section__desc" style="margin:0">No saved addresses yet. Add one below.</p>';
    return;
  }
  list.innerHTML = addresses.map(addr => {
    const full = [addr.street, addr.city, addr.state].filter(Boolean).join(', ');
    return `
      <div class="addr-card" data-addr-id="${addr._id}">
        <div class="addr-card__icon">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
        </div>
        <div class="addr-card__body">
          <span class="addr-card__type">${addr.label || 'Address'}</span>
          <span class="addr-card__value">${full || '—'}</span>
        </div>
        <button type="button" class="btn-addr-edit" data-addr-id="${addr._id}" aria-label="Edit address">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
          <span>Edit</span>
        </button>
        <button type="button" class="btn-addr-delete" data-addr-id="${addr._id}" aria-label="Delete address" style="margin-left:4px;background:none;border:none;cursor:pointer;color:var(--color-error,#e53);">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
        </button>
      </div>`;
  }).join('');

  // Wire edit buttons
  list.querySelectorAll('.btn-addr-edit').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.addrId;
      const addr = (window.__servio_user_addresses || []).find(a => a._id === id);
      if (addr) openAddressForm(addr);
    });
  });

  // Wire delete buttons
  list.querySelectorAll('.btn-addr-delete').forEach(btn => {
    btn.addEventListener('click', async () => {
      const id = btn.dataset.addrId;
      if (!confirm('Delete this address?')) return;
      try {
        await deleteAddress(id);
        window.__servio_user_addresses = (window.__servio_user_addresses || []).filter(a => a._id !== id);
        renderAddressList();
        showToast('Address deleted.', 'success');
      } catch (err) {
        showToast(err.response?.data?.message || 'Failed to delete address', 'error');
      }
    });
  });
}

let _editingAddrId = null;

function openAddressForm(addr) {
  const formWrap = document.getElementById('addr-form-wrap');
  const btnAdd   = document.getElementById('btn-addr-add');
  const formTitle = document.getElementById('addr-form-title');
  if (!formWrap) return;
  _editingAddrId = addr ? addr._id : null;
  if (formTitle) formTitle.textContent = addr ? 'Edit Address' : 'Add Address';
  document.getElementById('addr-input-label').value    = addr?.label   || '';
  document.getElementById('addr-input-street').value   = addr?.street  || '';
  document.getElementById('addr-input-district').value = addr?.state   || '';
  document.getElementById('addr-input-city').value     = addr?.city    || '';
  formWrap.removeAttribute('hidden');
  if (btnAdd) btnAdd.setAttribute('hidden', '');
  document.getElementById('addr-input-street').focus();
}

function initAddressTab() {
  const formWrap  = document.getElementById('addr-form-wrap');
  const btnAdd    = document.getElementById('btn-addr-add');
  const btnCancel = document.getElementById('btn-addr-cancel');
  const btnSave   = document.getElementById('btn-addr-save');
  if (!formWrap) return;

  function closeForm() {
    formWrap.setAttribute('hidden', '');
    if (btnAdd) btnAdd.removeAttribute('hidden');
    _editingAddrId = null;
  }

  btnAdd?.addEventListener('click', () => openAddressForm(null));
  btnCancel?.addEventListener('click', closeForm);

  btnSave?.addEventListener('click', async () => {
    const label  = document.getElementById('addr-input-label').value.trim();
    const street = document.getElementById('addr-input-street').value.trim();
    const state  = document.getElementById('addr-input-district').value.trim();
    const city   = document.getElementById('addr-input-city').value.trim();
    if (!street) { document.getElementById('addr-input-street').focus(); return; }

    try {
      if (_editingAddrId) {
        const updated = await updateAddress(_editingAddrId, { label, street, city, state });
        window.__servio_user_addresses = (window.__servio_user_addresses || []).map(
          a => a._id === _editingAddrId ? updated : a
        );
      } else {
        const created = await addAddress({ label, street, city, state });
        window.__servio_user_addresses = [...(window.__servio_user_addresses || []), created];
      }
      renderAddressList();
      closeForm();
      showToast('Address saved.', 'success');
    } catch (err) {
      console.error('Failed to save address:', err);
      showToast(err.response?.data?.message || err.message || 'Failed to save address', 'error');
    }
  });
}

/* ── Account tab (export / deactivate / delete) ─────────── */
function initAccountTab() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  /* ── Export data ── */
  document.getElementById('btn-export-data')?.addEventListener('click', () => {
    showToast(_t('toast_export_demo'), 'info');
  });

  /* ── Deactivate modal ── */
  const modalDeactivate  = document.getElementById('modal-deactivate');
  const checkDeactivate  = document.getElementById('deactivate-confirm-check');
  const btnDeactivateOk  = document.getElementById('btn-deactivate-confirm');

  function openDeactivateModal() {
    if (!modalDeactivate) return;
    checkDeactivate.checked = false;
    btnDeactivateOk.disabled = true;
    modalDeactivate.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    checkDeactivate.focus();
  }
  function closeDeactivateModal() {
    modalDeactivate?.setAttribute('hidden', '');
    document.body.style.overflow = '';
  }

  document.getElementById('btn-deactivate-account')?.addEventListener('click', openDeactivateModal);
  document.getElementById('btn-close-deactivate')?.addEventListener('click', closeDeactivateModal);
  document.getElementById('btn-deactivate-cancel')?.addEventListener('click', closeDeactivateModal);

  checkDeactivate?.addEventListener('change', () => {
    btnDeactivateOk.disabled = !checkDeactivate.checked;
  });

  btnDeactivateOk?.addEventListener('click', () => {
    closeDeactivateModal();
    showToast(_t('toast_deactivate_demo'), 'info');
  });

  /* ── Delete modal ── */
  const modalDelete   = document.getElementById('modal-delete');
  const inputDelete   = document.getElementById('delete-confirm-input');
  const btnDeleteOk   = document.getElementById('btn-delete-confirm');
  const CONFIRM_WORD  = 'DELETE';

  function openDeleteModal() {
    if (!modalDelete) return;
    inputDelete.value = '';
    inputDelete.classList.remove('is-valid');
    btnDeleteOk.disabled = true;
    modalDelete.removeAttribute('hidden');
    document.body.style.overflow = 'hidden';
    inputDelete.focus();
  }
  function closeDeleteModal() {
    modalDelete?.setAttribute('hidden', '');
    document.body.style.overflow = '';
  }

  // Override the existing btn-delete-account click (initDeleteAccount set a toast, we replace it)
  const btnDeleteAcct = document.getElementById('btn-delete-account');
  if (btnDeleteAcct) {
    // Clone to remove the old listener added by initDeleteAccount
    const fresh = btnDeleteAcct.cloneNode(true);
    btnDeleteAcct.parentNode.replaceChild(fresh, btnDeleteAcct);
    fresh.addEventListener('click', openDeleteModal);
  }

  document.getElementById('btn-close-delete')?.addEventListener('click', closeDeleteModal);
  document.getElementById('btn-delete-cancel')?.addEventListener('click', closeDeleteModal);

  inputDelete?.addEventListener('input', () => {
    const match = inputDelete.value === CONFIRM_WORD;
    inputDelete.classList.toggle('is-valid', match);
    btnDeleteOk.disabled = !match;
  });

  btnDeleteOk?.addEventListener('click', async () => {
    btnDeleteOk.disabled = true;
    try {
      await deleteMe();
      closeDeleteModal();
      showToast(_t('toast_delete_success') || 'Account deleted successfully.', 'success');
      setTimeout(() => {
        localStorage.removeItem('servio_token');
        localStorage.removeItem('servio_session');
        window.location.href = 'index.html';
      }, 1500);
    } catch (error) {
      btnDeleteOk.disabled = false;
      showToast(error.response?.data?.message || error.message || 'Failed to delete account.', 'error');
    }
  });

  /* ── Close on backdrop click ── */
  [modalDeactivate, modalDelete].forEach(modal => {
    modal?.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal === modalDeactivate ? closeDeactivateModal() : closeDeleteModal();
      }
    });
  });

  /* ── Close on Escape ── */
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (modalDeactivate && !modalDeactivate.hidden) closeDeactivateModal();
    if (modalDelete     && !modalDelete.hidden)     closeDeleteModal();
  });
}

/* ── Date/Time Translation ────────────────────────────── */
function translateDateTime(str) {
  if (!str) return '';
  const lang = localStorage.getItem('servio_lang') || 'en';
  if (lang !== 'ar') return str;

  const monthsMap = {
    'Jan': 'يناير', 'Feb': 'فبراير', 'Mar': 'مارس', 'Apr': 'أبريل',
    'May': 'مايو', 'Jun': 'يونيو', 'Jul': 'يوليو', 'Aug': 'أغسطس',
    'Sep': 'سبتمبر', 'Oct': 'أكتوبر', 'Nov': 'نوفمبر', 'Dec': 'ديسمبر',
    'January': 'يناير', 'February': 'فبراير', 'March': 'مارس', 'April': 'أبريل',
    'June': 'يونيو', 'July': 'يوليو', 'August': 'أغسطس',
    'September': 'سبتمبر', 'October': 'أكتوبر', 'November': 'نوفمبر', 'December': 'ديسمبر',
    'Sun': 'الأحد', 'Mon': 'الاثنين', 'Tue': 'الثلاثاء', 'Wed': 'الأربعاء', 'Thu': 'الخميس', 'Fri': 'الجمعة', 'Sat': 'السبت'
  };

  const ampmMap = {
    'AM': 'صباحاً',
    'PM': 'مساءً'
  };

  let res = str;
  Object.keys(monthsMap).forEach(k => { res = res.replace(new RegExp('\\b' + k + '\\b', 'g'), monthsMap[k]); });
  Object.keys(ampmMap).forEach(k => { res = res.replace(new RegExp('\\b' + k + '\\b', 'g'), ampmMap[k]); });
  return res;
}

/* ── Live language switch ────────────────────────────────── */
function refreshDynamicText() {
  updateWelcomeText();
  const welcomeEl = document.querySelector('[data-dash-welcome]');
  if (welcomeEl) {
    welcomeEl.textContent = typeof window.t === 'function' ? window.t('cust_welcome_sub_text') : 'Your overview';
    welcomeEl.removeAttribute('data-i18n');
  }

  // Translate hours in schedule cards
  document.querySelectorAll('.dash-next-appt__hour, .dash-schedule-item__hour').forEach(el => {
    // Store original if not stored
    if (!el.dataset.origText) el.dataset.origText = el.textContent;
    el.textContent = translateDateTime(el.dataset.origText);
  });

  // Translate Job counts in Favourites
  document.querySelectorAll('.fav-card-v2__jobs-count').forEach(el => {
    if (!el.dataset.origText) el.dataset.origText = el.textContent;
    const countMatch = el.dataset.origText.match(/\d+/);
    if (countMatch && typeof window.t === 'function') {
      el.textContent = window.t('cust_fav_jobs_n', { n: countMatch[0] });
    }
  });
}

/* On every language switch (fired by lang.js after it calls applyLanguage) */
document.addEventListener('langchange', refreshDynamicText);

/* On initial load: lang.js fires langchange on DOMContentLoaded */
document.addEventListener('DOMContentLoaded', refreshDynamicText, { once: true });

/* ═══════════════════════════════════════════════
   PHASE 2 ADDITIONS
   ═══════════════════════════════════════════════ */

(function initPhase2Customer() {
  // ── Post Job modal ─────────────────────────
  document.getElementById('postJobBtn')?.addEventListener('click', () => {
    document.getElementById('postJobModal').hidden = false;
  });
  document.getElementById('closePostJobModal')?.addEventListener('click', () => {
    document.getElementById('postJobModal').hidden = true;
  });
  document.getElementById('cancelPostJob')?.addEventListener('click', () => {
    document.getElementById('postJobModal').hidden = true;
  });

  document.getElementById('postJobForm')?.addEventListener('submit', e => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const job = {
      category: fd.get('category'), title: fd.get('title'),
      description: fd.get('description'), location: fd.get('location'),
      dateFrom: fd.get('dateFrom'), dateTo: fd.get('dateTo'),
      budgetMin: fd.get('budgetMin'), budgetMax: fd.get('budgetMax'),
      paymentPref: fd.get('paymentPref'),
      postedAt: new Date().toISOString(), status: 'open',
    };
    const posts = JSON.parse(localStorage.getItem('servio_job_posts') || '[]');
    posts.push(job);
    localStorage.setItem('servio_job_posts', JSON.stringify(posts));
    document.getElementById('postJobModal').hidden = true;
    e.target.reset();
    const _msg = typeof window.t === 'function' ? window.t('toast_job_posted') : 'Job posted successfully!';
    showToast?.(_msg, 'success') || alert(_msg);
  });

  // ── View Proposals — switch tab ────────────
  document.querySelectorAll('[data-view-proposals]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelector('[data-tab="proposals"]')?.click();
    });
  });

  // ── Close Job ─────────────────────────────
  document.querySelectorAll('[data-close-job]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      if (confirm(_t('confirm_close_job'))) {
        const card = btn.closest('.job-post-card');
        const openBadge = card?.querySelector('.jpc-badge--open');
        if (openBadge) {
          openBadge.textContent = _t('status_closed') || 'Closed';
          openBadge.className = 'jpc-badge jpc-badge--closed';
        }
        showToast?.(_t('toast_job_closed'), 'info');
      }
    });
  });

  // ── Accept Proposal — open payment modal ──
  let pendingProposal = null;
  document.querySelectorAll('[data-accept-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      pendingProposal = { tech: btn.dataset.tech, price: parseFloat(btn.dataset.price) };
      document.getElementById('bookingSummaryBlock').hidden = true;
      document.getElementById('proceedPaymentBtn').hidden   = false;
      document.getElementById('paymentModal').hidden = false;
    });
  });
  document.getElementById('closePaymentModal')?.addEventListener('click', () => {
    document.getElementById('paymentModal').hidden = true;
  });

  document.getElementById('proceedPaymentBtn')?.addEventListener('click', () => {
    if (!pendingProposal) return;
    const _t = typeof window.t === 'function' ? window.t : (k) => k;
    const method = document.querySelector('[name="paymentMethod"]:checked')?.value || 'online';
    const labels = {
      online: _t('booking_online_payment'),
      cash: _t('booking_cash'),
    };
    document.getElementById('summaryTech').textContent    = `${_t('cust_lbl_technician')}: ${pendingProposal.tech}`;
    document.getElementById('summaryPrice').textContent   = `${_t('cust_lbl_amount')}: ${pendingProposal.price} EGP`;
    document.getElementById('summaryPayment').textContent = `${_t('cust_lbl_payment_method')}: ${labels[method]}`;
    document.getElementById('bookingSummaryBlock').hidden = false;
    document.getElementById('proceedPaymentBtn').hidden   = true;
  });

  document.getElementById('confirmBookingBtn')?.addEventListener('click', () => {
    const booking = {
      id: 'S-' + Date.now(),
      tech: pendingProposal?.tech || 'Technician',
      price: pendingProposal?.price || 0,
      payment: document.querySelector('[name="paymentMethod"]:checked')?.value || 'online',
      pin: null, status: 'Booked', timestamp: Date.now(),
    };
    localStorage.setItem('servio_active_booking', JSON.stringify(booking));
    const bookings = JSON.parse(localStorage.getItem('servio_bookings') || '[]');
    bookings.push(booking);
    localStorage.setItem('servio_bookings', JSON.stringify(bookings));
    window.location.href = './booking-confirmation.html';
  });

  // ── Decline proposal ──────────────────────
  document.querySelectorAll('[data-decline-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      btn.closest('.proposal-card')?.remove();
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      showToast?.(_t('toast_proposal_declined') || 'Proposal declined', 'info');
    });
  });

  // ── Edit job post (stub) ───────────────────
  document.querySelectorAll('[data-i18n="cust_edit"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      showToast(_t('toast_coming_soon'), 'info');
    });
  });

  // ── Dismiss notification ───────────────────
  document.querySelectorAll('[data-i18n="cust_dismiss"]').forEach(btn => {
    btn.addEventListener('click', () => {
      const _t = typeof window.t === 'function' ? window.t : (k) => k;
      btn.closest('.notif-card-v2')?.remove();
      showToast(_t('toast_notif_dismissed'), 'info');
    });
  });
})();

// .
