/* ═══════════════════════════════════════════════════════════
   customer-dashboard.js
   ═══════════════════════════════════════════════════════════ */
import { showToast } from '../components/toast.js';
import { revealAll } from '../components/scroll-reveal.js';


const TAB_KEY = 'servio_activeTab_customer';

function getSession() {
  try {
    return JSON.parse(localStorage.getItem('servio_session') || 'null');
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

function getInitials(name) {
  return (name || '?').trim().split(/\s+/).slice(0, 2).map(w => w[0].toUpperCase()).join('');
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
    localStorage.setItem(TAB_KEY, id);
  }

  tabs.forEach(tab => tab.addEventListener('click', () => showTab(tab.dataset.tab)));
  document.querySelectorAll('.dash-mobile-tab').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.mobileTab));
  });

  // data-tab-link buttons (Quick Actions → Bookings, Favourites, etc.)
  document.querySelectorAll('[data-tab-link]').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.tabLink));
  });

  // Cancel booking with contextual confirmation
  document.querySelectorAll('[data-cancel-booking]').forEach(btn => {
    btn.addEventListener('click', () => {
      const type = btn.dataset.cancelType || 'confirmed';
      const msg =
        type === 'pending'
          ? (typeof window.t === 'function' ? window.t('confirm_withdraw') : 'Withdraw this pending request? You can submit a new booking anytime.')
          : (typeof window.t === 'function' ? window.t('confirm_cancel') : 'Cancel this confirmed visit? You may need to book a new slot if you still need the service.');
      if (!window.confirm(msg)) return;
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
    });
  });

  // Restore saved tab
  const saved = localStorage.getItem(TAB_KEY) || 'overview';
  showTab(saved);
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

  const name = session.name || account?.fullName || 'User';
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
    const email = session.email || account?.email || '';
    emailEl.textContent = email || '—';
  }
  const firstName = name.split(' ')[0];
  document.querySelectorAll('[data-dash-firstname]').forEach(el => {
    el.textContent = firstName;
    el.removeAttribute('data-i18n'); // real name set — prevent lang.js from re-translating to placeholder
  });
  if (welcomeEl) {
    welcomeEl.textContent = typeof window.t === 'function' ? window.t('cust_welcome_sub_text') : 'Your overview';
  }

  // Pre-fill settings form from account data
  if (account) {
    document.querySelectorAll('[data-settings-field]').forEach(f => {
      if (account[f.dataset.settingsField] != null) {
        f.value = account[f.dataset.settingsField];
      }
    });
    // Update avatar preview initials
    const preview = document.querySelector('[data-avatar-preview]');
    if (preview && preview.children.length === 0) preview.textContent = initials;
  }
}

