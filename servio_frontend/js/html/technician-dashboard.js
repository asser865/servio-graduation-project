/* ═══════════════════════════════════════════════════════════
   technician-dashboard.js
   ═══════════════════════════════════════════════════════════ */
import { revealAll } from '../components/scroll-reveal.js';
import { showToast } from '../components/toast.js';
import { getInitials } from '../utils/string.js';
import { getMe, updateMe, updatePassword, updateEmail, deleteMe, updateAvailability, toggleAvailableNow, toggleBlockedDate } from '../api/users.js';
import { uploadPublicFile } from '../api/uploads.js';
import { getWorkerBookings, updateBookingStatus } from '../api/bookings.js';
import { getWorkerReviews } from '../api/reviews.js';
import { getServices } from '../api/services.js';

const TAB_KEY = 'servio_activeTab_technician';

// Holds uploaded avatar URL between file-select and form-save
let _pendingPhotoUrl = null;
const DAYS_KEYS = ['avail_day_mon','avail_day_tue','avail_day_wed','avail_day_thu','avail_day_fri','avail_day_sat','avail_day_sun'];
const SKILLS_KEYS = ['skill_plumbing','skill_electrical','skill_hvac','skill_painting','skill_carpentry',
  'skill_cleaning','skill_roofing','skill_flooring','skill_appliance','skill_landscaping','skill_general'];

// Tab label map for topbar title (keys resolved via t() at render time)
const TAB_LABEL_KEYS = {
  'overview':      'tech_nav_overview',
  'job-queue':     'tech_nav_job_queue',
  'earnings':      'tech_nav_earnings',
  'availability':  'tech_nav_availability',
  'reviews':       'tech_nav_reviews',
  'verification':  'tech_nav_verification',
  'settings':      'tech_nav_settings',
  'job-board':     'tech_nav_job_board',
  'my-proposals':  'tech_nav_proposals',
};

function getSession() {
  try { return JSON.parse(localStorage.getItem('servio_session') || 'null'); } catch { return null; }
}

// ── Auth Guard ──────────────────────────────────────────
const session = getSession();
if (!session) {
  window.location.href = './login.html';
} else if (session.role === 'admin') {
  window.location.href = './admin-dashboard.html';
} else if (session.role === 'customer') {
  window.location.href = './customer-dashboard.html';
}

function getAccount() {
  try { return JSON.parse(localStorage.getItem('servio_account') || 'null'); } catch { return null; }
}
/* ── Topbar notification badge ──────────────────────────── */
function updateTopbarBadge(count) {
  const badge = document.getElementById('topbar-notif-badge');
  if (!badge) return;
  badge.hidden = count === 0;
  badge.textContent = count > 9 ? '9+' : String(count);
}

/* ── Topbar avatar ──────────────────────────────────────── */
function initTopbarAvatar() {
  try {
    const session = JSON.parse(localStorage.getItem('servio_session') || '{}');
    const initial = (session.name || 'T')[0].toUpperCase();
    const el = document.getElementById('topbar-avatar');
    if (el) el.textContent = initial;
  } catch {}
}

/* ── Topbar theme toggle ────────────────────────────────── */
function initTabs() {
  const tabs = document.querySelectorAll('[data-tab]');
  const panels = document.querySelectorAll('[data-panel]');
  const mobileTabs = document.querySelector('[data-mobile-tabs]');

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

  // Timestamps of last data refresh per tab (ms). Avoids redundant API calls on rapid switches.
  const tabLastRefresh = {};
  const TAB_REFRESH_TTL = 30_000; // 30 s

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
    // Update topbar title
    const labelKey = TAB_LABEL_KEYS[id];
    const el = document.getElementById('dash-topbar-title');
    if (el) {
      if (labelKey && typeof window.t === 'function') {
        el.textContent = window.t(labelKey);
        el.removeAttribute('data-i18n');
      } else if (labelKey) {
        el.setAttribute('data-i18n', labelKey);
      } else {
        el.textContent = id;
      }
    }

    // Refresh data for data-driven tabs (skip on first load — initDashboard already fetched)
    const now = Date.now();
    const stale = !tabLastRefresh[id] || (now - tabLastRefresh[id]) > TAB_REFRESH_TTL;
    if (stale && tabLastRefresh[id] !== undefined) {
      tabLastRefresh[id] = now;
      if (id === 'job-queue') {
        initJobQueue().catch(() => {});
      } else if (id === 'overview' || id === 'earnings') {
        populateStats().catch(() => {});
      }
    } else if (tabLastRefresh[id] === undefined) {
      // Mark as seen so next visit triggers refresh
      tabLastRefresh[id] = now;
    }
  }

  tabs.forEach(tab => tab.addEventListener('click', () => showTab(tab.dataset.tab)));
  document.querySelectorAll('[data-tab-link]').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.tabLink));
  });
  document.querySelectorAll('.dash-mobile-tab').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.mobileTab));
  });

  // Quick availability button in overview
  const quickAvail = document.querySelector('[data-quick-availability]');
  if (quickAvail) quickAvail.addEventListener('click', () => showTab('availability'));

  const saved = sessionStorage.getItem(TAB_KEY) || 'overview';
  showTab(saved);
}

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

  const name = session.name || account?.fullName || 'Technician';
  const initials = getInitials(name);

  document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = initials; });
  const nameEl = document.querySelector('[data-dash-name]');
  const emailEl = document.querySelector('[data-dash-email]');
  if (nameEl) nameEl.textContent = name;
  if (emailEl) {
    const email = session.email || account?.email || '';
    emailEl.textContent = email || '—';
  }
  // Topbar avatar initial
  const topbarAvatar = document.getElementById('topbar-avatar');
  if (topbarAvatar && !topbarAvatar.hasAttribute('data-dash-initials')) topbarAvatar.textContent = initials[0] || 'T';
  // First name in welcome banner
  document.querySelectorAll('[data-dash-firstname]').forEach(el => { el.textContent = name.split(' ')[0]; });

  // Build an effective account by merging session fields as fallback for missing account data
  const effectiveAccount = {
    fullName:        session.name || '',
    name:            session.name || '',
    email:           session.email || '',
    phone:           session.phone || '',
    skills:          session.skills || [],
    specialty:       Array.isArray(session.skills) ? session.skills.join(', ') : '',
    hourlyRate:      session.hourlyRate ?? '',
    yearsExperience: session.yearsExperience ?? '',
    experience:      session.yearsExperience ?? '',
    bio:             session.bio || '',
    ...( account || {} ),
  };

  // Normalise field aliases
  if (!effectiveAccount.fullName && effectiveAccount.name) effectiveAccount.fullName = effectiveAccount.name;
  if (effectiveAccount.yearsExperience != null && effectiveAccount.experience == null) {
    effectiveAccount.experience = effectiveAccount.yearsExperience;
  }
  if (!effectiveAccount.specialty && Array.isArray(effectiveAccount.skills) && effectiveAccount.skills.length) {
    effectiveAccount.specialty = effectiveAccount.skills.join(', ');
  }

  document.querySelectorAll('[data-settings-field]').forEach(f => {
    const val = effectiveAccount[f.dataset.settingsField];
    if (val != null && val !== '') f.value = val;
  });
  const serviceAreaInput = document.getElementById('service-area');
  if (serviceAreaInput && effectiveAccount.serviceArea) serviceAreaInput.value = effectiveAccount.serviceArea;

  // Render avatar — photo takes priority over initials
  const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
  // Only trust server URL if it's an actual HTTP/HTTPS/relative URL (not a local filesystem path)
  const serverImg = session.profileImage || '';
  const serverImgUsable = serverImg && (serverImg.startsWith('http') || serverImg.startsWith('/'));
  const photoUrl = serverImgUsable ? serverImg : (localStorage.getItem('servio_avatar_cache') || null);
  const preview  = document.querySelector('[data-avatar-preview]');
  const topbar   = document.getElementById('topbar-avatar');

  if (preview) {
    if (photoUrl) {
      preview.innerHTML = `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`;
      preview.classList.remove('avatar-required');
    } else {
      preview.innerHTML = `<span>${initials}</span>`;
      // Mandatory guard — red ring + hint when no photo
      preview.classList.add('avatar-required');
      const wrap = preview.closest('.settings-avatar-wrap');
      if (wrap && !wrap.querySelector('.avatar-required-hint')) {
        const hint = document.createElement('p');
        hint.className = 'avatar-required-hint';
        hint.textContent = typeof window.t === 'function'
          ? window.t('toast_photo_required')
          : 'Please add a profile photo before saving.';
        wrap.insertAdjacentElement('afterend', hint);
      }
    }
  }
  if (topbar) {
    topbar.innerHTML = photoUrl
      ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
      : (initials[0] || 'T');
  }

  // Sync from API — refresh photo and populate form fields with authoritative data
  getMe().then(user => {
    if (!user) return;

    // Update profile photo if changed (only use server URL if it's a real HTTP URL)
    const apiImg = user.profileImage || '';
    const apiImgUsable = apiImg && (apiImg.startsWith('http') || apiImg.startsWith('/'));
    const resolvedPhoto = apiImgUsable ? apiImg : (localStorage.getItem('servio_avatar_cache') || null);
    if (resolvedPhoto && resolvedPhoto !== photoUrl) {
      if (apiImgUsable) {
        const s = getSession();
        if (s) { s.profileImage = apiImg; localStorage.setItem('servio_session', JSON.stringify(s)); }
      }
      if (preview) {
        preview.innerHTML = `<img src="${resolvedPhoto}" alt="Profile photo" style="${imgStyle}" />`;
        preview.classList.remove('avatar-required');
        const hint = preview.closest('.settings-avatar-wrap')?.nextElementSibling;
        if (hint?.classList.contains('avatar-required-hint')) hint.remove();
      }
      if (topbar) topbar.innerHTML = `<img src="${resolvedPhoto}" alt="Profile photo" style="${imgStyle}" />`;
    }

    // Populate settings form fields from live API data
    const fieldMap = {
      fullName:   user.name,
      email:      user.email,
      phone:      user.phone,
      specialty:  Array.isArray(user.skills) ? user.skills.join(', ') : (user.specialty || ''),
      hourlyRate: user.hourlyRate,
      experience: user.yearsExperience,
      bio:        user.bio,
      facebook:   user.facebook,
      instagram:  user.instagram,
      portfolio:  user.portfolioUrl,
    };
    Object.entries(fieldMap).forEach(([field, val]) => {
      if (val == null || val === '') return;
      const el = document.querySelector(`[data-settings-field="${field}"]`);
      if (el) el.value = val;
    });

    // Update sidebar name and initials
    if (user.name) {
      document.querySelectorAll('[data-dash-name]').forEach(el => { el.textContent = user.name; });
      const freshInitials = getInitials(user.name);
      document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = freshInitials; });
      document.querySelectorAll('[data-dash-firstname]').forEach(el => { el.textContent = user.name.split(' ')[0]; });
    }

    // Persist updated data locally for offline use
    try {
      const acc = getAccount() || {};
      if (user.name)            { acc.fullName = user.name; acc.name = user.name; }
      if (user.phone)           acc.phone       = user.phone;
      if (user.skills)          { acc.skills = user.skills; acc.specialty = user.skills.join(', '); }
      if (user.hourlyRate)      acc.hourlyRate   = user.hourlyRate;
      if (user.yearsExperience != null) { acc.yearsExperience = user.yearsExperience; acc.experience = user.yearsExperience; }
      if (user.bio)             acc.bio          = user.bio;
      if (user.facebook)        acc.facebook     = user.facebook;
      if (user.instagram)       acc.instagram    = user.instagram;
      if (user.portfolioUrl)    acc.portfolio    = user.portfolioUrl;
      localStorage.setItem('servio_account', JSON.stringify(acc));
    } catch (_) {}
  }).catch(() => {});
}

function updateWelcomeText() {
  // Time-aware greeting
  const hour = new Date().getHours();
  const greetingKey = hour < 12 ? 'greeting_morning' : hour < 17 ? 'greeting_afternoon' : 'greeting_evening';
  const greeting = typeof window.t === 'function' ? window.t(greetingKey) : (hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening');
  document.querySelectorAll('[data-dash-greeting], .dash-welcome__greeting').forEach(el => {
    el.textContent = greeting;
  });

  // Populate first name in the welcome banner
  const session = getSession();
  const account = getAccount();
  const name = session?.name || account?.fullName || 'Technician';
  const firstName = name.split(' ')[0];
  document.querySelectorAll('[data-dash-firstname]').forEach(el => { el.textContent = firstName; });

  // Legacy selector support
  const welcomeEl = document.querySelector('[data-dash-welcome]');
  if (welcomeEl) {
    const welcomeKey = typeof window.t === 'function' ? window.t('tech_welcome_back') : 'Welcome back, ';
    welcomeEl.textContent = `${welcomeKey}${firstName}!`;
  }

  // Status sub-text
  const pending = parseInt(document.querySelector('[data-stat="pending-requests"]')?.textContent, 10) || 0;
  let subText;
  if (typeof window.t === 'function') {
    subText = pending === 0
      ? window.t('tech_no_requests')
      : pending === 1
        ? window.t('tech_n_requests', { n: 1 })
        : window.t('tech_n_requests_plural', { n: pending });
  } else {
    subText = pending === 0 ? 'No new requests right now.' : `You have ${pending} new job request${pending > 1 ? 's' : ''} waiting.`;
  }
  document.querySelectorAll('[data-dash-status-sub], .dash-welcome__sub').forEach(el => {
    el.textContent = subText;
  });
}

async function populateStats() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  function setStat(key, val) {
    const el = document.querySelector(`[data-stat="${key}"]`);
    if (el) el.textContent = val;
  }
  function setStatSub(key, val) {
    const el = document.querySelector(`[data-stat-sub="${key}"]`);
    if (el) el.textContent = val;
  }

  // Fetch all bookings for this worker (up to 200 to compute stats)
  let bookings = [];
  let totalCount = 0;
  try {
    const res = await getWorkerBookings({ limit: 200 });
    bookings = res?.bookings || [];
    totalCount = res?.pagination?.total ?? bookings.length;
  } catch (_) {}

  const now = new Date();
  const thisMonth = now.getMonth();
  const thisYear  = now.getFullYear();
  const lastMonth = thisMonth === 0 ? 11 : thisMonth - 1;
  const lastYear  = thisMonth === 0 ? thisYear - 1 : thisYear;

  const completed = bookings.filter(b => b.status === 'completed');
  const pending   = bookings.filter(b => b.status === 'pending');

  // Month earnings = sum of totalPrice for completed bookings this month
  const monthEarnings = completed.reduce((sum, b) => {
    const d = new Date(b.scheduledDate || b.createdAt);
    if (d.getMonth() === thisMonth && d.getFullYear() === thisYear) {
      return sum + (b.totalPrice || 0);
    }
    return sum;
  }, 0);

  // Last month earnings for delta
  const lastMonthEarnings = completed.reduce((sum, b) => {
    const d = new Date(b.scheduledDate || b.createdAt);
    if (d.getMonth() === lastMonth && d.getFullYear() === lastYear) {
      return sum + (b.totalPrice || 0);
    }
    return sum;
  }, 0);

  // Outstanding cash: cash bookings that are completed but not yet settled
  const cashCompleted = completed.filter(b => b.paymentMethod === 'cash');
  const outstandingAmount = cashCompleted.reduce((sum, b) => sum + (b.totalPrice || 0), 0);

  // This month's job count
  const monthJobs = bookings.filter(b => {
    const d = new Date(b.scheduledDate || b.createdAt);
    return d.getMonth() === thisMonth && d.getFullYear() === thisYear && b.status !== 'cancelled' && b.status !== 'rejected';
  }).length;

  // Update stat card values
  const nonCancelled = bookings.filter(b => b.status !== 'cancelled' && b.status !== 'rejected');
  setStat('total-jobs', totalCount > bookings.length ? totalCount : nonCancelled.length);
  setStatSub('total-jobs-month', `+${monthJobs} ${_t('tech_stat_this_month') || 'this month'}`);

  setStat('month-earnings', monthEarnings > 0 ? `EGP ${monthEarnings.toLocaleString('en-US')}` : 'EGP 0');
  const delta = monthEarnings - lastMonthEarnings;
  const deltaStr = delta >= 0
    ? `+EGP ${Math.abs(delta).toLocaleString('en-US')} vs last`
    : `-EGP ${Math.abs(delta).toLocaleString('en-US')} vs last`;
  setStatSub('month-earnings-change', deltaStr);

  setStat('pending-requests', pending.length);
  setStatSub('pending-requests-note', pending.length > 0 ? (_t('tech_action_needed') || 'Action needed') : (_t('tech_no_pending') || 'All clear'));

  // Outstanding balance stat card
  const outstandingEl = document.querySelector('[data-stat="outstanding-balance"]');
  if (outstandingEl) {
    outstandingEl.innerHTML = `${outstandingAmount.toLocaleString('en-US')} <span data-i18n="currency_egp">EGP</span>`;
  }

  // Notification badge = pending requests
  updateTopbarBadge(pending.length);

  // Update welcome sub-text with real pending count
  document.querySelectorAll('[data-dash-status-sub], .dash-welcome__sub').forEach(el => {
    let subText;
    if (pending.length === 0) {
      subText = _t('tech_no_requests') || 'No new requests right now.';
    } else if (pending.length === 1) {
      subText = _t('tech_n_requests') ? _t('tech_n_requests').replace('{n}', 1) : 'You have 1 new job request waiting.';
    } else {
      const key = _t('tech_n_requests_plural') || `You have ${pending.length} new job requests waiting.`;
      subText = key.replace('{n}', pending.length);
    }
    el.textContent = subText;
  });

  // Populate earnings panel
  populateEarnings(bookings, completed, monthEarnings, lastMonthEarnings, cashCompleted, outstandingAmount);

  // Populate overview panels
  populateOverviewIncoming(pending);
  populateOverviewSchedule(bookings);

  // Populate notifications from booking activity
  populateNotifications(bookings);

  return { bookings, pending, completed, monthEarnings, outstandingAmount };
}

