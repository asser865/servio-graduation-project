/* ═══════════════════════════════════════════════════════════
   technician-dashboard.js
   ═══════════════════════════════════════════════════════════ */
import { revealAll } from '../components/scroll-reveal.js';
import { showToast } from '../components/toast.js';
import { getInitials } from '../utils/string.js';

const TAB_KEY = 'servio_activeTab_technician';
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

  const saved = localStorage.getItem(TAB_KEY) || 'overview';
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

  if (account) {
    document.querySelectorAll('[data-settings-field]').forEach(f => {
      if (account[f.dataset.settingsField] != null) f.value = account[f.dataset.settingsField];
    });
    const preview = document.querySelector('[data-avatar-preview]');
    if (preview && preview.children.length === 0) preview.textContent = initials;
    // Pre-fill service area
    const serviceAreaInput = document.getElementById('service-area');
    if (serviceAreaInput && account.serviceArea) serviceAreaInput.value = account.serviceArea;
  }
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

function populateStats() {
  const stats = {
    'total-jobs': '18',
    'month-earnings': 'EGP 3,200',
    'avg-rating': '4.8',
    'pending-requests': '2'
  };
  Object.entries(stats).forEach(([key, val]) => {
    const el = document.querySelector(`[data-stat="${key}"]`);
    if (el) el.textContent = val;
  });
  // Show unread notification count on topbar badge (demo: 2 pending)
  updateTopbarBadge(2);
}

function initAvailabilitySchedule() {
  const container = document.getElementById('avail-schedule');
  if (!container) return;
  const T = typeof window.t === 'function' ? window.t.bind(window) : (k) => k;
  const toLabel = T('avail_to');
  const offLabel = T('avail_off');
  DAYS_KEYS.forEach(dayKey => {
    const day = T(dayKey);
    const row = document.createElement('div');
    row.className = 'avail-day-row';
    row.innerHTML = `
      <span class="avail-day-row__label">${day}</span>
      <input type="time" value="09:00" aria-label="${day} start time" />
      <span style="color:var(--color-text-light);font-size:0.8rem;">${toLabel}</span>
      <input type="time" value="17:00" aria-label="${day} end time" />
      <label class="avail-day-off-label">
        <input type="checkbox" aria-label="${day} day off" /> ${offLabel}
      </label>
    `;
    container.appendChild(row);
  });
}

function initCategories() {
  const grid = document.getElementById('categories-grid');
  if (!grid) return;
  const account = getAccount();
  const saved = account?.skills || [];
  const T2 = typeof window.t === 'function' ? window.t.bind(window) : (k) => k;
  SKILLS_KEYS.forEach(skillKey => {
    const skill = T2(skillKey);
    const label = document.createElement('label');
    const checked = saved.includes(skill) ? 'checked' : '';
    label.innerHTML = `<input type="checkbox" ${checked} /><span>${skill}</span>`;
    grid.appendChild(label);
  });
}