/* ── Stats ──────────────────────────────────────────────── */
function populateStats() {
  const bookingsTotal = 3; // Demo static values
  const goalTotal     = 5;
  const pct = Math.round((bookingsTotal / goalTotal) * 100);

  const tEl = document.querySelector('[data-stat="total-bookings"]');
  const aEl = document.querySelector('[data-stat="active-bookings"]');
  const sEl = document.querySelector('[data-stat="saved-technicians"]');

  if (tEl) tEl.textContent = String(bookingsTotal);
  if (aEl) aEl.textContent = '2';
  if (sEl) sEl.textContent = '2';

  const spentEl = document.querySelector('[data-stat="total-spent"]');
  if (spentEl) spentEl.textContent = '1,250 EGP';

  // Update Goal Context & Progress Bar
  const ctxE = document.querySelector('.dash-stat-card__context[data-i18n-html]');
  if (ctxE) {
    ctxE.setAttribute('data-i18n-pct', String(pct));
    // Trigger translation again if lang.js is available
    if (window.applyLanguage && window.__lang) {
      window.applyLanguage(window.__lang);
    }
  }

  const barFill = document.querySelector('[data-stat-goal-bar="total"]');
  if (barFill) barFill.style.width = pct + '%';
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

/* ── Notifications: mark all read ──────────────────────── */
function initNotifications() {
  const markAllBtn = document.getElementById('mark-all-read');
  if (!markAllBtn) return;
  markAllBtn.addEventListener('click', () => {
    document.querySelectorAll('.notif-card--unread').forEach(el => el.classList.remove('notif-card--unread'));
    document.querySelectorAll('.notif-card-v2.is-unread').forEach(el => el.classList.remove('is-unread'));
    document.querySelectorAll('.notif-card__dot:not(.notif-card__dot--read)').forEach(el => {
      el.classList.add('notif-card__dot--read');
    });
    showToast(typeof window.t === 'function' ? window.t('toast_notif_read') : 'All notifications marked as read.', 'success');
  });
}

/* ── Settings: photo upload preview ────────────────────── */
function initSettingsForm() {
  // Fix 5: Photo upload via hidden input + Change Photo button
  const photoUploadInput = document.getElementById('photo-upload-input');
  const changePhotoBtn = document.getElementById('btn-change-photo');
  const preview = document.querySelector('[data-avatar-preview]');

  if (changePhotoBtn && photoUploadInput) {
    changePhotoBtn.addEventListener('click', () => photoUploadInput.click());
  }

  if (photoUploadInput && preview) {
    photoUploadInput.addEventListener('change', () => {
      const file = photoUploadInput.files[0];
      if (!file) {
        // Fall back to initials
        const session = getSession();
        const account = getAccount();
        const name = session?.name || account?.fullName || 'User';
        preview.innerHTML = `<span data-dash-initials>${getInitials(name)}</span>`;
        return;
      }
      const reader = new FileReader();
      reader.onload = (evt) => {
        preview.innerHTML = `<img src="${evt.target.result}" alt="Profile photo" style="width:100%;height:100%;object-fit:cover;border-radius:50%;" />`;
      };
      reader.readAsDataURL(file);
    });
  }

  const form = document.querySelector('[data-settings-form]');
  if (!form) return;
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    let reqOk = true;
    form.querySelectorAll('input[data-required]').forEach(input => {
      if (!input.value.trim()) reqOk = false;
    });
    if (!reqOk) {
      showToast(typeof window.t === 'function' ? window.t('toast_fill_required') : 'Please fill all required fields.', 'info');
      return;
    }
    const newPw = form.querySelector('#settings-new-password');
    const confirmPw = form.querySelector('#settings-confirm-password');
    const currentPw = form.querySelector('#settings-current-password');
    if (newPw?.value || confirmPw?.value) {
      if (!currentPw?.value?.trim()) {
        showToast(typeof window.t === 'function' ? window.t('toast_enter_current_pw') : 'Enter your current password to set a new one.', 'info');
        currentPw?.focus();
        return;
      }
      if (newPw.value.length < 8) {
        showToast(typeof window.t === 'function' ? window.t('toast_pw_min_length') : 'New password must be at least 8 characters.', 'info');
        newPw.focus();
        return;
      }
      if (!/(?=.*[A-Za-z])(?=.*\d)/.test(newPw.value)) {
        showToast(typeof window.t === 'function' ? window.t('toast_pw_needs_letter_num') : 'New password needs at least one letter and one number.', 'info');
        newPw.focus();
        return;
      }
      if (newPw.value !== confirmPw.value) {
        showToast(typeof window.t === 'function' ? window.t('toast_pw_mismatch') : 'New password and confirmation do not match.', 'info');
        confirmPw.focus();
        return;
      }
    }
    const account = getAccount() || {};
    const passwordFields = new Set(['newPassword', 'confirmPassword']);
    document.querySelectorAll('[data-settings-field]').forEach(f => {
      if (!passwordFields.has(f.dataset.settingsField)) {
        account[f.dataset.settingsField] = f.value;
      }
    });
    localStorage.setItem('servio_account', JSON.stringify(account));
    const session = getSession();
    if (session && account.fullName) {
      session.name = account.fullName;
      localStorage.setItem('servio_session', JSON.stringify(session));
    }
    if (newPw?.value) {
      newPw.value = '';
      confirmPw.value = '';
      if (currentPw) currentPw.value = '';
      showToast(typeof window.t === 'function' ? window.t('toast_pw_saved') : 'Profile saved. Password change simulated (demo only).', 'success');
    } else {
      showToast(typeof window.t === 'function' ? window.t('toast_settings_saved') : 'Your changes have been saved.', 'success');
    }
    populateProfile();
    updateWelcomeText();
    updateProfileCompleteness();
  });
}