// ── Available Now Toggle ──────────────────────────────────────────────────────
// Connects the toggle to PATCH /users/me/available with debounce + UI feedback
function initAvailableNowToggle(initialState) {
  const toggle  = document.getElementById('avail-now-toggle');
  const card    = document.getElementById('avail-now-card');
  const pill    = document.getElementById('avail-now-pill');
  const icon    = document.getElementById('avail-now-icon');
  if (!toggle) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  function applyUIState(isOn) {
    const safeT = (k, def) => { 
      const r = _t(k); 
      return (r === k || !r) ? def : r; 
    };
    toggle.checked = isOn;
    if (card)  card.classList.toggle('is-active', isOn);
    if (pill) {
      pill.textContent = isOn ? safeT('avail_status_online', 'Online') : safeT('avail_status_offline', 'Offline');
      pill.classList.toggle('is-online', isOn);
    }
  }

  // Seed from API state
  applyUIState(!!initialState);

  let debounceTimer = null;
  toggle.addEventListener('change', () => {
    const isOn = toggle.checked;
    applyUIState(isOn);

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(async () => {
      toggle.disabled = true;
      try {
        await toggleAvailableNow(isOn);
        // Persist to session
        try {
          const s = JSON.parse(localStorage.getItem('servio_session') || '{}');
          s.isAvailable = isOn;
          localStorage.setItem('servio_session', JSON.stringify(s));
        } catch (_) {}
        const msg = isOn
          ? (_t('toast_avail_on')  || 'You are now visible and accepting bookings.')
          : (_t('toast_avail_off') || 'You are now offline. New bookings are paused.');
        showToast(msg, isOn ? 'success' : 'info');
      } catch (err) {
        // Revert on error
        applyUIState(!isOn);
        showToast(err?.message || 'Failed to update availability.', 'error');
      } finally {
        toggle.disabled = false;
      }
    }, 350);
  });
}

// ── Weekly Schedule Builder ────────────────────────────────────────────────────
// Renders structured day rows with AM/PM dropdowns, on/off chip, and validation
function initAvailabilitySchedule(savedSlots) {
  const container = document.getElementById('avail-schedule');
  if (!container) return;
  const T = typeof window.t === 'function' ? window.t.bind(window) : (k) => k;

  const DAY_CONFIGS = [
    { key: 'monday',    label: T('avail_day_mon') || 'Monday',    abbr: 'MON', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'tuesday',   label: T('avail_day_tue') || 'Tuesday',   abbr: 'TUE', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'wednesday', label: T('avail_day_wed') || 'Wednesday', abbr: 'WED', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'thursday',  label: T('avail_day_thu') || 'Thursday',  abbr: 'THU', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'friday',    label: T('avail_day_fri') || 'Friday',    abbr: 'FRI', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'saturday',  label: T('avail_day_sat') || 'Saturday',  abbr: 'SAT', defaultFrom: '10:00', defaultTo: '15:00' },
    { key: 'sunday',    label: T('avail_day_sun') || 'Sunday',    abbr: 'SUN', defaultFrom: '10:00', defaultTo: '15:00' },
  ];

  // Build half-hour time options for dropdown
  function buildTimeOptions() {
    const opts = [];
    for (let h = 6; h <= 23; h++) {
      for (const m of [0, 30]) {
        const pad  = n => String(n).padStart(2, '0');
        const val  = `${pad(h)}:${pad(m)}`;
        const h12  = h === 0 ? 12 : h > 12 ? h - 12 : h;
        const ampm = h >= 12 ? 'PM' : 'AM';
        const lbl  = `${h12}:${pad(m)} ${ampm}`;
        opts.push({ val, lbl });
      }
    }
    return opts;
  }
  const TIME_OPTIONS = buildTimeOptions();

  function makeSelect(id, selectedVal) {
    const sel = document.createElement('select');
    sel.className = 'avail-time-select';
    sel.id = id;
    sel.setAttribute('aria-label', id);
    TIME_OPTIONS.forEach(({ val, lbl }) => {
      const opt = document.createElement('option');
      opt.value = val;
      opt.textContent = lbl;
      if (val === selectedVal) opt.selected = true;
      sel.appendChild(opt);
    });
    return sel;
  }

  function validateRow(fromSel, toSel) {
    const fromVal = fromSel.value;
    const toVal   = toSel.value;
    const isValid = toVal > fromVal;
    toSel.classList.toggle('is-error', !isValid);
    return isValid;
  }

  container.innerHTML = '';

  DAY_CONFIGS.forEach(day => {
    const savedSlot = (savedSlots || []).find(s => s.day === day.key);
    const isActive  = !!savedSlot;
    const fromVal   = savedSlot?.from || day.defaultFrom;
    const toVal     = savedSlot?.to   || day.defaultTo;

    const row = document.createElement('div');
    row.className = `avail-day-row${isActive ? '' : ' is-off'}`;
    row.dataset.day = day.key;

    // Day name
    const nameEl = document.createElement('span');
    nameEl.className = 'avail-day-row__name';
    nameEl.textContent = day.abbr;
    nameEl.title = day.label;

    // Time selects
    const timesDiv = document.createElement('div');
    timesDiv.className = 'avail-day-row__times';
    const fromSel = makeSelect(`avail-from-${day.key}`, fromVal);
    const sep     = document.createElement('span');
    sep.className = 'avail-day-row__sep';
    sep.textContent = T('avail_to') || 'to';
    const toSel = makeSelect(`avail-to-${day.key}`, toVal);
    timesDiv.append(fromSel, sep, toSel);

    // Validate on change
    function onTimeChange() { validateRow(fromSel, toSel); }
    fromSel.addEventListener('change', onTimeChange);
    toSel.addEventListener('change', onTimeChange);

    // On/Off chip
    const chip = document.createElement('button');
    const safeT = (k, def) => { 
      const v = T(k); 
      return (v === k || !v) ? def : v; 
    };
    chip.type = 'button';
    chip.className = `avail-day-toggle-chip${isActive ? ' is-on' : ''}`;
    chip.textContent = isActive ? safeT('avail_working', 'Working') : safeT('avail_day_off', 'Not Available');
    chip.setAttribute('aria-pressed', String(isActive));
    chip.addEventListener('click', () => {
      const nowOn = !chip.classList.contains('is-on');
      chip.classList.toggle('is-on', nowOn);
      chip.textContent = nowOn ? safeT('avail_working', 'Working') : safeT('avail_day_off', 'Not Available');
      chip.setAttribute('aria-pressed', String(nowOn));
      row.classList.toggle('is-off', !nowOn);
      timesDiv.style.visibility = nowOn ? '' : 'hidden';
    });
    if (!isActive) timesDiv.style.visibility = 'hidden';

    row.append(nameEl, timesDiv, chip);
    container.appendChild(row);
  });

  // Clear All handler
  document.getElementById('avail-clear-schedule')?.addEventListener('click', () => {
    const safeT = (k, def) => { 
      const v = T(k); 
      return (v === k || !v) ? def : v; 
    };
    container.querySelectorAll('.avail-day-row').forEach(row => {
      row.classList.add('is-off');
      const chip = row.querySelector('.avail-day-toggle-chip');
      if (chip) {
        chip.classList.remove('is-on');
        chip.textContent = safeT('avail_day_off', 'Not Available');
        chip.setAttribute('aria-pressed', 'false');
      }
      const times = row.querySelector('.avail-day-row__times');
      if (times) times.style.visibility = 'hidden';
    });
  });
}