function initJobQueue() {
  document.querySelectorAll('[data-accept]').forEach(btn => {
    btn.addEventListener('click', () => {
      const actionsEl = btn.closest('.dash-card').querySelector('.dash-card__actions');
      const acceptedLabel = typeof window.t === 'function' ? window.t('jq_accepted_badge') : 'Accepted';
      actionsEl.innerHTML = `<span class="badge badge--confirmed">${acceptedLabel}</span>`;
    });
  });
  document.querySelectorAll('[data-decline]').forEach(btn => {
    btn.addEventListener('click', () => btn.closest('.dash-card').remove());
  });
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

  function setFieldState(input, valid, message) {
    input.classList.toggle('is-valid', valid);
    input.classList.toggle('is-invalid', !valid);
    let errorEl = input.parentElement.querySelector('.field-error');
    if (!valid && message) {
      if (!errorEl) {
        errorEl = document.createElement('span');
        errorEl.className = 'field-error';
        // If inside .input-password-wrap, append to parent form-field
        const wrap = input.closest('.input-password-wrap');
        if (wrap) {
          wrap.parentElement.appendChild(errorEl);
        } else {
          input.parentElement.appendChild(errorEl);
        }
      }
      errorEl.textContent = message;
    } else if (errorEl) {
      errorEl.remove();
    }
  }

  function clearFieldState(input) {
    input.classList.remove('is-valid', 'is-invalid');
    const wrap = input.closest('.input-password-wrap');
    const container = wrap ? wrap.parentElement : input.parentElement;
    const errorEl = container.querySelector('.field-error');
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

  function validatePasswordMatch() {
    if (!newPasswordInput || !confirmPasswordInput) return;
    const newVal = newPasswordInput.value;
    const confirmVal = confirmPasswordInput.value;
    if (!newVal && !confirmVal) {
      clearFieldState(newPasswordInput);
      clearFieldState(confirmPasswordInput);
      return;
    }
    if (confirmVal && newVal !== confirmVal) {
      setFieldState(confirmPasswordInput, false, typeof window.t === 'function' ? window.t('err_pw_mismatch') : 'Passwords do not match.');
    } else if (confirmVal) {
      setFieldState(confirmPasswordInput, true, '');
    }
  }

  if (confirmPasswordInput) {
    confirmPasswordInput.addEventListener('blur', validatePasswordMatch);
    confirmPasswordInput.addEventListener('input', validatePasswordMatch);
  }
  if (newPasswordInput) {
    newPasswordInput.addEventListener('input', () => {
      if (confirmPasswordInput && confirmPasswordInput.value) validatePasswordMatch();
    });
  }
}

function initSettingsForm() {
  const form = document.querySelector('[data-settings-form]');
  if (!form) return;

  // Fix 5: Change Photo button with FileReader preview
  const changePhotoBtn = document.getElementById('btn-change-photo');
  const photoUploadInput = document.getElementById('photo-upload-input');
  const preview = document.querySelector('[data-avatar-preview]');

  if (changePhotoBtn && photoUploadInput) {
    changePhotoBtn.addEventListener('click', () => photoUploadInput.click());
    photoUploadInput.addEventListener('change', () => {
      const file = photoUploadInput.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (e) => {
        if (preview) {
          preview.innerHTML = `<img src="${e.target.result}" alt="Profile photo" style="width:100%;height:100%;object-fit:cover;border-radius:50%;" />`;
        }
        // Also update topbar avatar with image
        const topbarAvatar = document.getElementById('topbar-avatar');
        if (topbarAvatar) {
          topbarAvatar.innerHTML = `<img src="${e.target.result}" alt="Profile photo" style="width:100%;height:100%;object-fit:cover;border-radius:50%;" />`;
        }
      };
      reader.readAsDataURL(file);
    });
  }

  form.addEventListener('submit', (e) => {
    e.preventDefault();
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
    showToast(typeof window.t === 'function' ? window.t('toast_settings_saved') : 'Your changes have been saved.', 'success');
  });

  // Delete account button (Fix 3)
  const deleteBtn = document.getElementById('btn-delete-account');
  if (deleteBtn) {
    deleteBtn.addEventListener('click', () => {
      showToast(typeof window.t === 'function' ? window.t('toast_delete_demo') : 'Account deletion is not available in demo mode.', 'info');
    });
  }

  const saveAvailBtn = document.getElementById('save-availability');
  const availSaveMsg = document.querySelector('[data-avail-save-msg]');
  if (saveAvailBtn && availSaveMsg) {
    saveAvailBtn.addEventListener('click', () => {
      availSaveMsg.hidden = false;
      setTimeout(() => { availSaveMsg.hidden = true; }, 2500);
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
  const fields = ['fullName', 'email', 'phone', 'address', 'specialty'];
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
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const currentPw = form.querySelector('#s-current-password');
    const newPw     = form.querySelector('#s-new-password');
    const confirmPw = form.querySelector('#s-confirm-password');
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

populateProfile();
populateStats();
updateWelcomeText();
initTabs();
initTopbarAvatar();
initAvailabilitySchedule();
initCategories();
initJobQueue();
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

/* Re-render dynamic grids and welcome text on language change */
document.addEventListener('langchange', () => {
  updateWelcomeText();
  const scheduleContainer = document.getElementById('avail-schedule');
  if (scheduleContainer) { scheduleContainer.innerHTML = ''; initAvailabilitySchedule(); }
  const categoriesGrid = document.getElementById('categories-grid');
  if (categoriesGrid) { categoriesGrid.innerHTML = ''; initCategories(); }
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

  // Arrival state machine
  document.querySelectorAll('.arrival-flow').forEach(flow => {
    const bookingId = flow.dataset.bookingId;
    const correctPin = flow.dataset.pin;
    const key = `servio_job_state_${bookingId}`;

    // Determine initial state from HTML (whichever arrival-state does not have hidden attr)
    const visibleState = flow.querySelector('.arrival-state:not([hidden])');
    let currentState = visibleState?.dataset.state || 'pending';
    // Check localStorage override
    const stored = localStorage.getItem(key);
    if (stored) {
      currentState = stored;
      showArrivalState(flow, currentState);
    }

    let timerInterval;
    let seconds = 0;

    function showArrivalState(flowEl, state) {
      flowEl.querySelectorAll('.arrival-state').forEach(el => el.hidden = true);
      const target = flowEl.querySelector(`[data-state="${state}"]`);
      if (target) target.hidden = false;
      localStorage.setItem(key, state);
      currentState = state;
      if (state === 'in-progress') startTimer(bookingId);
    }

    function startTimer(id) {
      const el = document.getElementById(`jobTimer-${id}`) || document.getElementById(`timer-${id}`);
      clearInterval(timerInterval);
      seconds = 0;
      timerInterval = setInterval(() => {
        seconds++;
        const h = String(Math.floor(seconds/3600)).padStart(2,'0');
        const m = String(Math.floor((seconds%3600)/60)).padStart(2,'0');
        const s = String(seconds%60).padStart(2,'0');
        if (el) el.textContent = `${h}:${m}:${s}`;
      }, 1000);
    }

    flow.addEventListener('click', e => {
      const action = e.target.closest('[data-action], [data-flow-action]');
      const actionName = action?.dataset.action || action?.dataset.flowAction;
      if (!actionName) return;
      if (actionName === 'accept-job' || actionName === 'accept')   showArrivalState(flow, 'accepted');
      if (actionName === 'decline-job' || actionName === 'decline') { const declineMsg = typeof window.t === 'function' ? window.t('tech_decline') + '?' : 'Decline this job?'; if (confirm(declineMsg)) flow.closest('.jq-card, article, .dash-card')?.remove(); }
      if (actionName === 'on-my-way')    showArrivalState(flow, 'en-route');
      if (actionName === 'arrived')      showArrivalState(flow, 'arrived');
      if (actionName === 'start-job') {
        const input = flow.querySelector('.pin-input');
        const errEl = flow.querySelector('.pin-error');
        if (input && input.value === correctPin) {
          showArrivalState(flow, 'in-progress');
        } else if (errEl) {
          errEl.hidden = false;
        }
      }
      if (actionName === 'complete-job' || actionName === 'complete') showArrivalState(flow, 'complete');
      if (actionName === 'submit-complete') {
        showToast(typeof window.t === 'function' ? window.t('tech_status_completed') : 'Job marked complete!', 'success');
        flow.closest('.jq-card, article, .dash-card')?.classList.add('is-completed');
      }
    });
  });

  // Liability: Pay Now
  document.getElementById('payLiabilityBtn')?.addEventListener('click', () => {
    const el = document.getElementById('liabilityAmount');
    if (el) el.textContent = '0 EGP';
    showToast(typeof window.t === 'function' ? window.t('toast_saved') : 'Balance cleared!', 'success');
  });

  initBioSection();
  initSocialLinks();
  initSkillTags();
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
   SKILL TAGS
───────────────────────────────────────────────────────────── */
function initSkillTags() {
  const container = document.getElementById('skill-tags');
  const saveBtn   = document.getElementById('btn-save-skills');
  const saveMsg   = document.getElementById('skills-save-msg');
  if (!container) return;

  const account = getAccount() || {};
  const saved = Array.isArray(account.skillTags) ? account.skillTags : [];

  container.querySelectorAll('.skill-tag').forEach(tag => {
    const skill = tag.dataset.skill;
    if (saved.includes(skill)) tag.setAttribute('aria-pressed', 'true');
    tag.addEventListener('click', () => {
      const pressed = tag.getAttribute('aria-pressed') === 'true';
      tag.setAttribute('aria-pressed', String(!pressed));
    });
  });

  saveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    acc.skillTags = [...container.querySelectorAll('.skill-tag[aria-pressed="true"]')]
      .map(t => t.dataset.skill);
    // Also save certifications
    const certEl = document.getElementById('s-certifications');
    if (certEl) acc.certifications = certEl.value.trim();
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
  });

  // Restore certifications
  const certEl = document.getElementById('s-certifications');
  if (certEl && account.certifications) certEl.value = account.certifications;
}

/* ─────────────────────────────────────────────────────────────
   SERVICE AREA TAGS
───────────────────────────────────────────────────────────── */
function initAreaTags() {
  const container = document.getElementById('area-tags');
  const saveBtn   = document.getElementById('btn-save-areas');
  const saveMsg   = document.getElementById('areas-save-msg');
  if (!container) return;

  const account = getAccount() || {};
  const saved = Array.isArray(account.serviceAreas) ? account.serviceAreas : [];

  container.querySelectorAll('.skill-tag').forEach(tag => {
    const area = tag.dataset.area;
    if (saved.includes(area)) tag.setAttribute('aria-pressed', 'true');
    tag.addEventListener('click', () => {
      const pressed = tag.getAttribute('aria-pressed') === 'true';
      tag.setAttribute('aria-pressed', String(!pressed));
    });
  });

  saveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    acc.serviceAreas = [...container.querySelectorAll('.skill-tag[aria-pressed="true"]')]
      .map(t => t.dataset.area);
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
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

// Initial update for dates
updateActionNeededDates();

// Re-run on language change
document.addEventListener('langchange', updateActionNeededDates);