/* ── Fix 3: Delete account button ──────────────────────── */
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
      const input = wrap.querySelector('input');
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

  // Email blur validation
  const emailInput = form.querySelector('input[type="email"], input[name="email"], #settings-email');
  if (emailInput) {
    emailInput.addEventListener('blur', () => {
      if (emailInput.value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailInput.value)) {
        setError(emailInput, typeof window.t === 'function' ? window.t('err_invalid_email') : 'Please enter a valid email address.');
      } else if (emailInput.value) {
        setValid(emailInput);
      }
    });
  }

  // Confirm password blur
  const newPw = form.querySelector('#settings-new-password, input[name="new-password"]');
  const confirmPw = form.querySelector('#settings-confirm-password, input[name="confirm-password"]');
  if (newPw && confirmPw) {
    confirmPw.addEventListener('blur', () => {
      if (confirmPw.value && confirmPw.value !== newPw.value) {
        setError(confirmPw, typeof window.t === 'function' ? window.t('err_pw_mismatch') : 'Passwords do not match.');
      } else if (confirmPw.value) {
        setValid(confirmPw);
      }
    });
  }

  /* Required fields on submit are handled in initSettingsForm (toast + return). */
}

/* ── Logout ─────────────────────────────────────────────── */
function initDashLogout() {
  const btn = document.querySelector('[data-dash-logout]');
  if (!btn) return;
  btn.addEventListener('click', () => {
    try {
      localStorage.removeItem('servio_session');
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
populateStats();
updateWelcomeText();

initTabs();
initBookingFilter();
initHistoryPanel();
initFavouritesPanel();
initNotificationActions();
initNotifications();
initSettingsForm();
initDeleteAccount();
initPasswordToggles();
initSettingsValidation();
initSettingsTabs();
initSecurityForm();
initPasswordStrength();
initSettingToggles();
initLanguageCards();
initThemeCards();
initAddressTab();
initAccountTab();
initDashLogout();

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
    document.querySelectorAll('.stab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
    if (target === 'profile') updateProfileCompleteness();
  });
  // Run once on load so the bar shows the correct percentage immediately
  updateProfileCompleteness();
}

/* ── Security form (separate from profile form) ──────────── */
function initSecurityForm() {
  const form = document.getElementById('security-form');
  if (!form) return;
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
    const currentPw = form.querySelector('#settings-current-password');
    const newPw     = form.querySelector('#settings-new-password');
    const confirmPw = form.querySelector('#settings-confirm-password');
    if (!currentPw.value.trim()) {
      showToast(_t('toast_enter_current_pw'), 'info');
      currentPw.focus(); return;
    }
    if (newPw.value.length < 8) {
      showToast(_t('toast_pw_min_length'), 'info');
      newPw.focus(); return;
    }
    if (!/(?=.*[A-Za-z])(?=.*\d)/.test(newPw.value)) {
      showToast(_t('toast_pw_needs_letter_num'), 'info');
      newPw.focus(); return;
    }
    if (newPw.value !== confirmPw.value) {
      showToast(_t('toast_pw_mismatch'), 'info');
      confirmPw.focus(); return;
    }
    currentPw.value = '';
    newPw.value = '';
    confirmPw.value = '';
    document.getElementById('pw-strength-wrap')?.setAttribute('hidden', '');
    document.querySelectorAll('.pw-check').forEach(c => c.classList.remove('is-met'));
    showToast(_t('toast_pw_updated'), 'success');
  });
}

/* ── Password strength meter + live checklist ────────────── */
function initPasswordStrength() {
  const newPw     = document.getElementById('settings-new-password');
  const confirmPw = document.getElementById('settings-confirm-password');
  const wrap      = document.getElementById('pw-strength-wrap');
  const fill      = document.getElementById('pw-strength-fill');
  const label     = document.getElementById('pw-strength-label');
  const matchHint = document.getElementById('pw-match-hint');
  if (!newPw || !wrap) return;

  const checks = {
    length:  { el: document.getElementById('pwc-length'),  test: v => v.length >= 8 },
    upper:   { el: document.getElementById('pwc-upper'),   test: v => /[A-Z]/.test(v) },
    number:  { el: document.getElementById('pwc-number'),  test: v => /\d/.test(v) },
    special: { el: document.getElementById('pwc-special'), test: v => /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(v) },
  };

  const strengthLabels = ['', 'cust_pw_strength_weak', 'cust_pw_strength_fair', 'cust_pw_strength_good', 'cust_pw_strength_strong'];

  newPw.addEventListener('input', () => {
    const v = newPw.value;
    if (!v) { wrap.setAttribute('hidden', ''); return; }
    wrap.removeAttribute('hidden');

    let met = 0;
    Object.values(checks).forEach(c => {
      const pass = c.test(v);
      c.el?.classList.toggle('is-met', pass);
      if (pass) met++;
    });

    fill.setAttribute('data-level', met);
    fill.style.width = (met * 25) + '%';
    const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
    label.textContent = _t(strengthLabels[met]);
    label.setAttribute('data-level', met);

    if (confirmPw.value) checkMatch();
  });

  function checkMatch() {
    if (!matchHint || !confirmPw.value) return;
    const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
    const match = newPw.value === confirmPw.value;
    matchHint.removeAttribute('hidden');
    matchHint.textContent = _t(match ? 'cust_pw_match' : 'cust_pw_no_match');
    matchHint.className = 'pw-match-hint ' + (match ? 'is-match' : 'is-mismatch');
  }
  confirmPw?.addEventListener('input', checkMatch);
}