function initBlockedDatesCalendar(workerAvailability, initialBlockedDates) {
  let blockedDates = new Set(initialBlockedDates || []);
  let currentYear  = new Date().getFullYear();
  let currentMonth = new Date().getMonth();

  const DAY_NAMES  = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
  const avDays     = (workerAvailability || []).map(a => a.day);

  function renderBlockedCal() {
    const grid  = document.getElementById('blockedCalGrid');
    const label = document.getElementById('blockedCalLabel');
    const prev  = document.getElementById('blockedCalPrev');
    const next  = document.getElementById('blockedCalNext');
    if (!grid) return;

    const today     = new Date(); today.setHours(0,0,0,0);
    const maxDate   = new Date(); maxDate.setDate(maxDate.getDate() + 60); maxDate.setHours(0,0,0,0);
    const firstDay  = new Date(currentYear, currentMonth, 1);
    const lastDay   = new Date(currentYear, currentMonth + 1, 0);
    const prevEnd   = new Date(currentYear, currentMonth, 0);
    const nextStart = new Date(currentYear, currentMonth + 1, 1);

    if (label) label.textContent = firstDay.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    if (prev)  prev.disabled  = prevEnd < today;
    if (next)  next.disabled  = nextStart > maxDate;

    let html = '';
    for (let i = 0; i < firstDay.getDay(); i++) html += '<div class="bcal-day bcal-day--empty"></div>';

    for (let d = 1; d <= lastDay.getDate(); d++) {
      const date    = new Date(currentYear, currentMonth, d);
      const dateStr = `${currentYear}-${String(currentMonth+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
      const isPast     = date < today;
      const isFar      = date > maxDate;
      const isToday    = date.getTime() === today.getTime();
      const dayName    = DAY_NAMES[date.getDay()];
      const isOffSched = avDays.length > 0 && !avDays.includes(dayName);
      const isBlocked  = blockedDates.has(dateStr);

      let cls = 'bcal-day';
      if (isToday)    cls += ' bcal-day--today';
      if (isPast || isFar) cls += ' bcal-day--past';
      else if (isOffSched) cls += ' bcal-day--off-schedule';
      else if (isBlocked)  cls += ' bcal-day--blocked';
      else                 cls += ' bcal-day--working';

      const canClick = !isPast && !isFar && !isOffSched;
      html += `<div class="${cls}" ${canClick ? `data-date="${dateStr}"` : ''}>${d}</div>`;
    }

    grid.innerHTML = html;

    grid.querySelectorAll('.bcal-day[data-date]').forEach(cell => {
      cell.addEventListener('click', async () => {
        const d = cell.dataset.date;
        try {
          await toggleBlockedDate(d);
          if (blockedDates.has(d)) blockedDates.delete(d);
          else blockedDates.add(d);
          renderBlockedCal();
          // Show brief feedback
          const fb = document.getElementById('blocked-dates-feedback');
          if (fb) { fb.hidden = false; setTimeout(() => { fb.hidden = true; }, 2000); }
        } catch (err) {
          console.error('Failed to toggle blocked date:', err);
        }
      });
    });
  }

  document.getElementById('blockedCalPrev')?.addEventListener('click', () => {
    currentMonth--;
    if (currentMonth < 0) { currentMonth = 11; currentYear--; }
    renderBlockedCal();
  });
  document.getElementById('blockedCalNext')?.addEventListener('click', () => {
    currentMonth++;
    if (currentMonth > 11) { currentMonth = 0; currentYear++; }
    renderBlockedCal();
  });

  renderBlockedCal();
}

function initCategories(savedSkills) {
  const grid = document.getElementById('categories-grid');
  if (!grid) return;
  grid.innerHTML = '';
  const savedSet = new Set((savedSkills || []).map(s => s.toLowerCase()));
  const T2 = typeof window.t === 'function' ? window.t.bind(window) : (k) => k;
  const SKILL_DATA = [
    { key: 'skill_plumbing',     icon: '🔧' },
    { key: 'skill_electrical',   icon: '⚡' },
    { key: 'skill_hvac',         icon: '❄️' },
    { key: 'skill_painting',     icon: '🖌️' },
    { key: 'skill_carpentry',    icon: '🪚' },
    { key: 'skill_cleaning',     icon: '🧹' },
    { key: 'skill_roofing',      icon: '🏠' },
    { key: 'skill_flooring',     icon: '🪵' },
    { key: 'skill_appliance',    icon: '🔌' },
    { key: 'skill_landscaping',  icon: '🌿' },
    { key: 'skill_renovation',   icon: '🏗️' },
    { key: 'skill_handyman',     icon: '🔨' },
    { key: 'skill_drywall',      icon: '🧱' },
    { key: 'skill_pest_control', icon: '🦟' },
    { key: 'skill_installation', icon: '📺' },
    { key: 'skill_general',      icon: '🛠️' },
  ];
  SKILL_DATA.forEach(({ key, icon }) => {
    const label = T2(key);
    const isSelected = savedSet.has(label.toLowerCase()) || savedSet.has(key.replace('skill_', '').toLowerCase());
    const chip = document.createElement('label');
    chip.className = `avail-category-chip${isSelected ? ' is-selected' : ''}`;
    chip.dataset.skill = label;
    chip.innerHTML = `<input type="checkbox" ${isSelected ? 'checked' : ''} /><span>${icon} ${label}</span>`;
    chip.addEventListener('click', (e) => {
      e.preventDefault();
      chip.classList.toggle('is-selected');
      const cb = chip.querySelector('input[type="checkbox"]');
      if (cb) cb.checked = chip.classList.contains('is-selected');
    });
    grid.appendChild(chip);
  });
}

async function initJobQueue() {
  const container = document.getElementById('job-queue-list');
  if (!container) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  const showMsg = (text, color = '#6b7280') =>
    (container.innerHTML = `<div style="display:flex;flex-direction:column;align-items:center;padding:48px 24px;gap:12px;text-align:center;">
      <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="${color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" opacity="0.5"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/></svg>
      <p style="color:${color};font-size:0.95rem;margin:0;">${text}</p>
    </div>`);

  // Loading state
  showMsg('Loading jobs…');

  let bookings = [];
  try {
    const res = await getWorkerBookings({ limit: 50 });
    // Backend returns { bookings: [...], pagination: {...} }
    bookings = Array.isArray(res) ? res : (res?.bookings || []);
  } catch (err) {
    showMsg('Failed to load jobs. Please refresh.', '#dc2626');
    console.error('[Job Queue] API error:', err);
    return;
  }

  if (bookings.length === 0) {
    showMsg('No jobs assigned yet. Bookings from customers will appear here.');
    return;
  }

  const pending = bookings.filter(b => b.status === 'pending');
  const ongoing = bookings.filter(b => ['accepted','in_progress'].includes(b.status));
  const done    = bookings.filter(b => ['completed','rejected','cancelled'].includes(b.status));

  // Default tab: show active if exists, else pending, else done
  const defaultTab = ongoing.length ? 'active' : pending.length ? 'pending' : 'done';

  function badgeHtml(n) {
    return n > 0 ? `<span class="jq-tab-badge">${n}</span>` : '';
  }

  function makePane(id, items, emptyMsg) {
    const pane = document.createElement('div');
    pane.id = `stab-jq-${id}`;
    pane.className = 'stab-pane jq-tab-pane';
    if (id !== defaultTab) pane.setAttribute('hidden', '');
    else pane.classList.add('stab-pane--active');

    if (items.length === 0) {
      pane.innerHTML = `<div class="jq-empty-state"><svg viewBox="0 0 24 24" width="36" height="36" fill="none" stroke="#6b7280" stroke-width="1.5" opacity="0.4"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 00-2-2h-4a2 2 0 00-2 2v2"/></svg><p>${emptyMsg}</p></div>`;
    } else {
      const list = document.createElement('div');
      list.className = 'jq-queue-list';
      items.forEach(b => {
        try { list.appendChild(buildJobCard(b, _t)); }
        catch (e) { console.error('[Job Queue] card error', b._id, e); }
      });
      pane.appendChild(list);
    }
    return pane;
  }

  container.innerHTML = '';

  // ── Tab bar ──
  const tabBar = document.createElement('nav');
  tabBar.id = 'jq-tab-bar';
  tabBar.className = 'stab-bar jq-stab-bar';
  tabBar.setAttribute('role', 'tablist');
  tabBar.innerHTML = `
    <button class="stab-btn${defaultTab === 'pending' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'pending'}" data-stab="jq-pending">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9"/><path d="M12 8v4l2 2"/></svg>
      Awaiting Response${badgeHtml(pending.length)}
    </button>
    <button class="stab-btn${defaultTab === 'active' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'active'}" data-stab="jq-active">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><polyline points="13 2 13 9 20 9"/><path d="M21 3L13 11l-4-4L2 14"/></svg>
      Active Jobs${badgeHtml(ongoing.length)}
    </button>
    <button class="stab-btn${defaultTab === 'done' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'done'}" data-stab="jq-done">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>
      Completed${badgeHtml(done.length)}
    </button>`;
  container.appendChild(tabBar);

  // ── Panes ──
  container.appendChild(makePane('pending', pending, 'No pending requests.'));
  container.appendChild(makePane('active',  ongoing, 'No active jobs right now.'));
  container.appendChild(makePane('done',    done,    'No completed jobs yet.'));

  // ── Tab switching ──
  tabBar.addEventListener('click', e => {
    const btn = e.target.closest('.stab-btn');
    if (!btn) return;
    const target = btn.dataset.stab;
    tabBar.querySelectorAll('.stab-btn').forEach(b => {
      b.classList.toggle('stab-btn--active', b === btn);
      b.setAttribute('aria-selected', b === btn ? 'true' : 'false');
    });
    container.querySelectorAll('.jq-tab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
  });

  wireArrivalFlows(container);
  revealAll(container);
}

/* ── Job Flow Modal ──────────────────────────────────────────────────────── */
function ensureJobModal() {
  if (document.getElementById('jq-modal')) return;
  const el = document.createElement('div');
  el.id = 'jq-modal';
  el.className = 'jq-modal-overlay';
  el.innerHTML = `<div class="jq-modal-box" role="dialog" aria-modal="true"><div class="jq-modal-inner"></div></div>`;
  document.body.appendChild(el);
  el.addEventListener('click', e => { if (e.target === el) closeJobModal(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeJobModal(); });
}
function openJobModal(html) {
  ensureJobModal();
  const overlay = document.getElementById('jq-modal');
  overlay.querySelector('.jq-modal-inner').innerHTML = html;
  overlay.classList.add('is-open');
  document.body.style.overflow = 'hidden';
}
function closeJobModal() {
  const overlay = document.getElementById('jq-modal');
  if (!overlay) return;
  overlay.classList.remove('is-open');
  document.body.style.overflow = '';
}

/* ── Progress Stepper ────────────────────────────────────────────────────── */
function buildStepperHtml(localState) {
  const steps = ['Accepted', 'En Route', 'Arrived', 'Working', 'Done'];
  const idx   = { accepted: 0, 'en-route': 1, arrived: 2, 'in-progress': 3, 'complete-confirm': 3, done: 4 };
  const cur   = idx[localState] ?? 0;
  const checkSvg = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`;
  
  return `
    <div class="jq-stepper-container">
      <div class="jq-stepper">
        ${steps.map((label, i) => {
          const done   = i < cur;
          const active = i === cur;
          let stateClass = '';
          if (done) stateClass = 'is-done';
          else if (active) stateClass = 'is-active';
          
          return `
            <div class="jq-step ${stateClass}">
              <div class="jq-step__indicator">
                ${done ? checkSvg : `<span>${i + 1}</span>`}
              </div>
              <span class="jq-step__label">${label}</span>
            </div>
            ${i < steps.length - 1 ? `<div class="jq-step-line ${done ? 'is-done' : ''}"></div>` : ''}
          `;
        }).join('')}
      </div>
    </div>
  `;
}

/* ─────────────────────────────────────────────────────────────────────────── */
function buildJobCard(b, _t) {
  const id       = b._id;
  const shortId  = id.slice(-6).toUpperCase();
  const service  = b.serviceName || b.service?.title || b.serviceCategory || 'Service';
  const badge    = (b.serviceCategory || b.service?.category || 'service').replace(/_/g,' ').toUpperCase();
  const customer = b.user?.name  || '—';
  const phone    = b.user?.phone || '';
  const address  = b.address || '—';
  const mapsUrl  = `https://maps.google.com/?q=${encodeURIComponent(address)}`;
  const date     = b.scheduledDate
    ? new Date(b.scheduledDate).toLocaleDateString('en-US', { weekday:'short', day:'numeric', month:'short' })
    : '—';
  const time    = b.scheduledTime || '';
  const price   = b.totalPrice != null ? `${Number(b.totalPrice).toLocaleString('en-US')} EGP` : '—';
  const payment = b.paymentMethod === 'cash' ? 'Cash' : 'Credit Card';
  const pin     = b.pin || '';
  const desc    = b.description ? `<p class="jq-premium-desc">${b.description}</p>` : '';

  const statusCfg = {
    pending:     { label:'Pending Acceptance', dot:'amber'  },
    accepted:    { label:'Accepted',           dot:'blue'   },
    in_progress: { label:'In Progress',        dot:'purple' },
    completed:   { label:'Completed',          dot:'green'  },
    cancelled:   { label:'Cancelled',          dot:'grey'   },
    rejected:    { label:'Declined',           dot:'grey'   },
  };
  const { label: statusLabel, dot: dotColor } = statusCfg[b.status] || { label: b.status, dot:'grey' };
  const isActive = ['accepted','in_progress'].includes(b.status);

  let flowHtml = '';
  if (b.status === 'pending') {
    flowHtml = `
      <div class="jq-flow" data-booking-id="${id}" data-pin="${pin}"
        data-customer="${customer}" data-address="${address}"
        data-date="${date}" data-time="${time}" data-price="${price}" data-payment="${payment}" data-service="${service}">
        <div class="jq-section" data-section="pending">
          <div class="jq-premium-actions">
            <button class="btn-premium btn-premium--primary" data-flow-action="accept">
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
              See Details
            </button>
            <button class="btn-premium btn-premium--danger-outline" data-flow-action="decline">
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              Decline
            </button>
          </div>
        </div>
      </div>`;
  } else if (b.status === 'accepted' || b.status === 'in_progress') {
    const phoneRow = phone
      ? `<div class="jq-meta-row"><span>Phone</span><a href="tel:${phone}" class="jq-phone-link">${phone}</a></div>`
      : '';
    flowHtml = `
      <div class="jq-flow" data-booking-id="${id}" data-pin="${pin}" data-customer="${customer}" data-address="${address}">
        <div class="jq-section" data-section="accepted">
          <div class="jq-accepted-action-bar">
            <div class="jq-nav-info">
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="12" r="3"/></svg>
              <span class="truncate">${address}</span>
            </div>
            <div class="jq-accepted-actions">
              <a class="btn-premium btn-premium--accent btn-premium--sm" href="${mapsUrl}" target="_blank" rel="noopener">Navigate</a>
              <button class="btn-premium btn-premium--primary btn-premium--sm" data-flow-action="on-my-way">
                I'm On My Way
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
              </button>
            </div>
          </div>
        </div>
        <div class="jq-section" data-section="en-route" hidden>
          <div class="jq-accepted-action-bar">
            <div class="jq-nav-info">
              <div class="jq-pulse-indicator jq-pulse-indicator--sm">
                <span class="pulse-dot"></span>
                <span class="pulse-ring"></span>
              </div>
              <span class="jq-enroute-label">EN ROUTE</span>
              <span class="jq-enroute-sep">·</span>
              <span class="truncate">${address}</span>
            </div>
            <div class="jq-accepted-actions">
              <a class="btn-premium btn-premium--blue btn-premium--sm" href="${mapsUrl}" target="_blank" rel="noopener">Maps</a>
              <button class="btn-premium btn-premium--primary btn-premium--sm" data-flow-action="arrived">
                I've Arrived
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="12" r="3"/></svg>
              </button>
            </div>
          </div>
        </div>
        <div class="jq-section" data-section="arrived" hidden>
          <div class="jq-premium-pin-card">
            <div class="jq-pin-icon-box">
              <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
            </div>
            <div class="jq-pin-content">
              <h4>Customer Verification</h4>
              <p>Ask <strong>${customer}</strong> for their 4-digit PIN</p>
            </div>
          </div>
          <div class="jq-premium-pin-group" data-pin-group>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
          </div>
          <p class="jq-pin-error" hidden>Incorrect PIN — please try again.</p>
          <div class="jq-flow-footer">
            <button class="btn-premium btn-premium--amber" data-flow-action="start-job">
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
              Verify &amp; Start Job
            </button>
          </div>
        </div>
        <div class="jq-section" data-section="in-progress" hidden>
          <div class="jq-premium-timer-card">
            <div class="jq-timer-header">
              <div class="jq-timer-live-dot"></div>
              <div class="jq-timer-text" id="timer-${id}">00:00:00</div>
              <span class="jq-timer-pill">LIVE</span>
            </div>
            <div class="jq-timer-details">
              <div class="detail-row"><span>Customer</span><strong>${customer}</strong></div>
              <div class="detail-row"><span>Service</span><strong>${service}</strong></div>
              <div class="detail-row"><span>Payout</span><strong class="text-emerald">${price}</strong></div>
              ${phoneRow}
            </div>
          </div>
          <div class="jq-flow-footer">
            <button class="btn-premium btn-premium--emerald" data-flow-action="complete">
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              Mark Job Complete
            </button>
          </div>
        </div>
        <div class="jq-section" data-section="complete-confirm" hidden>
          <div class="jq-premium-confirm-card">
            <div class="jq-confirm-icon-box">
              <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
            </div>
            <div class="jq-confirm-content">
              <h4>Confirm Completion</h4>
              <p>Ensure all work is finished before submitting.</p>
            </div>
          </div>
          <div class="jq-notes-field">
            <label>Notes for customer <span>(optional)</span></label>
            <textarea class="jq-notes-textarea" placeholder="Describe the work done..." maxlength="400" rows="3"></textarea>
          </div>
          <div class="jq-premium-actions">
            <button class="btn-premium btn-premium--ghost" data-flow-action="back-to-inprogress">Back</button>
            <button class="btn-premium btn-premium--primary" data-flow-action="submit-complete">Submit Completion</button>
          </div>
        </div>
      </div>`;
  } else if (b.status === 'completed') {
    flowHtml = `
      <div class="jq-premium-completion">
        <div class="jq-completion-hero">
          <div class="jq-check-blob">
            <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
          </div>
          <div class="jq-completion-text">
            <h4>Job Completed</h4>
            <p>${customer}</p>
          </div>
        </div>
        <div class="jq-completion-value">${price}</div>
      </div>`;
  } else {
    flowHtml = `<div class="jq-premium-status-note">${statusLabel}</div>`;
  }

  const article = document.createElement('article');
  article.className = `jq-premium-card status-${b.status}`.trim();
  article.id = `jq-${id}`;
  article.setAttribute('data-reveal', '');
  article.dataset.status = b.status;

  const serviceIconHtml = `
    <div class="jq-premium-icon-wrap jq-premium-icon-wrap--${dotColor}">
      <svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
    </div>
  `;

  article.innerHTML = `
    <div class="jq-premium-card__header">
      <div class="jq-header-left">
        <span class="jq-premium-badge">${badge}</span>
        <span class="jq-premium-id">#${shortId}</span>
      </div>
      <div class="jq-premium-status jq-status--${dotColor}">
        <span class="status-dot"></span>
        <span class="status-label">${statusLabel}</span>
      </div>
    </div>
    
    ${isActive ? `<div class="jq-premium-stepper-wrap" id="stepper-${id}">${buildStepperHtml(b.status === 'in_progress' ? 'in-progress' : 'accepted')}</div>` : ''}
    
    <div class="jq-premium-card__body">
      <div class="jq-body-main">
        ${serviceIconHtml}
        <div class="jq-body-content">
          <h3 class="jq-premium-name">${customer}</h3>
          <div class="jq-premium-meta">
            <div class="meta-item">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="12" r="3"/></svg>
              <span>${address}</span>
            </div>
            <div class="meta-chips">
              <span class="meta-chip">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
                ${date}${time ? ' · ' + time : ''}
              </span>
              <span class="meta-chip">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
                ${payment}
              </span>
            </div>
          </div>
          ${desc}
        </div>
      </div>
      <div class="jq-body-payout">
        <div class="payout-amount">${price}</div>
        <div class="payout-label">TOTAL PAYOUT</div>
      </div>
    </div>
    
    <div class="jq-premium-card__footer">
      ${flowHtml}
    </div>
  `;
  return article;
}

function wireArrivalFlows(container) {
  container.querySelectorAll('.jq-flow').forEach(flow => {
    const bookingId  = flow.dataset.bookingId;
    const correctPin = flow.dataset.pin;
    const storeKey   = `servio_flow_${bookingId}`;
    const timerKey   = `servio_timer_${bookingId}`;
    let timerInterval = null;

    /* ── Section visibility ── */
    function showSection(name) {
      flow.querySelectorAll('.jq-section').forEach(s => { s.hidden = true; });
      const target = flow.querySelector(`[data-section="${name}"]`);
      if (target) target.hidden = false;
      localStorage.setItem(storeKey, name);
      const stepperWrap = document.getElementById(`stepper-${bookingId}`);
      if (stepperWrap) stepperWrap.innerHTML = buildStepperHtml(name);
    }

    /* ── Timer (wall-clock based so refresh-safe) ── */
    function startTimer() {
      const el = document.getElementById(`timer-${bookingId}`);
      if (!el) return;
      clearInterval(timerInterval);
      let t0 = parseInt(localStorage.getItem(timerKey) || '0');
      if (!t0) { t0 = Date.now(); localStorage.setItem(timerKey, t0); }
      const tick = () => {
        const s = Math.floor((Date.now() - t0) / 1000);
        const h = String(Math.floor(s / 3600)).padStart(2,'0');
        const m = String(Math.floor((s % 3600) / 60)).padStart(2,'0');
        const sec = String(s % 60).padStart(2,'0');
        if (el) el.textContent = `${h}:${m}:${sec}`;
      };
      tick();
      timerInterval = setInterval(tick, 1000);
    }

    /* ── Restore persisted state on load ── */
    const stored = localStorage.getItem(storeKey);
    if (stored) {
      showSection(stored);
      if (stored === 'in-progress') startTimer();
    }

    /* ── PIN box auto-advance + backspace ── */
    const pinGroup = flow.querySelector('[data-pin-group]');
    if (pinGroup) {
      const boxes = [...pinGroup.querySelectorAll('.jq-pin-box')];
      boxes.forEach((box, i) => {
        box.addEventListener('input', e => {
          const v = e.target.value.replace(/\D/g, '');
          e.target.value = v;
          box.classList.toggle('is-filled', !!v);
          if (v && i < boxes.length - 1) boxes[i + 1].focus();
        });
        box.addEventListener('keydown', e => {
          if (e.key === 'Backspace' && !box.value && i > 0) boxes[i - 1].focus();
        });
        box.addEventListener('paste', e => {
          e.preventDefault();
          const digits = (e.clipboardData.getData('text') || '').replace(/\D/g,'').slice(0,4);
          [...digits].forEach((d, j) => { if (boxes[j]) boxes[j].value = d; });
          boxes[Math.min(digits.length, boxes.length - 1)]?.focus();
        });
      });
    }

    /* ── Accept modal ── */
    function showAcceptModal() {
      const { service, customer, address, date, time, price, payment } = flow.dataset;
      const circumference = 2 * Math.PI * 16; // r=16 → ~100.5
      openJobModal(`
        <div class="jqm-accept">
          <div class="jqm-accept-head">
            <div class="jqm-countdown-wrap">
              <svg class="jqm-countdown-svg" viewBox="0 0 40 40" width="64" height="64">
                <circle cx="20" cy="20" r="16" fill="none" stroke="var(--dash-card-border)" stroke-width="3"/>
                <circle cx="20" cy="20" r="16" fill="none" stroke="var(--color-accent)" stroke-width="3"
                  stroke-dasharray="${circumference.toFixed(2)}"
                  stroke-dashoffset="0" stroke-linecap="round"
                  transform="rotate(-90 20 20)" id="accept-ring"/>
              </svg>
              <span class="jqm-countdown-num" id="accept-secs">30</span>
            </div>
            <div class="jqm-accept-title">
              <h2>New Job Request</h2>
              <p>Review details before accepting</p>
            </div>
            <button class="jqm-close-btn" data-modal-close aria-label="Close">
              <svg viewBox="0 0 20 20" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="5" x2="15" y2="15"/><line x1="15" y1="5" x2="5" y2="15"/></svg>
            </button>
          </div>
          <div class="jqm-detail-list">
            <div class="jqm-row"><span>Service</span><strong>${service || '—'}</strong></div>
            <div class="jqm-row"><span>Customer</span><strong>${customer || '—'}</strong></div>
            <div class="jqm-row"><span>Address</span><strong>${address || '—'}</strong></div>
            <div class="jqm-row"><span>Date</span><strong>${date || '—'}${time ? ' · ' + time : ''}</strong></div>
            <div class="jqm-row jqm-row--payout"><span>Payout</span><strong>${price || '—'}</strong></div>
            <div class="jqm-row"><span>Payment</span><strong>${payment || '—'}</strong></div>
          </div>
          <div class="jqm-actions">
            <button class="jqm-btn-pass" id="modal-pass-btn">Pass on this job</button>
            <button class="jqm-btn-confirm-accept" id="modal-accept-btn">
              <svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="4,10 8,14 16,6"/></svg>
              Accept Job
            </button>
          </div>
        </div>`);

      /* countdown ring */
      let secs = 30;
      const ring  = document.getElementById('accept-ring');
      const secsEl = document.getElementById('accept-secs');
      const cdInterval = setInterval(() => {
        secs--;
        if (secsEl) secsEl.textContent = secs;
        if (ring)   ring.style.strokeDashoffset = String((circumference * (1 - secs / 30)).toFixed(2));
        if (secs <= 0) { clearInterval(cdInterval); closeJobModal(); }
      }, 1000);

      document.getElementById('modal-accept-btn')?.addEventListener('click', async () => {
        clearInterval(cdInterval);
        const btn = document.getElementById('modal-accept-btn');
        if (btn) { btn.disabled = true; btn.textContent = 'Accepting…'; }
        try {
          await updateBookingStatus(bookingId, 'accepted');
          closeJobModal();
          const card = flow.closest('.jq-premium-card');
          if (card) {
            card.classList.add('jq-premium-card--accepted');
            const statusEl = card.querySelector('.jq-premium-status');
            if (statusEl) {
              statusEl.innerHTML = `<span class="status-dot"></span><span>Accepted</span>`;
              statusEl.className = 'jq-premium-status jq-status--blue';
            }
            if (!document.getElementById(`stepper-${bookingId}`)) {
              const sw = document.createElement('div');
              sw.className = 'jq-premium-stepper-wrap';
              sw.id = `stepper-${bookingId}`;
              sw.innerHTML = buildStepperHtml('accepted');
              card.querySelector('.jq-premium-card__body')?.before(sw);
            }
          }
          showSection('accepted');
          showToast('Job accepted! Head to the customer location.', 'success');
        } catch (err) {
          closeJobModal();
          showToast(err?.message || 'Failed to accept job.', 'error');
        }
      });

      document.getElementById('modal-pass-btn')?.addEventListener('click', () => {
        clearInterval(cdInterval);
        closeJobModal();
        showDeclineModal();
      });

      document.querySelector('#jq-modal [data-modal-close]')?.addEventListener('click', () => {
        clearInterval(cdInterval);
        closeJobModal();
      });
    }

    /* ── Decline modal ── */
    function showDeclineModal() {
      openJobModal(`
        <div class="jqm-decline">
          <div class="jqm-decline-icon">
            <svg viewBox="0 0 48 48" width="52" height="52" fill="none" stroke="#EF4444" stroke-width="2"><circle cx="24" cy="24" r="20"/><line x1="15" y1="15" x2="33" y2="33"/><line x1="33" y1="15" x2="15" y2="33"/></svg>
          </div>
          <h2>Decline This Job?</h2>
          <p>Select a reason — this helps improve job matching for you.</p>
          <select class="jqm-reason-select" id="decline-reason">
            <option value="">Select a reason…</option>
            <option value="busy">I'm busy at this time</option>
            <option value="too_far">Location is too far</option>
            <option value="outside_skills">Outside my skill set</option>
            <option value="emergency">Personal emergency</option>
            <option value="other">Other</option>
          </select>
          <div class="jqm-actions">
            <button class="jqm-btn-keep" id="decline-cancel-btn">Keep Job</button>
            <button class="jqm-btn-confirm-decline" id="decline-confirm-btn" disabled>Decline Job</button>
          </div>
        </div>`);

      document.getElementById('decline-reason')?.addEventListener('change', e => {
        const b = document.getElementById('decline-confirm-btn');
        if (b) b.disabled = !e.target.value;
      });

      document.getElementById('decline-cancel-btn')?.addEventListener('click', closeJobModal);

      document.getElementById('decline-confirm-btn')?.addEventListener('click', async () => {
        const btn = document.getElementById('decline-confirm-btn');
        if (btn) { btn.disabled = true; btn.textContent = 'Declining…'; }
        try {
          await updateBookingStatus(bookingId, 'rejected');
          closeJobModal();
          const card = flow.closest('.jq-premium-card');
          if (card) {
            card.style.transition = 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
            card.style.opacity = '0';
            card.style.transform = 'scale(0.95) translateY(10px)';
            setTimeout(() => card.remove(), 420);
          }
          localStorage.removeItem(storeKey);
          showToast('Job declined.', 'info');
        } catch (err) {
          closeJobModal();
          showToast(err?.message || 'Failed to decline.', 'error');
        }
      });
    }

    /* ── Main click handler ── */
    flow.addEventListener('click', async e => {
      const btn = e.target.closest('[data-flow-action]');
      if (!btn) return;
      const action = btn.dataset.flowAction;

      if (action === 'accept') { showAcceptModal(); return; }

      if (action === 'decline') { showDeclineModal(); return; }

      if (action === 'on-my-way') {
        showSection('en-route');
        showToast('Customer notified — you\'re on your way!', 'info');
        return;
      }

      if (action === 'arrived') {
        showSection('arrived');
        setTimeout(() => flow.querySelector('.jq-pin-box')?.focus(), 80);
        showToast('Ask the customer for their 4-digit PIN.', 'info');
        return;
      }

      if (action === 'start-job') {
        const boxes  = [...flow.querySelectorAll('.jq-pin-box')];
        const entered = boxes.map(b => b.value).join('');
        const errEl  = flow.querySelector('.jq-pin-error');
        if (correctPin && entered !== correctPin) {
          const pg = flow.querySelector('[data-pin-group]');
          if (pg) { pg.classList.remove('jq-pin--shake'); void pg.offsetWidth; pg.classList.add('jq-pin--shake'); }
          if (errEl) errEl.hidden = false;
          boxes.forEach(b => { b.value = ''; b.classList.remove('is-filled'); });
          boxes[0]?.focus();
          return;
        }
        if (errEl) errEl.hidden = true;
        btn.disabled = true; btn.textContent = 'Starting…';
        try {
          await updateBookingStatus(bookingId, 'in_progress');
          const card = flow.closest('.jq-premium-card');
          if (card) {
            card.classList.add('jq-premium-card--in-progress');
            const statusEl = card.querySelector('.jq-premium-status');
            if (statusEl) {
              statusEl.innerHTML = `<span class="status-dot"></span><span>In Progress</span>`;
              statusEl.className = 'jq-premium-status jq-status--purple';
            }
          }
          showSection('in-progress');
          startTimer();
          showToast('Job started! Timer is running.', 'success');
        } catch (err) {
          btn.disabled = false; btn.textContent = 'Verify & Start Job';
          showToast(err?.message || 'Failed to start job.', 'error');
        }
        return;
      }

      if (action === 'complete') {
        showSection('complete-confirm');
        return;
      }

      if (action === 'back-to-inprogress') {
        showSection('in-progress');
        startTimer();
        return;
      }

      if (action === 'submit-complete') {
        const notes = flow.querySelector('.jq-notes-textarea')?.value?.trim() || '';
        btn.disabled = true; btn.textContent = 'Submitting…';
        try {
          await updateBookingStatus(bookingId, 'completed');
          clearInterval(timerInterval);
          const duration = document.getElementById(`timer-${bookingId}`)?.textContent || '—';
          const customer = flow.dataset.customer || '—';
          const payoutAmount = flow.closest('.jq-premium-card')?.querySelector('.payout-amount')?.textContent?.trim() || '—';
          localStorage.removeItem(storeKey);
          localStorage.removeItem(timerKey);

          const card = flow.closest('.jq-premium-card');
          if (card) {
            card.className = 'jq-premium-card jq-premium-card--completed jq-premium-card--done-anim is-visible';
            card.removeAttribute('data-status');
            card.innerHTML = `
              <div class="jq-done-banner">
                <div class="jq-done-icon">
                  <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" stroke-width="3"><polyline points="4,12 9,17 20,6"/></svg>
                </div>
                <div class="jq-done-info">
                  <p class="jq-done-label">Job Completed Successfully</p>
                  <p class="jq-done-sub">${customer} · ${duration}</p>
                </div>
                <div class="jq-done-earnings">${payoutAmount}</div>
              </div>
              ${notes ? `<div class="jq-done-notes">
                <div class="jq-notes-label">Service Notes:</div>
                <p>${notes}</p>
              </div>` : ''}`;

            const doneSection = document.getElementById('jq-completed-section');
            if (doneSection) {
              doneSection.style.display = 'block';
              doneSection.querySelector('.jq-completed-list')?.prepend(card);
            }
          }
          showToast('Job complete! Earnings added to your wallet. 🎉', 'success');
        } catch (err) {
          btn.disabled = false; btn.textContent = 'Submit Completion';
          showToast(err?.message || 'Failed to complete job.', 'error');
        }
        return;
      }
    });
  });
}

// ── Populate overview incoming requests ──────────────────────────────────────
function populateOverviewIncoming(pendingBookings) {
  const container = document.getElementById('overview-incoming-list');
  if (!container) return;
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  const preview = pendingBookings.slice(0, 3);
  if (preview.length === 0) {
    container.innerHTML = `<p style="color:var(--color-text-muted);font-size:0.85rem;padding:12px 0;">${_t('tech_no_pending_requests') || 'No pending requests right now.'}</p>`;
    return;
  }

  container.innerHTML = preview.map(b => {
    const service  = b.service?.title || b.service?.category || 'Service';
    const customer = b.user?.name || '—';
    const address  = b.address || '—';
    const price    = b.totalPrice != null ? `~EGP ${Number(b.totalPrice).toLocaleString('en-US')}` : '—';
    return `
      <div class="job-card-v2">
        <div class="job-card-v2__icon">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#9A8C73" stroke-width="2" aria-hidden="true"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
        </div>
        <div class="job-card-v2__body">
          <h4 class="job-card-v2__title">${service}</h4>
          <p class="job-card-v2__meta">
            <span>${customer}</span><span class="job-card-v2__sep">·</span>
            <span>${address}</span><span class="job-card-v2__sep">·</span>
            <span class="job-card-v2__price">${price}</span>
          </p>
        </div>
        <span class="badge badge--pending">${_t('status_new') || 'New'}</span>
      </div>`;
  }).join('');
}

// ── Populate overview upcoming schedule ──────────────────────────────────────
function populateOverviewSchedule(bookings) {
  const container = document.getElementById('overview-schedule-list');
  if (!container) return;
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  const now = new Date();
  const upcoming = bookings
    .filter(b => {
      const d = new Date(b.scheduledDate);
      return d >= now && (b.status === 'pending' || b.status === 'accepted' || b.status === 'in_progress');
    })
    .sort((a, b) => new Date(a.scheduledDate) - new Date(b.scheduledDate))
    .slice(0, 4);

  if (upcoming.length === 0) {
    container.innerHTML = `<p style="color:var(--color-text-muted);font-size:0.85rem;padding:12px 0;">${_t('tech_no_upcoming') || 'No upcoming jobs scheduled.'}</p>`;
    return;
  }

  const MONTHS = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
  container.innerHTML = upcoming.map(b => {
    const d       = new Date(b.scheduledDate);
    const day     = String(d.getDate()).padStart(2, '0');
    const month   = MONTHS[d.getMonth()];
    const service = b.service?.title || b.service?.category || 'Service';
    const time    = b.scheduledTime || '—';
    const loc     = b.address ? b.address.split(',')[0] : '—';
    return `
      <div class="dash-schedule-item">
        <div class="dash-schedule-date">
          <span class="dash-schedule-day">${day}</span>
          <span class="dash-schedule-month">${month}</span>
        </div>
        <div class="dash-schedule-content">
          <h4 class="dash-schedule-title">${service}</h4>
          <p class="dash-schedule-info">
            <span class="dash-schedule-time">${time}</span>
            <span class="dash-schedule-sep">·</span>
            <span class="dash-schedule-loc">${loc}</span>
          </p>
        </div>
      </div>`;
  }).join('');
}

// ── Populate earnings panel ───────────────────────────────────────────────────
function populateEarnings(allBookings, completed, monthEarnings, lastMonthEarnings, cashCompleted, outstandingAmount) {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  // Summary stats
  const totalEarned = completed.reduce((s, b) => s + (b.totalPrice || 0), 0);
  const earnTotalEl = document.getElementById('earn-total');
  if (earnTotalEl) earnTotalEl.textContent = `${totalEarned.toLocaleString('en-US')} EGP`;

  const earnMonthEl = document.getElementById('earn-month');
  if (earnMonthEl) earnMonthEl.textContent = `${monthEarnings.toLocaleString('en-US')} EGP`;

  const earnMonthSubEl = document.getElementById('earn-month-sub');
  if (earnMonthSubEl) {
    const delta = monthEarnings - lastMonthEarnings;
    const isUp = delta >= 0;
    earnMonthSubEl.innerHTML = `
      <span class="${isUp ? 'jq-earn-trend-up' : 'jq-earn-trend-down'}">
        ${isUp ? '↑' : '↓'} EGP ${Math.abs(delta).toLocaleString('en-US')}
      </span> vs last month`;
  }

  const earnCompletedEl = document.getElementById('earn-completed-count');
  if (earnCompletedEl) earnCompletedEl.textContent = completed.length;

  // Outstanding cash balance
  const liabilityAmountEl = document.getElementById('liabilityAmount');
  if (liabilityAmountEl) liabilityAmountEl.innerHTML = `${outstandingAmount.toLocaleString('en-US')} <span>EGP</span>`;

  // Liability items — last 5 cash completed bookings
  const liabilityList = document.getElementById('liability-items-list');
  if (liabilityList) {
    if (cashCompleted.length === 0) {
      liabilityList.innerHTML = `<p style="color:var(--color-text-muted);font-size:0.85rem;padding:8px 0;">${_t('tech_no_outstanding') || 'No outstanding cash balance.'}</p>`;
    } else {
      liabilityList.innerHTML = cashCompleted.slice(0, 5).map(b => {
        const shortId = b._id.slice(-6).toUpperCase();
        const amount  = b.totalPrice != null ? `${Number(b.totalPrice).toLocaleString('en-US')} EGP` : '—';
        return `
          <div class="jq-premium-liability-row">
            <div class="jq-premium-liability-info">
              <span class="jq-premium-liability-id">#${shortId}</span>
              <span class="jq-premium-liability-tag">${_t('tech_commission') || 'Commission'}</span>
            </div>
            <span class="jq-premium-liability-val">${amount}</span>
          </div>`;
      }).join('');
    }
  }

  // Show warning if outstanding > 2000
  const liabilityWarning = document.getElementById('liabilityWarning');
  if (liabilityWarning) liabilityWarning.hidden = outstandingAmount < 2000;

  // Recent jobs list
  const recentList = document.getElementById('earnings-recent-list');
  if (recentList) {
    const recentCompleted = completed
      .sort((a, b) => new Date(b.scheduledDate || b.updatedAt) - new Date(a.scheduledDate || a.updatedAt))
      .slice(0, 10);

    if (recentCompleted.length === 0) {
      recentList.innerHTML = `<p style="color:var(--color-text-muted);font-size:0.85rem;padding:12px 0;">${_t('tech_no_completed_jobs') || 'No completed jobs yet.'}</p>`;
    } else {
      recentList.innerHTML = recentCompleted.map(b => {
        const service = b.service?.title || b.service?.category || 'Service';
        const dateStr = b.scheduledDate
          ? new Date(b.scheduledDate).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })
          : '—';
        const amount = b.totalPrice != null ? `+${Number(b.totalPrice).toLocaleString('en-US')} EGP` : '—';
        return `
          <div class="jq-premium-earn-row" data-reveal>
            <div class="jq-earn-row-left">
              <div class="jq-earn-row-icon">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
              </div>
              <div class="jq-earn-row-info">
                <h4>${service}</h4>
                <p>${dateStr}</p>
              </div>
            </div>
            <div class="jq-earn-row-amount">${amount}</div>
          </div>`;
      }).join('');
    }
  }

  // Next settlement date
  const settlementEl = document.getElementById('liability-settlement-date');
  if (settlementEl) {
    const now = new Date();
    const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    const settlementStr = lastDay.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });
    settlementEl.textContent = settlementStr;
  }
}

