/* ═══════════════════════════════════════════════════════════
   technician-dashboard.js
   ═══════════════════════════════════════════════════════════ */
import { revealAll } from '../components/scroll-reveal.js';
import { showToast } from '../components/toast.js';

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
function getInitials(name) {
  return (name || '?').trim().split(/\s+/).slice(0, 2).map(w => w[0].toUpperCase()).join('');
}

/* ── Topbar title ───────────────────────────────────────── */
function updateTopbarTitle(tabName) {
  const el = document.getElementById('dash-topbar-title');
  if (el) el.textContent = tabName;
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
    updateTopbarTitle(labelKey && typeof window.t === 'function' ? window.t(labelKey) : id);
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
  if (welcomeEl) welcomeEl.textContent = `Welcome back, ${firstName}!`;

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
initDashLogout();
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
}

// .