/* ── Profile completeness bar ────────────────────────────── */
function updateProfileCompleteness() {
  const account = getAccount ? getAccount() : null;
  const fields = ['fullName', 'email', 'phone', 'city', 'bio'];
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
function initAddressTab() {
  const formWrap   = document.getElementById('addr-form-wrap');
  const btnAdd     = document.getElementById('btn-addr-add');
  const btnCancel  = document.getElementById('btn-addr-cancel');
  const btnSave    = document.getElementById('btn-addr-save');
  const formTitle  = document.getElementById('addr-form-title');
  if (!formWrap) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  let currentAddrTarget = null;

  function openForm(target) {
    currentAddrTarget = target;
    formTitle.textContent = _t('cust_addr_edit_title');
    // Pre-fill if stored
    const saved = JSON.parse(localStorage.getItem('servio_addresses') || '{}');
    const data = saved[target] || {};
    document.getElementById('addr-input-street').value   = data.street   || '';
    document.getElementById('addr-input-district').value = data.district || '';
    document.getElementById('addr-input-city').value     = data.city     || '';
    formWrap.removeAttribute('hidden');
    btnAdd.setAttribute('hidden', '');
    document.getElementById('addr-input-street').focus();
  }

  function closeForm() {
    formWrap.setAttribute('hidden', '');
    btnAdd.removeAttribute('hidden');
    currentAddrTarget = null;
  }

  // Edit buttons on each card
  document.querySelectorAll('.btn-addr-edit').forEach(btn => {
    btn.addEventListener('click', () => openForm(btn.dataset.addrTarget));
  });

  btnAdd.addEventListener('click', () => openForm('other-' + Date.now()));
  btnCancel.addEventListener('click', closeForm);

  btnSave.addEventListener('click', () => {
    if (!currentAddrTarget) return;
    const street   = document.getElementById('addr-input-street').value.trim();
    const district = document.getElementById('addr-input-district').value.trim();
    const city     = document.getElementById('addr-input-city').value.trim();
    if (!street) { document.getElementById('addr-input-street').focus(); return; }

    const saved = JSON.parse(localStorage.getItem('servio_addresses') || '{}');
    saved[currentAddrTarget] = { street, district, city };
    localStorage.setItem('servio_addresses', JSON.stringify(saved));

    const full = [street, district, city].filter(Boolean).join(', ');
    const valueEl = document.getElementById('addr-' + currentAddrTarget + '-value');
    if (valueEl) valueEl.textContent = full;

    closeForm();
    showToast(_t('toast_addr_saved'), 'success');
  });

  // Restore saved addresses on load
  const saved = JSON.parse(localStorage.getItem('servio_addresses') || '{}');
  ['home', 'work'].forEach(key => {
    const data = saved[key];
    if (!data) return;
    const el = document.getElementById('addr-' + key + '-value');
    if (el) el.textContent = [data.street, data.district, data.city].filter(Boolean).join(', ');
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

  btnDeleteOk?.addEventListener('click', () => {
    closeDeleteModal();
    showToast(_t('toast_delete_demo'), 'info');
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
    const pin = Math.floor(1000 + Math.random() * 9000);
    const booking = {
      id: 'S-' + Math.floor(2900 + Math.random() * 100),
      tech: pendingProposal?.tech || 'Technician',
      price: pendingProposal?.price || 0,
      payment: document.querySelector('[name="paymentMethod"]:checked')?.value || 'online',
      pin, status: 'Booked', timestamp: Date.now(),
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