// ── Populate notifications from booking activity ──────────────────────────────
function populateNotifications(bookings) {
  const list = document.getElementById('notif-items-list');
  if (!list) return;
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  // Generate notifications from recent booking events
  const notifs = [];
  const now = new Date();

  bookings.slice(0, 20).forEach(b => {
    const service = b.service?.title || b.service?.category || 'Service';
    const customer = b.user?.name || '—';
    const updated = new Date(b.updatedAt || b.createdAt);
    const ageMs = now - updated;
    const ageMinutes = Math.floor(ageMs / 60000);
    const ageHours   = Math.floor(ageMs / 3600000);
    const ageDays    = Math.floor(ageMs / 86400000);

    let timeStr;
    if (ageMinutes < 60)   timeStr = `${ageMinutes || 1} min ago`;
    else if (ageHours < 24) timeStr = `${ageHours} hr ago`;
    else if (ageDays === 1) timeStr = 'Yesterday';
    else                    timeStr = `${ageDays} days ago`;

    let icon, msg, isUnread = false;
    if (b.status === 'pending') {
      icon = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`;
      msg = `New job request: <strong>${service}</strong> from ${customer}`;
      isUnread = ageMinutes < 60;
    } else if (b.status === 'completed') {
      icon = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>`;
      const amount = b.totalPrice != null ? `EGP ${Number(b.totalPrice).toLocaleString('en-US')}` : '';
      msg = amount ? `Payment of <strong>${amount}</strong> received for <strong>${service}</strong>` : `Job completed: <strong>${service}</strong>`;
    } else if (b.status === 'cancelled') {
      icon = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`;
      msg = `Booking cancelled: <strong>${service}</strong> by ${customer}`;
    } else {
      return; // skip accepted/in_progress in notifications
    }

    notifs.push({ icon, msg, timeStr, isUnread });
  });

  if (notifs.length === 0) {
    list.innerHTML = '';
    const emptyEl = document.getElementById('notif-empty');
    if (emptyEl) emptyEl.hidden = false;
    updateTopbarBadge(0);
    return;
  }

  list.innerHTML = notifs.map((n, i) => `
    <div class="notif-item${n.isUnread ? ' is-unread' : ''}" data-notif-id="live-${i}">
      <span class="notif-item__dot"></span>
      <span class="notif-item__icon notif-item__icon--job">${n.icon}</span>
      <div class="notif-item__body">
        <p class="notif-item__msg">${n.msg}</p>
        <span class="notif-item__time">${n.timeStr}</span>
      </div>
    </div>`).join('');

  const unreadCount = notifs.filter(n => n.isUnread).length;
  updateTopbarBadge(unreadCount);
}

/* ── Fix 6: Password show/hide toggles ─────────────────── */
function initPasswordToggles() {
  document.querySelectorAll('.btn-toggle-password').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset.target;
      const input = document.getElementById(targetId);
      if (!input) return;
      const isHidden = input.type === 'password';
      input.type = isHidden ? 'text' : 'password';
      const openIcon = btn.querySelector('.eye-icon--open');
      const closedIcon = btn.querySelector('.eye-icon--closed');
      if (openIcon) openIcon.style.display = isHidden ? 'none' : '';
      if (closedIcon) closedIcon.style.display = isHidden ? '' : 'none';
      const showLabel = typeof window.t === 'function' ? window.t('pw_show') : 'Show password';
      const hideLabel = typeof window.t === 'function' ? window.t('pw_hide') : 'Hide password';
      btn.setAttribute('aria-label', isHidden ? hideLabel : showLabel);
    });
  });
}

/* ── Fix 7: Settings validation ─────────────────────────── */
function initSettingsValidation() {
  const emailInput = document.getElementById('s-email');
  const newPasswordInput = document.getElementById('s-new-password');
  const confirmPasswordInput = document.getElementById('s-confirm-password');

  function getContainer(input) {
    const wrap = input.closest('.input-password-wrap');
    return wrap ? wrap.parentElement : input.parentElement;
  }

  function setFieldState(input, valid, message) {
    input.classList.toggle('is-valid', valid);
    input.classList.toggle('is-invalid', !valid);
    const container = getContainer(input);
    let errorEl = container.querySelector('.field-error');
    if (!valid && message) {
      if (!errorEl) {
        errorEl = document.createElement('span');
        errorEl.className = 'field-error';
        container.appendChild(errorEl);
      }
      errorEl.textContent = message;
    } else if (errorEl) {
      errorEl.remove();
    }
  }

  function clearFieldState(input) {
    input.classList.remove('is-valid', 'is-invalid');
    const errorEl = getContainer(input).querySelector('.field-error');
    if (errorEl) errorEl.remove();
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (emailInput) {
    emailInput.addEventListener('blur', () => {
      const val = emailInput.value.trim();
      if (!val) { clearFieldState(emailInput); return; }
      if (emailRegex.test(val)) {
        setFieldState(emailInput, true, '');
      } else {
        setFieldState(emailInput, false, typeof window.t === 'function' ? window.t('err_invalid_email') : 'Please enter a valid email address.');
      }
    });
    emailInput.addEventListener('input', () => {
      if (emailInput.classList.contains('is-invalid') && emailRegex.test(emailInput.value.trim())) {
        setFieldState(emailInput, true, '');
      }
    });
  }

  const mismatchMsg = () => typeof window.t === 'function' ? window.t('err_pw_mismatch') : 'Passwords do not match.';

  function validatePasswordMatch(showError = true) {
    if (!newPasswordInput || !confirmPasswordInput) return;
    const newVal     = newPasswordInput.value;
    const confirmVal = confirmPasswordInput.value;
    if (!newVal && !confirmVal) {
      clearFieldState(confirmPasswordInput);
      return;
    }
    if (!confirmVal) { clearFieldState(confirmPasswordInput); return; }
    if (newVal === confirmVal) {
      setFieldState(confirmPasswordInput, true, '');
    } else if (showError) {
      setFieldState(confirmPasswordInput, false, mismatchMsg());
    } else {
      // While typing: clear the error if it was previously shown, don't add a new one
      clearFieldState(confirmPasswordInput);
    }
  }

  if (confirmPasswordInput) {
    // Show error only after the user leaves the field
    confirmPasswordInput.addEventListener('blur', () => validatePasswordMatch(true));
    // While typing: only clear the error when they've matched; never add new error mid-type
    confirmPasswordInput.addEventListener('input', () => validatePasswordMatch(false));
  }
  if (newPasswordInput) {
    newPasswordInput.addEventListener('input', () => {
      if (confirmPasswordInput?.value) validatePasswordMatch(false);
    });
  }
}

function initSettingsForm() {
  const form = document.querySelector('[data-settings-form]');
  if (!form) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';

  // ── Photo upload ──────────────────────────────────────────
  const changePhotoBtn   = document.getElementById('btn-change-photo');
  const photoUploadInput = document.getElementById('photo-upload-input');
  const preview          = document.querySelector('[data-avatar-preview]');

  if (changePhotoBtn && photoUploadInput) {
    changePhotoBtn.addEventListener('click', () => photoUploadInput.click());

    photoUploadInput.addEventListener('change', async () => {
      const file = photoUploadInput.files[0];
      if (!file) return;

      if (file.size > 2 * 1024 * 1024) {
        showToast(_t('toast_photo_error') || 'Image must be under 2 MB.', 'error');
        photoUploadInput.value = '';
        return;
      }

      // Instant local preview
      const reader = new FileReader();
      reader.onload = (e) => {
        if (preview) {
          preview.innerHTML = `<img src="${e.target.result}" alt="Profile photo" style="${imgStyle}" />`;
          preview.classList.remove('avatar-required');
          const hint = preview.closest('.settings-avatar-wrap')?.nextElementSibling;
          if (hint?.classList.contains('avatar-required-hint')) hint.remove();
        }
        const topbar = document.getElementById('topbar-avatar');
        if (topbar) topbar.innerHTML = `<img src="${e.target.result}" alt="Profile photo" style="${imgStyle}" />`;
        // Cache locally so photo persists across reloads before save
        try { localStorage.setItem('servio_avatar_cache', e.target.result); } catch (_) {}
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
      } finally {
        changePhotoBtn.disabled = false;
        changePhotoBtn.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg><span data-i18n="cust_change_photo">${_t('cust_change_photo') || 'Change Photo'}</span>`;
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const currentSession = getSession();
    const photoUrl = _pendingPhotoUrl || currentSession?.profileImage || null;

    // Mandatory guard — technicians must have a profile photo
    if (!photoUrl) {
      showToast(_t('toast_photo_required') || 'Please add a profile photo before saving.', 'error');
      if (preview) preview.classList.add('avatar-required');
      return;
    }

    const account = getAccount() || {};
    const passwordFields = new Set(['newPassword', 'confirmPassword']);
    document.querySelectorAll('[data-settings-field]').forEach(f => {
      if (!passwordFields.has(f.dataset.settingsField)) account[f.dataset.settingsField] = f.value;
    });
    localStorage.setItem('servio_account', JSON.stringify(account));

    try {
      await updateMe({
        name:         account.fullName || account.name || '',
        phone:        account.phone || '',
        profileImage: photoUrl,
      });

      if (currentSession) {
        if (account.fullName) currentSession.name = account.fullName;
        currentSession.profileImage = photoUrl;
        localStorage.setItem('servio_session', JSON.stringify(currentSession));
      }
      if (_pendingPhotoUrl) _pendingPhotoUrl = null;
      // Keep servio_avatar_cache — server may return a local path that browsers can't load

      showToast(_t('toast_settings_saved') || 'Your changes have been saved.', 'success');
    } catch (err) {
      showToast(err.message || 'Failed to save settings.', 'error');
    }
  });

  // Delete account button — opens confirmation modal
  const deleteBtn = document.getElementById('btn-delete-account');
  if (deleteBtn) {
    deleteBtn.addEventListener('click', () => {
      const modal = document.getElementById('modal-delete-account');
      if (modal) modal.style.display = 'flex';
    });
  }

  const saveScheduleBtn = document.getElementById('save-schedule');
  const scheduleFeedback = document.getElementById('avail-schedule-feedback');
  if (saveScheduleBtn) {
    saveScheduleBtn.addEventListener('click', async () => {
      const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
      const slots = [];
      let hasTimeError = false;
      document.querySelectorAll('#avail-schedule .avail-day-row').forEach(row => {
        const dayKey  = row.dataset.day;
        const isOff   = row.classList.contains('is-off');
        if (isOff) return;
        const fromSel = row.querySelector(`#avail-from-${dayKey}`);
        const toSel   = row.querySelector(`#avail-to-${dayKey}`);
        if (!fromSel || !toSel) return;
        const from = fromSel.value;
        const to   = toSel.value;
        if (to <= from) {
          toSel.classList.add('is-error');
          hasTimeError = true;
          return;
        }
        toSel.classList.remove('is-error');
        slots.push({ day: dayKey, from, to });
      });

      if (hasTimeError) {
        showToast(_t('toast_avail_time_error') || 'End time must be after start time.', 'error');
        return;
      }

      const origLabel = saveScheduleBtn.querySelector('.avail-save-btn__label');
      if (origLabel) origLabel.textContent = _t('tech_saving') || 'Saving…';
      const iconSpan = saveScheduleBtn.querySelector('.avail-save-btn__icon');
      if (iconSpan) iconSpan.innerHTML = '<span class="spinner"></span>';
      saveScheduleBtn.disabled = true;
      if (scheduleFeedback) scheduleFeedback.hidden = true;

      try {
        await updateAvailability(slots);
        try {
          const acc = JSON.parse(localStorage.getItem('servio_account') || '{}');
          acc.availability = slots;
          localStorage.setItem('servio_account', JSON.stringify(acc));
        } catch (_) {}

        if (scheduleFeedback) { scheduleFeedback.hidden = false; setTimeout(() => { scheduleFeedback.hidden = true; }, 3500); }
        showToast(_t('tech_schedule_saved_msg') || 'Schedule saved successfully!', 'success');
      } catch (err) {
        showToast(err?.message || 'Failed to save schedule.', 'error');
      } finally {
        saveScheduleBtn.disabled = false;
        if (origLabel) origLabel.textContent = _t('tech_save_schedule') || 'Save Schedule';
        if (iconSpan) iconSpan.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>`;
      }
    });
  }

  const saveCoverageBtn = document.getElementById('save-coverage');
  const coverageFeedback = document.getElementById('avail-coverage-feedback');
  if (saveCoverageBtn) {
    saveCoverageBtn.addEventListener('click', async () => {
      const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
      const serviceAreaInput = document.getElementById('service-area');
      const serviceArea = serviceAreaInput?.value.trim() || '';
      const selectedSkills = [];
      document.querySelectorAll('#categories-grid .avail-category-chip.is-selected').forEach(chip => {
        selectedSkills.push(chip.dataset.skill || chip.querySelector('span')?.textContent || '');
      });

      const origLabel = saveCoverageBtn.querySelector('.avail-save-btn__label');
      if (origLabel) origLabel.textContent = _t('tech_saving') || 'Saving…';
      const iconSpan = saveCoverageBtn.querySelector('.avail-save-btn__icon');
      if (iconSpan) iconSpan.innerHTML = '<span class="spinner"></span>';
      saveCoverageBtn.disabled = true;
      if (coverageFeedback) coverageFeedback.hidden = true;

      try {
        const profileUpdate = {};
        profileUpdate.serviceArea = serviceArea; // allow empty to clear
        profileUpdate.skills = selectedSkills; // allow empty array to clear
        await updateMe(profileUpdate);

        try {
          const acc = JSON.parse(localStorage.getItem('servio_account') || '{}');
          acc.serviceArea = serviceArea;
          acc.skills = selectedSkills;
          acc.specialty = selectedSkills.join(', ');
          localStorage.setItem('servio_account', JSON.stringify(acc));
        } catch (_) {}

        if (coverageFeedback) { coverageFeedback.hidden = false; setTimeout(() => { coverageFeedback.hidden = true; }, 3500); }
        showToast(_t('tech_coverage_saved_msg') || 'Coverage saved successfully!', 'success');
      } catch (err) {
        showToast(err?.message || 'Failed to save coverage.', 'error');
      } finally {
        saveCoverageBtn.disabled = false;
        if (origLabel) origLabel.textContent = _t('tech_save_coverage') || 'Save Coverage';
        if (iconSpan) iconSpan.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>`;
      }
    });
  }
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
    document.querySelectorAll('.stab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
    if (target === 'profile') updateProfileCompleteness();
  });
  updateProfileCompleteness();
}

/* ── Profile completeness bar ────────────────────────────── */
function updateProfileCompleteness() {
  const account = typeof getAccount === 'function' ? getAccount() : null;
  const fields = ['fullName', 'email', 'phone', 'specialty', 'hourlyRate'];
  const filled = fields.filter(f => account && account[f] && String(account[f]).trim()).length;
  const avatar = document.querySelector('.settings-avatar-preview img');
  const total  = fields.length + 1;
  const score  = Math.round(((filled + (avatar ? 1 : 0)) / total) * 100);
  const pct  = document.getElementById('profile-complete-pct');
  const bar  = document.getElementById('profile-complete-bar');
  const fill = document.getElementById('profile-complete-fill');
  if (pct)  pct.textContent = score + '%';
  if (bar)  bar.setAttribute('aria-valuenow', score);
  if (fill) fill.style.width = score + '%';
}

/* ── Security form (separate from profile form) ──────────── */
function initTechSecurityForm() {
  const form = document.getElementById('tech-security-form');
  if (!form) return;
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const currentPw = form.querySelector('#s-current-password');
    const newPw     = form.querySelector('#s-new-password');
    const confirmPw = form.querySelector('#s-confirm-password');
    const submitBtn = form.querySelector('[type="submit"]');
    if (!currentPw.value.trim()) {
      showToast(_t('toast_enter_current_pw') || 'Enter your current password.', 'info');
      currentPw.focus(); return;
    }
    if (newPw.value.length < 8) {
      showToast(_t('toast_pw_min_length') || 'Password must be at least 8 characters.', 'info');
      newPw.focus(); return;
    }
    if (!/[0-9]/.test(newPw.value)) {
      showToast(_t('toast_pw_needs_number') || 'Password must contain at least one number.', 'info');
      newPw.focus(); return;
    }
    if (!/[^A-Za-z0-9]/.test(newPw.value)) {
      showToast(_t('toast_pw_needs_special') || 'Password must contain at least one special character.', 'info');
      newPw.focus(); return;
    }
    if (newPw.value === currentPw.value) {
      showToast(_t('toast_pw_same_as_current') || 'New password must be different from your current password.', 'info');
      newPw.focus(); return;
    }
    if (newPw.value !== confirmPw.value) {
      showToast(_t('toast_pw_mismatch') || 'Passwords do not match.', 'info');
      confirmPw.focus(); return;
    }
    if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = _t('tech_updating') || 'Updating…'; }
    try {
      await updatePassword({ currentPassword: currentPw.value, newPassword: newPw.value });
      currentPw.value = '';
      newPw.value = '';
      confirmPw.value = '';
      document.getElementById('pw-strength-wrap')?.setAttribute('hidden', '');
      document.querySelectorAll('.pw-check').forEach(c => c.classList.remove('is-met'));
      showToast(_t('toast_pw_updated') || 'Password updated. Please sign in again.', 'success');
      setTimeout(() => {
        localStorage.removeItem('servio_token');
        localStorage.removeItem('servio_session');
        window.location.href = './login.html';
      }, 1500);
    } catch (err) {
      showToast(err.message || 'Failed to update password.', 'error');
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = _t('tech_update_password') || 'Update Password'; }
    }
  });
}

/* ── Password strength meter + live checklist ────────────── */
function initPasswordStrengthMeter() {
  const newPw     = document.getElementById('s-new-password');
  const confirmPw = document.getElementById('s-confirm-password');
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
  const strengthLabels = ['', 'tech_pw_strength_weak', 'tech_pw_strength_fair', 'tech_pw_strength_good', 'tech_pw_strength_strong'];

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
    matchHint.textContent = _t(match ? 'tech_pw_match' : 'tech_pw_no_match');
    matchHint.className = 'pw-match-hint ' + (match ? 'is-match' : 'is-mismatch');
  }
  confirmPw?.addEventListener('input', checkMatch);
}

/* ── Settings toggles (notifications, 2FA) ──────────────── */
function initSettingToggles() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const prefs = JSON.parse(localStorage.getItem('servio_tech_notif_prefs') || '{}');
  document.querySelectorAll('.stab-toggle[data-pref]').forEach(btn => {
    const key = btn.dataset.pref;
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
      localStorage.setItem('servio_tech_notif_prefs', JSON.stringify(prefs));
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
      c.setAttribute('aria-checked', c.dataset.lang === current ? 'true' : 'false');
    });
  }
  syncCards();
  cards.addEventListener('click', (e) => {
    const card = e.target.closest('.lang-card');
    if (!card) return;
    const lang = card.dataset.lang;
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
      c.setAttribute('aria-checked', c.dataset.themeChoice === current ? 'true' : 'false');
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
    const toggle = document.querySelector('[data-theme-toggle]');
    if (toggle) toggle.checked = apply === 'dark';
    syncCards();
  });
}

/* ── Export / Deactivate account buttons ────────────────── */
function initAccountTab() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  document.getElementById('btn-export-data')?.addEventListener('click', () => {
    showToast(_t('toast_export_requested') || 'Data export requested. You will receive an email shortly.', 'success');
  });
  document.getElementById('btn-deactivate-account')?.addEventListener('click', () => {
    const msg = _t('confirm_deactivate') || 'Deactivate your account? You can log back in to reactivate.';
    if (confirm(msg)) showToast(_t('toast_account_deactivated') || 'Account deactivated.', 'info');
  });
}

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

/* ── Pending account guard ──────────────────────────────────
   Blocks all dashboard tabs except Verification and Settings
   while the account is pending admin approval.
─────────────────────────────────────────────────────────── */
function initPendingGuard() {
  const account = getAccount();
  const isPending =
    account?.status === 'pending' ||
    account?.verificationStatus === 'pending';
  if (!isPending) return;

  // Build inline doc status rows
  const docs = account?.uploadedDocs || {};
  const DOC_LABELS = {
    idFront:   'National ID — Front',
    idBack:    'National ID — Back',
    idSelfie:  'Selfie with ID',
    cvFile:    'CV / Resume',
    portfolio: 'Portfolio',
  };
  const docRows = Object.entries(DOC_LABELS).map(([key, label]) => {
    const doc = docs[key];
    const uploaded = key === 'portfolio' ? !!(doc?.count) : !!(doc?.uploaded);
    const badge = uploaded
      ? '<span style="color:#065f46;font-weight:600;font-size:0.75rem;">&#10003; Uploaded</span>'
      : '<span style="color:#92400e;font-size:0.75rem;">Pending</span>';
    return `<div style="display:flex;justify-content:space-between;align-items:center;padding:6px 0;border-bottom:1px solid var(--color-border,#e5e7eb);">
      <span style="font-size:0.82rem;">${label}</span>${badge}</div>`;
  }).join('');

  const overlay = document.createElement('div');
  overlay.id = 'pending-overlay';
  overlay.setAttribute('role', 'alert');
  overlay.setAttribute('aria-live', 'polite');
  overlay.innerHTML = `
    <div class="pending-overlay__card">
      <div class="pending-overlay__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="52" height="52" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
        </svg>
      </div>
      <h2 class="pending-overlay__title">Application Under Review</h2>
      <p class="pending-overlay__desc">Your documents are being reviewed by our team. This typically takes 1–2 business days. You'll have full access once your account is approved.</p>
      <div style="width:100%;margin-top:12px;margin-bottom:4px;">${docRows}</div>
      <p style="font-size:0.78rem;color:var(--color-text-light,#6b7280);margin-top:12px;">Questions? Contact us at <strong>support@servio.com</strong></p>
      <div style="width:100%;height:1px;background:var(--color-border,#e5e7eb);margin:20px 0 16px;"></div>
      <button type="button" id="pending-overlay-logout" style="display:inline-flex;align-items:center;gap:7px;padding:9px 20px;border:none;border-radius:10px;background:#f3f4f6;color:#6b7280;font-size:0.82rem;font-weight:500;cursor:pointer;letter-spacing:0.01em;transition:background 0.18s,color 0.18s;" onmouseover="this.style.background='#fee2e2';this.style.color='#dc2626';" onmouseout="this.style.background='#f3f4f6';this.style.color='#6b7280';">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
        Sign Out
      </button>
    </div>
  `;
  document.body.appendChild(overlay);

  // Overlay is permanent — never hidden while account is pending
  overlay.removeAttribute('hidden');

  document.getElementById('pending-overlay-logout')?.addEventListener('click', () => {
    localStorage.removeItem('servio_session');
    window.location.href = './login.html';
  });

  // Swallow ALL tab navigation so sidebar clicks do nothing while pending
  document.querySelectorAll('[data-tab]').forEach(tab => {
    tab.addEventListener('click', e => e.stopImmediatePropagation(), true);
  });
}

/* ── Verification tab: sync document statuses from signup data ──
   Reads account.uploadedDocs written by signup.js and updates
   each document row's badge and shows uploaded filenames.
─────────────────────────────────────────────────────────── */
function updateVerifStatusBanner(status) {
  const banner   = document.getElementById('verif-status-banner');
  const textEl   = document.getElementById('verif-status-text');
  const hintEl   = document.getElementById('verif-status-hint');
  if (!banner || !textEl) return;

  banner.className = 'verif-status';
  if (status === 'verified' || status === 'approved') {
    banner.classList.add('verif-status--verified');
    textEl.textContent = 'Status: Verified ✓';
    if (hintEl) hintEl.textContent = 'Your identity has been verified. You are now a trusted professional on SERVIO.';
  } else if (status === 'rejected') {
    banner.classList.add('verif-status--rejected');
    textEl.textContent = 'Status: Rejected';
    if (hintEl) hintEl.textContent = 'Your verification was rejected. Please re-upload your documents and try again.';
  } else if (status === 'pending' || status === 'not_submitted') {
    banner.classList.add('verif-status--review');
    textEl.textContent = 'Status: Pending Submission';
    if (hintEl) hintEl.textContent = 'Please upload your identity documents to start the verification process.';
  } else {
    banner.classList.add('verif-status--review');
    textEl.textContent = 'Status: Under Review';
    if (hintEl) hintEl.textContent = 'Your documents are being verified. This typically takes 1–2 business days.';
  }
}

function toAbsUrl(url) {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  const base = (window.SERVIO_CONFIG?.API_BASE || 'http://127.0.0.1:5000/api/v1').replace('/api/v1', '');
  return base + url;
}

function initVerificationTab() {
  const panel = document.getElementById('panel-verification');
  if (!panel) return;

  const account = getAccount();
  const docs    = account?.uploadedDocs || {};

  // Show status from localStorage first, then refresh from API
  updateVerifStatusBanner(account?.verificationStatus || 'pending');

  panel.querySelectorAll('[data-verif-doc]').forEach(row => {
    const key   = row.dataset.verifDoc;
    const doc   = docs[key];
    const badge = row.querySelector('[data-verif-badge]');
    const viewBtn  = row.querySelector('[data-verif-view]');
    const labelSpan = row.querySelector('[data-verif-upload-label]');
    const fileInput = row.querySelector('input[type="file"]');
    const body = row.querySelector('.verif-doc-row-v2__body');

    // Determine upload state
    const isPortfolio = key === 'portfolio';
    const uploaded = isPortfolio ? !!(doc?.count) : !!(doc?.uploaded);
    const url      = isPortfolio ? doc?.files?.[0]?.url : doc?.url;
    const name     = isPortfolio
      ? (doc?.count ? doc.count + ' file' + (doc.count > 1 ? 's' : '') + ' uploaded' : '')
      : (doc?.name || '');

    // Update badge
    if (badge) {
      if (uploaded) {
        badge.className = 'badge badge--confirmed';
        badge.textContent = 'Uploaded';
      } else {
        badge.className = 'badge badge--pending';
        badge.textContent = 'Pending';
      }
    }

    // Show/wire View button
    if (viewBtn) {
      const absUrl = toAbsUrl(url);
      if (uploaded && absUrl) {
        viewBtn.hidden = false;
        viewBtn.onclick = () => window.open(absUrl, '_blank');
      } else {
        viewBtn.hidden = true;
      }
    }

    // Update upload label
    if (labelSpan) labelSpan.textContent = uploaded ? 'Replace' : 'Upload';

    // Show filename hint
    if (name && body && !body.querySelector('.verif-doc-filename')) {
      const hint = document.createElement('p');
      hint.className = 'verif-doc-filename';
      hint.textContent = name;
      body.appendChild(hint);
    }

    // Wire re-upload
    if (fileInput) {
      fileInput.addEventListener('change', async () => {
        const files = isPortfolio ? [...fileInput.files] : [fileInput.files[0]];
        if (!files.length || !files[0]) return;

        if (labelSpan) labelSpan.textContent = 'Uploading…';
        try {
          const uploads = await Promise.all(files.map(f => uploadPublicFile(f, key)));
          const firstUrl = toAbsUrl(uploads[0]?.url || '');

          // Update badge
          if (badge) { badge.className = 'badge badge--confirmed'; badge.textContent = 'Uploaded'; }
          // Update view button
          if (viewBtn && firstUrl) { viewBtn.hidden = false; viewBtn.onclick = () => window.open(firstUrl, '_blank'); }
          // Update label
          if (labelSpan) labelSpan.textContent = 'Replace';
          // Update filename hint
          const existingHint = body?.querySelector('.verif-doc-filename');
          const newName = isPortfolio
            ? files.length + ' file' + (files.length > 1 ? 's' : '') + ' uploaded'
            : (files[0].name || '');
          if (existingHint) {
            existingHint.textContent = newName;
          } else if (body && newName) {
            const hint = document.createElement('p');
            hint.className = 'verif-doc-filename';
            hint.textContent = newName;
            body.appendChild(hint);
          }

          // Persist to account
          const acc = getAccount() || {};
          if (!acc.uploadedDocs) acc.uploadedDocs = {};
          if (isPortfolio) {
            acc.uploadedDocs.portfolio = { uploaded: true, count: uploads.length, files: uploads.map(u => ({ url: u.url, name: u.name || '' })) };
          } else {
            acc.uploadedDocs[key] = { uploaded: true, url: firstUrl, name: files[0].name || '' };
          }
          localStorage.setItem('servio_account', JSON.stringify(acc));

          showToast('Document uploaded successfully.', 'success');
        } catch {
          if (labelSpan) labelSpan.textContent = uploaded ? 'Replace' : 'Upload';
          showToast('Upload failed. Please try again.', 'error');
        }
      });
    }
  });

  // Sync fresh data from API — updates status + view button URLs
  getMe().then(user => {
    if (!user) return;
    updateVerifStatusBanner(user.verificationStatus || 'pending');

    // Update account cache
    const acc = getAccount() || {};
    acc.verificationStatus = user.verificationStatus;
    if (!acc.uploadedDocs) acc.uploadedDocs = {};

    const apiDocMap = {
      idFront:  { url: user.idFrontUrl,  name: user.idFrontName  },
      idBack:   { url: user.idBackUrl,   name: user.idBackName   },
      idSelfie: { url: user.idSelfieUrl, name: user.idSelfieName },
      cvFile:   { url: user.cvUrl,       name: user.cvName       },
    };

    Object.entries(apiDocMap).forEach(([key, { url, name }]) => {
      if (!url) return;
      const absUrl = toAbsUrl(url);
      acc.uploadedDocs[key] = { uploaded: true, url: absUrl, name: name || '' };

      // Update view button in DOM
      const row = panel.querySelector(`[data-verif-doc="${key}"]`);
      if (!row) return;
      const vBtn = row.querySelector('[data-verif-view]');
      const badge = row.querySelector('[data-verif-badge]');
      if (vBtn) { vBtn.hidden = false; vBtn.onclick = () => window.open(absUrl, '_blank'); }
      if (badge) { badge.className = 'badge badge--confirmed'; badge.textContent = 'Uploaded'; }
    });

    // Portfolio
    if (user.portfolioFiles?.length) {
      const absFirst = toAbsUrl(user.portfolioFiles[0]?.url || '');
      acc.uploadedDocs.portfolio = { uploaded: true, count: user.portfolioFiles.length, files: user.portfolioFiles.map(f => ({ url: toAbsUrl(f.url), name: f.name || '' })) };
      const row = panel.querySelector('[data-verif-doc="portfolio"]');
      if (row) {
        const vBtn = row.querySelector('[data-verif-view]');
        const badge = row.querySelector('[data-verif-badge]');
        if (vBtn && absFirst) { vBtn.hidden = false; vBtn.onclick = () => window.open(absFirst, '_blank'); }
        if (badge) { badge.className = 'badge badge--confirmed'; badge.textContent = 'Uploaded'; }
      }
    }

    localStorage.setItem('servio_account', JSON.stringify(acc));
  }).catch(() => {});
}

/* ── Notification panel ─────────────────────────────────── */
function initNotifPanel() {
  const btn   = document.getElementById('topbar-notif-btn');
  const panel = document.getElementById('notif-panel');
  const markAllBtn = document.getElementById('notif-mark-all');
  const emptyEl    = document.getElementById('notif-empty');
  if (!btn || !panel) return;

  function countUnread() {
    return panel.querySelectorAll('.notif-item.is-unread').length;
  }

  function refreshBadgeAndEmpty() {
    const n = countUnread();
    updateTopbarBadge(n);
    const items = panel.querySelectorAll('.notif-item');
    if (emptyEl) emptyEl.hidden = items.length > 0;
  }

  function openPanel() {
    const rect   = btn.getBoundingClientRect();
    const panelW = 340;
    const isRTL  = document.documentElement.dir === 'rtl';

    panel.style.top = (rect.bottom + 8) + 'px';

    if (isRTL) {
      // RTL: anchor panel's left edge near the button's left edge
      let left = rect.left;
      if (left + panelW > window.innerWidth - 8) left = window.innerWidth - panelW - 8;
      if (left < 8) left = 8;
      panel.style.left  = left + 'px';
      panel.style.right = 'auto';
    } else {
      // LTR: anchor panel's right edge to the button's right edge
      let right = window.innerWidth - rect.right;
      if (right < 8) right = 8;
      panel.style.right = right + 'px';
      panel.style.left  = 'auto';
    }

    panel.classList.add('is-open');
    btn.setAttribute('aria-expanded', 'true');
  }

  function closePanel() {
    panel.classList.remove('is-open');
    btn.setAttribute('aria-expanded', 'false');
  }

  btn.addEventListener('click', e => {
    e.stopPropagation();
    panel.classList.contains('is-open') ? closePanel() : openPanel();
  });

  // Mark individual item as read on click
  panel.addEventListener('click', e => {
    const item = e.target.closest('.notif-item');
    if (item && item.classList.contains('is-unread')) {
      item.classList.remove('is-unread');
      refreshBadgeAndEmpty();
    }
    // Don't close on item click — let user read multiple
    e.stopPropagation();
  });

  // Mark all read
  markAllBtn?.addEventListener('click', e => {
    panel.querySelectorAll('.notif-item.is-unread').forEach(el => el.classList.remove('is-unread'));
    refreshBadgeAndEmpty();
    e.stopPropagation();
  });

  // Click outside → close
  document.addEventListener('click', () => {
    if (panel.classList.contains('is-open')) closePanel();
  });

  // Escape → close
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && panel.classList.contains('is-open')) {
      closePanel();
      btn.focus();
    }
  });
}

// ── Top-level async initialization ───────────────────────────────────────────────
// Fetches live user data first, then seeds the availability UI with real data
function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

async function initReviewsTab(workerId) {
  const summaryEl = document.getElementById('tech-dash-reviews-summary');
  const listEl    = document.getElementById('tech-dash-reviews-list');
  if (!summaryEl || !listEl) return;

  listEl.innerHTML = `<p style="padding:1rem;opacity:0.6">Loading reviews…</p>`;

  let reviews = [];
  try {
    reviews = await getWorkerReviews(workerId);
  } catch (_) {
    listEl.innerHTML = `<p style="padding:1rem;opacity:0.6">Could not load reviews.</p>`;
    return;
  }

  if (!reviews.length) {
    summaryEl.hidden = true;
    listEl.innerHTML = `<p style="padding:1rem;opacity:0.6">No reviews yet.</p>`;
    return;
  }

  const avg = (reviews.reduce((s, r) => s + (r.rating || 0), 0) / reviews.length).toFixed(1);
  const fullStars = Math.round(avg);
  const stars = Array.from({ length: 5 }, (_, i) => i < fullStars ? '★' : '☆').join('');
  summaryEl.hidden = false;
  summaryEl.innerHTML = `
    <div class="reviews-summary__rating">${avg}</div>
    <div>
      <div class="reviews-summary__stars">${stars}</div>
      <div class="reviews-summary__count">Based on ${reviews.length} review${reviews.length !== 1 ? 's' : ''}</div>
    </div>`;

  listEl.innerHTML = reviews.map(r => {
    const name     = escapeHtml(r.user?.name || 'Customer');
    const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
    const comment  = escapeHtml(r.comment || '');
    const date     = r.createdAt
      ? new Date(r.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
      : '';
    const starCount = Math.round(r.rating || 0);
    const starHtml  = Array.from({ length: 5 }, (_, i) =>
      i < starCount ? '★' : '☆'
    ).join('');
    return `
      <div class="review-card" data-reveal>
        <div class="review-card__header">
          <div class="review-card__avatar">${initials}</div>
          <div class="review-card__meta">
            <p class="review-card__name">${name}</p>
            <p class="review-card__date">${date}</p>
          </div>
        </div>
        <div class="review-card__stars">${starHtml}</div>
        ${comment ? `<p class="review-card__text">"${comment}"</p>` : ''}
      </div>`;
  }).join('');
}

async function initDashboard() {
  populateProfile();
  updateWelcomeText();
  initTabs();
  initTopbarAvatar();
  initSettingsForm();
  initPasswordToggles();
  initSettingsValidation();
  initSettingsTabs();
  initTechSecurityForm();
  initPasswordStrengthMeter();
  initSettingToggles();
  initLanguageCards();
  initThemeCards();
  initAccountTab();
  initDashLogout();
  initNotifPanel();
  initPhase2();
  initVerificationTab();
  initPendingGuard();

  // Fetch live availability data and seed the panel
  let liveAvailability = null;
  let liveIsAvailable = false;
  let liveSkills = null;
  let liveServiceArea = '';
  let liveBlockedDates = [];
  try {
    const res = await getMe();
    const user = res?.user || res?.data?.user || res?.data || res;
    liveAvailability = user?.availability  || null;
    liveIsAvailable  = user?.isAvailable   || false;
    liveSkills       = user?.skills        || null;
    liveServiceArea  = user?.serviceArea   || '';
    liveBlockedDates = user?.blockedDates  || [];
    // Populate service area input
    const saInput = document.getElementById('service-area');
    if (saInput && liveServiceArea) saInput.value = liveServiceArea;
    if (user?._id) initReviewsTab(user._id);
  } catch (_) {
    // Fall back to cached data
    const acc = getAccount();
    liveAvailability = acc?.availability  || null;
    liveIsAvailable  = acc?.isAvailable   || false;
    liveSkills       = acc?.skills        || null;
    liveServiceArea  = acc?.serviceArea   || '';
    liveBlockedDates = acc?.blockedDates  || [];
  }

  initAvailableNowToggle(liveIsAvailable);
  initAvailabilitySchedule(liveAvailability);
  initBlockedDatesCalendar(liveAvailability || [], liveBlockedDates);
  initCategories(liveSkills);

  // Fire data fetches in parallel — stats/queue/earnings all come from bookings API
  await Promise.allSettled([
    populateStats(),
    initJobQueue(),
  ]);
}

initDashboard().catch(err => console.error('[Dashboard init error]', err));

/* Re-render dynamic grids and welcome text on language change */
document.addEventListener('langchange', () => {
  updateWelcomeText();
  const acc = getAccount();
  const scheduleContainer = document.getElementById('avail-schedule');
  if (scheduleContainer) { scheduleContainer.innerHTML = ''; initAvailabilitySchedule(acc?.availability || null); }
  const categoriesGrid = document.getElementById('categories-grid');
  if (categoriesGrid) { categoriesGrid.innerHTML = ''; initCategories(acc?.skills || null); }
  // Re-render data-driven sections with new language
  populateStats().catch(() => {});
  initJobQueue().catch(() => {});
});

/* ── Phase 2: Job Board, Proposals, Arrival Flow ── */
function initPhase2() {
  // Quick action buttons (overview)
  document.querySelectorAll('[data-goto-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelector(`[data-tab="${btn.dataset.gotoTab}"]`)?.click();
    });
  });

  // My Proposals: Withdraw
  document.querySelectorAll('[data-withdraw-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      const msg = typeof window.t === 'function' ? window.t('confirm_withdraw') : 'Withdraw this proposal?';
      if (confirm(msg)) {
        btn.closest('.my-proposal-card').remove();
        showToast(typeof window.t === 'function' ? window.t('toast_request_withdrawn') : 'Proposal withdrawn', 'info');
      }
    });
  });

  // My Proposals: View Booking → Job Queue
  document.querySelectorAll('[data-goto-job-queue]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelector('[data-tab="job-queue"]')?.click();
    });
  });

  // Job Board: Send Proposal toggle
  document.querySelectorAll('[data-send-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.sendProposal;
      const area = document.getElementById(`proposal-area-${id}`);
      if (area) area.hidden = false;
      btn.hidden = true;
    });
  });

  // Job Board: Cancel Proposal
  document.querySelectorAll('[data-cancel-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.cancelProposal;
      const area = document.getElementById(`proposal-area-${id}`);
      if (area) area.hidden = true;
      const sendBtn = document.querySelector(`[data-send-proposal="${id}"]`);
      if (sendBtn) sendBtn.hidden = false;
    });
  });

  // Job Board: Submit Proposal form
  document.querySelectorAll('.proposal-form').forEach(form => {
    form.addEventListener('submit', e => {
      e.preventDefault();
      const jobId = form.dataset.for;
      const fd = new FormData(form);
      const proposal = {
        jobId, price: fd.get('price'), message: fd.get('message'),
        startDate: fd.get('startDate'), submittedAt: new Date().toISOString(),
      };
      const proposals = JSON.parse(localStorage.getItem('servio_my_proposals') || '[]');
      proposals.push(proposal);
      localStorage.setItem('servio_my_proposals', JSON.stringify(proposals));
      const area = document.getElementById(`proposal-area-${jobId}`);
      if (area) {
        area.innerHTML = '<span style="color:#065f46;font-weight:600">✓ ' + (typeof window.t === 'function' ? window.t('tech_submit_proposal') : 'Proposal Sent') + '</span>';
        area.hidden = false;
      }
      showToast(typeof window.t === 'function' ? window.t('toast_saved') : 'Proposal sent!', 'success');
    });
  });

  // Job Board: Filter
  document.getElementById('jbCategoryFilter')?.addEventListener('change', applyJbFilters);
  document.getElementById('jbAreaFilter')?.addEventListener('change', applyJbFilters);
  function applyJbFilters() {
    const cat  = document.getElementById('jbCategoryFilter')?.value;
    const area = document.getElementById('jbAreaFilter')?.value;
    document.querySelectorAll('.jb-card').forEach(card => {
      card.classList.toggle('is-hidden',
        !!(cat  && card.dataset.category !== cat) ||
        !!(area && card.dataset.area !== area));
    });
  }

  // GPS banner dismiss
  document.querySelectorAll('[data-dismissible] .banner-dismiss').forEach(btn => {
    btn.addEventListener('click', () => btn.closest('[data-dismissible]').remove());
  });

  // Liability: Pay Now — clears outstanding balance display
  document.getElementById('payLiabilityBtn')?.addEventListener('click', () => {
    const el = document.getElementById('liabilityAmount');
    if (el) el.textContent = '0 EGP';
    const listEl = document.getElementById('liability-items-list');
    if (listEl) listEl.innerHTML = '';
    showToast(typeof window.t === 'function' ? window.t('toast_saved') : 'Balance cleared!', 'success');
  });

  initBioSection();
  initSocialLinks();
  initServicesCatalog();
  initAreaTags();
  initPricingForm();
  initPayoutSection();
}

/* ─────────────────────────────────────────────────────────────
   BIO / ABOUT ME
───────────────────────────────────────────────────────────── */
function initBioSection() {
  const textarea = document.getElementById('s-bio');
  const counter  = document.getElementById('bio-char-count');
  const saveBtn  = document.getElementById('btn-save-bio');
  const saveMsg  = document.getElementById('bio-save-msg');
  if (!textarea) return;

  // Restore saved bio
  const account = getAccount() || {};
  if (account.bio) textarea.value = account.bio;
  if (counter) counter.textContent = textarea.value.length;

  textarea.addEventListener('input', () => {
    if (counter) counter.textContent = textarea.value.length;
  });

  saveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    acc.bio = textarea.value.trim();
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
  });
}

/* ─────────────────────────────────────────────────────────────
   SOCIAL & PORTFOLIO LINKS
───────────────────────────────────────────────────────────── */
function initSocialLinks() {
  const form = document.getElementById('social-links-form');
  if (!form) return;

  // Restore saved values (data-settings-field already handled in populateDashboard,
  // but social fields may not be wired there yet — handle explicitly)
  const account = getAccount() || {};
  ['facebook','instagram','portfolio'].forEach(key => {
    const el = document.getElementById('s-' + key);
    if (el && account[key]) el.value = account[key];
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const acc = getAccount() || {};
    ['facebook','instagram','portfolio'].forEach(key => {
      const el = document.getElementById('s-' + key);
      if (el) acc[key] = el.value.trim();
    });
    localStorage.setItem('servio_account', JSON.stringify(acc));
    const msg = document.getElementById('social-save-msg');
    if (msg) { msg.hidden = false; setTimeout(() => { msg.hidden = true; }, 2500); }
  });
}

/* ─────────────────────────────────────────────────────────────
   SERVICES CATALOG
───────────────────────────────────────────────────────────── */
const CATEGORY_LABELS = {
  plumbing:     'Plumbing',
  electrical:   'Electrical',
  hvac:         'A/C & HVAC',
  carpentry:    'Carpentry',
  appliance:    'Appliances',
  handyman:     'Handyman',
  renovation:   'Renovation',
  painting:     'Painting',
  flooring:     'Flooring',
  drywall:      'Drywall',
  roofing:      'Roofing',
  cleaning:     'Cleaning',
  'pest-control': 'Pest Control',
  landscaping:  'Landscaping',
  installation: 'Installation',
  other:        'Other',
};

async function initServicesCatalog() {
  const catalog = document.getElementById('services-catalog');
  const saveBtn = document.getElementById('btn-save-skills');
  const saveMsg = document.getElementById('skills-save-msg');
  if (!catalog) return;

  let allServices    = [];
  let selectedIds    = new Set();
  let verifiedCats   = [];
  let pendingCats    = [];

  try {
    const [svcRes, meRes] = await Promise.all([
      getServices({ limit: 200 }),
      getMe(),
    ]);
    allServices  = svcRes.data?.services || svcRes.services || svcRes.data || [];
    const me     = meRes.data || meRes;
    verifiedCats = me.categories         || [];
    pendingCats  = me.pendingCategories  || [];

    const workerServices = me.services || [];
    workerServices.forEach(s => selectedIds.add((s._id || s).toString()));

    const skills = me.skills || [];
    const certEl = document.getElementById('s-certifications');
    if (certEl && skills.length) certEl.value = skills.join('\n');
  } catch (e) {
    catalog.innerHTML = '<p style="color:#e74c3c;font-size:0.875rem;">Failed to load services. Please refresh.</p>';
    return;
  }

  if (!allServices.length) {
    catalog.innerHTML = '<p style="color:var(--color-secondary,#9A8C73);font-size:0.875rem;">No services found. Ask an admin to seed the service catalog.</p>';
    return;
  }

  const grouped = {};
  allServices.forEach(svc => {
    const cat = svc.category || 'other';
    if (!grouped[cat]) grouped[cat] = [];
    grouped[cat].push(svc);
  });

  const formatPrice = svc => {
    if (svc.priceUnit === 'per_hour') return `${svc.basePrice} EGP/hr`;
    if (svc.priceUnit === 'per_sqm')  return `${svc.basePrice} EGP/m²`;
    return `${svc.basePrice} EGP`;
  };

  const catBadge = cat => {
    if (verifiedCats.includes(cat))  return '<span class="svc-cat-badge svc-cat-badge--verified">Verified</span>';
    if (pendingCats.includes(cat))   return '<span class="svc-cat-badge svc-cat-badge--pending">Pending Admin Approval</span>';
    return '<span class="svc-cat-badge svc-cat-badge--new">Requires Re-verification</span>';
  };

  catalog.innerHTML = Object.entries(grouped).map(([cat, services]) => `
    <div class="svc-cat-group">
      <div class="svc-cat-header">${CATEGORY_LABELS[cat] || cat} ${catBadge(cat)}</div>
      <div class="svc-cat-options">
        ${services.map(svc => {
          const id      = (svc._id || svc.id || '').toString();
          const checked = selectedIds.has(id) ? 'checked' : '';
          return `<label class="svc-check-label">
            <input type="checkbox" class="svc-checkbox" value="${id}" data-category="${svc.category || ''}" ${checked} />
            <span class="svc-check-name">${svc.title}</span>
            <span class="svc-check-price">${formatPrice(svc)}</span>
          </label>`;
        }).join('')}
      </div>
    </div>
  `).join('');

  saveBtn?.addEventListener('click', async () => {
    const checkedIds  = [...catalog.querySelectorAll('.svc-checkbox:checked')].map(cb => cb.value);
    const checkedCats = [...new Set([...catalog.querySelectorAll('.svc-checkbox:checked')].map(cb => cb.dataset.category).filter(Boolean))];
    const certEl      = document.getElementById('s-certifications');
    const skills      = certEl ? certEl.value.trim().split('\n').map(s => s.trim()).filter(Boolean) : [];

    try {
      await updateMe({ services: checkedIds, skills });
      const newCats = checkedCats.filter(c => !verifiedCats.includes(c));
      if (newCats.length) {
        const labels = newCats.map(c => CATEGORY_LABELS[c] || c).join(', ');
        showToast(`Services saved. ${labels}: pending admin review before appearing live.`, 'info');
        pendingCats = [...new Set([...pendingCats, ...newCats])];
        catalog.querySelectorAll('.svc-cat-header').forEach(h => {
          const cat = Object.keys(CATEGORY_LABELS).find(k => h.textContent.includes(CATEGORY_LABELS[k]));
          if (cat && newCats.includes(cat)) {
            const badge = h.querySelector('.svc-cat-badge');
            if (badge) { badge.textContent = 'Pending Admin Approval'; badge.className = 'svc-cat-badge svc-cat-badge--pending'; }
          }
        });
      } else if (saveMsg) {
        saveMsg.hidden = false;
        setTimeout(() => { saveMsg.hidden = true; }, 2500);
      }
    } catch (e) {
      showToast('Failed to save services. Please try again.', 'error');
    }
  });
}

/* ─────────────────────────────────────────────────────────────
   SERVICE AREA TAGS
───────────────────────────────────────────────────────────── */
async function initAreaTags() {
  const container = document.getElementById('area-tags');
  const saveBtn   = document.getElementById('btn-save-areas');
  const saveMsg   = document.getElementById('areas-save-msg');
  if (!container) return;

  // Load saved areas from backend
  try {
    const me = await getMe();
    const serviceArea = me.data?.serviceArea || me.serviceArea || '';
    const savedAreas  = serviceArea ? serviceArea.split(',').map(a => a.trim()).filter(Boolean) : [];
    container.querySelectorAll('.skill-tag').forEach(tag => {
      if (savedAreas.includes(tag.dataset.area)) tag.setAttribute('aria-pressed', 'true');
    });
  } catch (e) { /* leave all unselected */ }

  container.querySelectorAll('.skill-tag').forEach(tag => {
    tag.addEventListener('click', () => {
      const pressed = tag.getAttribute('aria-pressed') === 'true';
      tag.setAttribute('aria-pressed', String(!pressed));
    });
  });

  saveBtn?.addEventListener('click', async () => {
    const selected = [...container.querySelectorAll('.skill-tag[aria-pressed="true"]')]
      .map(t => t.dataset.area);
    try {
      await updateMe({ serviceArea: selected.join(', ') });
      if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
    } catch (e) {
      showToast('Failed to save service areas. Please try again.', 'error');
    }
  });
}

/* ─────────────────────────────────────────────────────────────
   SERVICE PRICING FORM
───────────────────────────────────────────────────────────── */
function initPricingForm() {
  const form    = document.getElementById('pricing-form');
  const saveMsg = document.getElementById('pricing-save-msg');
  if (!form) return;

  const account = getAccount() || {};
  // Restore numeric fields
  ['minFee','travelFee','emergencyMultiplier'].forEach(key => {
    const el = document.getElementById('s-' + key.replace(/([A-Z])/g, c => '-' + c.toLowerCase()));
    if (el && account[key] != null) el.value = account[key];
  });
  // Restore checkboxes
  ['acceptCash','acceptCard','acceptInstapay','acceptWallet'].forEach(key => {
    const el = form.querySelector(`[name="${key}"]`);
    if (el) el.checked = !!account[key];
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const acc = getAccount() || {};
    acc.minFee              = parseFloat(document.getElementById('s-min-fee')?.value) || 0;
    acc.travelFee           = parseFloat(document.getElementById('s-travel-fee')?.value) || 0;
    acc.emergencyMultiplier = parseFloat(document.getElementById('s-emergency-mult')?.value) || 1;
    ['acceptCash','acceptCard','acceptInstapay','acceptWallet'].forEach(key => {
      const el = form.querySelector(`[name="${key}"]`);
      if (el) acc[key] = el.checked;
    });
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
  });
}

/* ─────────────────────────────────────────────────────────────
   PAYOUT SECTION
───────────────────────────────────────────────────────────── */
function initPayoutSection() {
  const methodCards   = document.getElementById('payout-method-cards');
  const bankFields    = document.getElementById('payout-fields-bank');
  const walletFields  = document.getElementById('payout-fields-wallet');
  const saveBtn       = document.getElementById('btn-save-payout');
  const saveMsg       = document.getElementById('payout-save-msg');
  const scheduleOpts  = document.getElementById('payout-schedule-options');
  const schedSaveBtn  = document.getElementById('btn-save-schedule');
  const schedSaveMsg  = document.getElementById('schedule-save-msg');

  if (!methodCards) return;

  const account = getAccount() || {};

  // Restore saved method
  const currentMethod = account.payoutMethod || 'bank';
  setPayoutMethod(currentMethod);

  // Restore bank / wallet field values
  if (account.bankName) {
    const sel = document.getElementById('s-bank-name');
    if (sel) sel.value = account.bankName;
  }
  if (account.accountHolder) {
    const el = document.getElementById('s-account-holder');
    if (el) el.value = account.accountHolder;
  }
  if (account.accountNumber) {
    const el = document.getElementById('s-account-number');
    if (el) el.value = account.accountNumber;
  }
  if (account.walletNumber) {
    const el = document.getElementById('s-wallet-number');
    if (el) el.value = account.walletNumber;
  }

  // Restore schedule
  if (account.payoutSchedule && scheduleOpts) {
    const radio = scheduleOpts.querySelector(`[value="${account.payoutSchedule}"]`);
    if (radio) radio.checked = true;
  }

  methodCards.addEventListener('click', (e) => {
    const card = e.target.closest('.payout-method-card');
    if (!card) return;
    setPayoutMethod(card.dataset.payoutMethod);
  });

  function setPayoutMethod(method) {
    methodCards.querySelectorAll('.payout-method-card').forEach(c => {
      const active = c.dataset.payoutMethod === method;
      c.classList.toggle('payout-method-card--active', active);
      c.setAttribute('aria-checked', String(active));
    });
    const isBank = method === 'bank';
    if (bankFields)   bankFields.hidden   = !isBank;
    if (walletFields) walletFields.hidden = isBank;
  }

  saveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    const activeCard = methodCards.querySelector('.payout-method-card--active');
    acc.payoutMethod = activeCard?.dataset.payoutMethod || 'bank';
    acc.bankName      = document.getElementById('s-bank-name')?.value || '';
    acc.accountHolder = document.getElementById('s-account-holder')?.value.trim() || '';
    acc.accountNumber = document.getElementById('s-account-number')?.value.trim() || '';
    acc.walletNumber  = document.getElementById('s-wallet-number')?.value.trim() || '';
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
  });

  schedSaveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    const checked = scheduleOpts?.querySelector('[name="payoutSchedule"]:checked');
    if (checked) acc.payoutSchedule = checked.value;
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (schedSaveMsg) { schedSaveMsg.hidden = false; setTimeout(() => { schedSaveMsg.hidden = true; }, 2500); }
  });
}

function updateActionNeededDates() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  document.querySelectorAll('.dash-action-card').forEach(card => {
    const statusEl = card.querySelector('.dash-action-card__status');
    const dateEl   = card.querySelector('.dash-action-card__date');
    if (statusEl && statusEl.textContent.trim() === 'Action needed') {
      statusEl.textContent = _t('tech_action_needed');
    }
    if (statusEl && statusEl.textContent.trim() === 'Awaiting review') {
      statusEl.textContent = _t('tech_stat_awaiting_review');
    }
    if (dateEl && dateEl.textContent.includes('Due')) {
      const dateStr = dateEl.textContent.replace('Due ', '').trim();
      dateEl.textContent = _t('tech_stat_due_date').replace('{date}', dateStr);
    }
  });
}

/* ── Profile read-only / edit mode ────────────────────────── */
function initProfileReadOnly() {
  const form       = document.querySelector('[data-readonly-form]');
  const editBtn    = document.getElementById('btn-edit-profile');
  const cancelBtn  = document.getElementById('btn-cancel-profile');
  const actionsRow = document.getElementById('profile-edit-actions');
  if (!form || !editBtn) return;

  // Snapshot values so Cancel can restore them
  let _snapshot = {};

  function getEditableInputs() {
    return [...form.querySelectorAll('input:not([type="file"]):not([id="s-email"]), textarea')];
  }

  function enableEdit() {
    _snapshot = {};
    getEditableInputs().forEach(el => {
      _snapshot[el.id || el.name] = el.value;
      el.removeAttribute('readonly');
    });
    if (actionsRow) actionsRow.style.display = 'flex';
    editBtn.style.display = 'none';
  }

  function disableEdit() {
    getEditableInputs().forEach(el => el.setAttribute('readonly', ''));
    if (actionsRow) actionsRow.style.display = 'none';
    editBtn.style.display = '';
  }

  editBtn.addEventListener('click', enableEdit);

  cancelBtn?.addEventListener('click', () => {
    getEditableInputs().forEach(el => {
      const key = el.id || el.name;
      if (key in _snapshot) el.value = _snapshot[key];
    });
    disableEdit();
  });

  // After a successful save, return to read-only
  form.addEventListener('submit', async () => {
    // Small delay so the submit handler runs first
    setTimeout(disableEdit, 100);
  }, { capture: true });
}

/* ── Email change modal ────────────────────────────────────── */
function initEmailChange() {
  const modal      = document.getElementById('modal-change-email-tech');
  const openBtn    = document.getElementById('btn-change-email-tech');
  const closeBtn   = document.getElementById('btn-close-change-email-tech');
  const cancelBtn  = document.getElementById('btn-change-email-tech-cancel');
  const form       = document.getElementById('change-email-tech-form');
  const newEmailEl = document.getElementById('change-email-tech-new');
  const pwEl       = document.getElementById('change-email-tech-password');
  const errorEl    = document.getElementById('change-email-tech-error');
  const submitBtn  = document.getElementById('btn-change-email-tech-confirm');
  if (!modal || !openBtn || !form) return;

  function openModal() { modal.removeAttribute('hidden'); newEmailEl?.focus(); }
  function closeModal() { modal.setAttribute('hidden', ''); form.reset(); if (errorEl) errorEl.hidden = true; }

  openBtn.addEventListener('click', openModal);
  closeBtn?.addEventListener('click', closeModal);
  cancelBtn?.addEventListener('click', closeModal);
  modal.addEventListener('click', e => { if (e.target === modal) closeModal(); });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (errorEl) errorEl.hidden = true;
    const newEmail = newEmailEl?.value?.trim();
    const currentPassword = pwEl?.value;
    if (!newEmail) { if (errorEl) { errorEl.textContent = 'Please enter a new email address.'; errorEl.hidden = false; } return; }
    if (!currentPassword) { if (errorEl) { errorEl.textContent = 'Please enter your current password.'; errorEl.hidden = false; } return; }
    if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = 'Updating…'; }
    try {
      await updateEmail({ newEmail, currentPassword });
      const sess = getSession();
      if (sess) { sess.email = newEmail; localStorage.setItem('servio_session', JSON.stringify(sess)); }
      const acc = getAccount() || {};
      acc.email = newEmail;
      localStorage.setItem('servio_account', JSON.stringify(acc));
      const emailInput = document.getElementById('s-email');
      if (emailInput) emailInput.value = newEmail;
      closeModal();
      showToast('Email updated successfully. Please log in again.', 'success');
      setTimeout(() => { localStorage.removeItem('servio_session'); window.location.href = './login.html'; }, 2000);
    } catch (err) {
      if (errorEl) { errorEl.textContent = err.message || 'Failed to update email.'; errorEl.hidden = false; }
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = 'Update Email'; }
    }
  });
}

/* ── Delete Account Modal ──────────────────────────────────── */
function initDeleteAccount() {
  const modal     = document.getElementById('modal-delete-account');
  const cancelBtn = document.getElementById('btn-delete-account-cancel');
  const confirmBtn= document.getElementById('btn-delete-account-confirm');
  const inputEl   = document.getElementById('delete-account-confirm-input');
  const errorEl   = document.getElementById('delete-account-error');
  if (!modal || !confirmBtn) return;

  function closeModal() {
    modal.style.display = 'none';
    if (inputEl) inputEl.value = '';
    if (errorEl) { errorEl.textContent = ''; errorEl.hidden = true; }
    if (confirmBtn) { confirmBtn.disabled = true; confirmBtn.textContent = 'Delete My Account'; }
  }

  cancelBtn?.addEventListener('click', closeModal);
  document.getElementById('btn-delete-account-cancel-footer')?.addEventListener('click', closeModal);
  modal.addEventListener('click', e => { if (e.target === modal) closeModal(); });

  // Enable confirm button only when user types DELETE
  if (inputEl) {
    inputEl.addEventListener('input', () => {
      confirmBtn.disabled = inputEl.value.trim() !== 'DELETE';
    });
  }

  confirmBtn.addEventListener('click', async () => {
    if (inputEl && inputEl.value.trim() !== 'DELETE') return;
    confirmBtn.disabled = true;
    confirmBtn.textContent = 'Deleting…';
    if (errorEl) { errorEl.hidden = true; }
    try {
      await deleteMe();
      // Wipe all local data and redirect to home
      localStorage.clear();
      window.location.href = './index.html';
    } catch (err) {
      if (errorEl) {
        errorEl.textContent = err.message || 'Failed to delete account. Please try again.';
        errorEl.hidden = false;
      }
      confirmBtn.disabled = false;
      confirmBtn.textContent = 'Delete My Account';
    }
  });
}

// Initial update for dates
updateActionNeededDates();
initProfileReadOnly();
initEmailChange();
initDeleteAccount();

// Re-run on language change
document.addEventListener('langchange', updateActionNeededDates);
