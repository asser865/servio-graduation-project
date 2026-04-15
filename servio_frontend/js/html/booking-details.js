(function () {
  let session = null;
  try { session = JSON.parse(localStorage.getItem('servio_session') || 'null'); } catch (_) { session = null; }
  if (!session) {
    const currentPath = window.location.pathname;
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
    const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
    window.location.href = './login.html?redirect=' + redirectParam;
    throw new Error('Unauthenticated — redirecting to login');
  }

  // ── Role Guard ──────────────────────────────────────────
  if (session.role === 'admin') {
    window.location.href = './admin-dashboard.html';
  } else if (session.role === 'technician') {
    window.location.href = './technician-dashboard.html';
  }
})();

// ─── Service name → i18n key map ─────────────────────────────────────────────
const SERVICE_KEY_MAP = {
  'pipe repair & leak fix':      'booking_svc_pipe_repair',
  'drain cleaning':              'booking_svc_drain',
  'fixture installation':        'booking_svc_fixture',
  'water heater service':        'booking_svc_water_heater',
  'full plumbing inspection':    'booking_svc_inspection',
  'emergency callout':           'booking_svc_emergency',
  'hvac maintenance':            'home_cat_hvac_maintenance',
  'a/c maintenance & hvac':      'home_cat_hvac',
  'plumbing':                    'home_cat_plumbing',
  'electrical':                  'home_cat_electrical',
  'professional cleaning':       'home_cat_cleaning',
  'painting':                    'home_cat_painting',
  'carpentry':                   'home_cat_carpentry',
  'appliance services':          'home_cat_appliance',
  'handyman tasks':              'home_cat_handyman',
  'home finishing & renovation': 'home_cat_renovation',
  'flooring':                    'home_cat_flooring',
  'drywall':                     'home_cat_drywall',
  'roofing':                     'home_cat_roofing',
  'pest control':                'home_cat_pest',
  'landscaping':                 'home_cat_landscaping',
  'installation services':       'home_cat_installation',
};

// ─── Canonical fallback booking (spec-defined demo data) ───────────────────
const DEFAULT_BOOKING = {
  id: 'S-2848',
  service: 'HVAC Maintenance',
  category: 'HVAC Maintenance',
  status: 'In Progress',
  date: 'Sun, 22 Mar 2026',
  time: '10:00 AM',
  scheduledDate: 'Sun, 22 Mar 2026',
  scheduledTime: '10:00 AM – 12:00 PM',
  duration: '~2 hours',
  location: '12 Nile View St, Maadi, Cairo',
  paymentMethod: 'Online Payment',
  paymentAmount: 'EGP 450',
  paymentStatus: 'Paid',
  pin: '7364',
  technician: {
    name: 'Hassan Ali',
    initials: 'HA',
    specialty: 'HVAC Specialist',
    rating: '4.8',
    phone: '+201000000000',
  },
};

// ─── Timeline step definitions ──────────────────────────────────────────────
function getSteps() {
  const t = (window.t || function(k){ return k; });
  return [
    { key: 'Booked',      labelKey: 'bkd_step_booked',      subKey: 'bkd_step_booked_sub' },
    { key: 'Confirmed',   labelKey: 'bkd_step_confirmed',   subKey: 'bkd_step_confirmed_sub' },
    { key: 'En Route',    labelKey: 'bkd_step_enroute',     subKey: 'bkd_step_enroute_sub' },
    { key: 'Arrived',     labelKey: 'bkd_step_arrived',     subKey: 'bkd_step_arrived_sub' },
    { key: 'In Progress', labelKey: 'bkd_step_inprogress',  subKey: 'bkd_step_inprogress_sub' },
    { key: 'Complete',    labelKey: 'bkd_step_complete',    subKey: 'bkd_step_complete_sub' }
  ].map(s => ({ ...s, label: t(s.labelKey), sub: t(s.subKey) }));
}
const TIMELINE_STEPS = null; // kept for compatibility — use getSteps() instead

// Status → badge CSS modifier
const STATUS_CLASS = {
  'Booked':      'bk-status-badge--booked',
  'Confirmed':   'bk-status-badge--confirmed',
  'En Route':    'bk-status-badge--en-route',
  'Arrived':     'bk-status-badge--confirmed',
  'In Progress': 'bk-status-badge--in-progress',
  'Complete':    'bk-status-badge--complete',
  'Cancelled':   'bk-status-badge--cancelled',
};

// ─── DOM refs ────────────────────────────────────────────────────────────────
const bkEmptyState     = document.getElementById('bkEmptyState');
const bkContent        = document.getElementById('bkContent');
const bkMobileBar      = document.getElementById('bkMobileBar');

const bkId             = document.getElementById('bkId');
const bkService        = document.getElementById('bkService');
const bkDate           = document.getElementById('bkDate');
const bkTime           = document.getElementById('bkTime');
const bkStatusBadge    = document.getElementById('bkStatusBadge');
const bkStatusText     = document.getElementById('bkStatusText');

const bkTimeline       = document.getElementById('bkTimeline');

const bkTechInitials   = document.getElementById('bkTechInitials');
const bkTechName       = document.getElementById('bkTechName');
const bkTechSpecialty  = document.getElementById('bkTechSpecialty');
const bkTechRating     = document.getElementById('bkTechRating');
const bkCallLink       = document.getElementById('bkCallLink');

const bkCategory       = document.getElementById('bkCategory');
const bkLocation       = document.getElementById('bkLocation');
const bkScheduledDate  = document.getElementById('bkScheduledDate');
const bkScheduledTime  = document.getElementById('bkScheduledTime');
const bkDuration       = document.getElementById('bkDuration');
const bkPaymentMethodDetail = document.getElementById('bkPaymentMethodDetail');

const bkPin            = document.getElementById('bkPin');
const bkPaySummaryMethod = document.getElementById('bkPaySummaryMethod');
const bkPayAmount      = document.getElementById('bkPayAmount');
const bkPayStatus      = document.getElementById('bkPayStatus');

const bkBarInitials    = document.getElementById('bkBarInitials');
const bkBarName        = document.getElementById('bkBarName');

const bkCancelBtn      = document.getElementById('bkCancelBtn');
const bkRescheduleBtn  = document.getElementById('bkRescheduleBtn');
const bkReceiptBtn     = document.getElementById('bkReceiptBtn');

const bkCancelDialog   = document.getElementById('bkCancelDialog');
const bkDialogId       = document.getElementById('bkDialogId');
const bkDialogKeep     = document.getElementById('bkDialogKeep');
const bkDialogConfirm  = document.getElementById('bkDialogConfirm');

const bkToastWrap      = document.getElementById('bkToastWrap');
const bkCancelledBannerWrap = document.getElementById('bkCancelledBannerWrap');

// ─── Load booking — default first, upgrade from localStorage if available ─────
// Always starts with canonical dummy data so the page is never blank.
// Real booking data from the flow overwrites it when present.
let booking = DEFAULT_BOOKING;
try {
  const raw = localStorage.getItem('servio_active_booking');
  if (raw) { const parsed = JSON.parse(raw); if (parsed?.id) booking = parsed; }
} catch (_) {}
if (booking === DEFAULT_BOOKING) {
  try {
    const rawList = localStorage.getItem('servio_bookings');
    if (rawList) {
      const list = JSON.parse(rawList);
      if (Array.isArray(list) && list.length > 0) {
        list.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
        if (list[0]?.id) booking = list[0];
      }
    }
  } catch (_) {}
}

// Date/Time Translation Helper
function translateDateTime(str) {
  if (!str) return '—';
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

// ─── Render ───────────────────────────────────────────────────────────────────
function renderPage(bk) {
  const t = (window.t || function(k){ return k; });
  // Header card
  bkId.textContent      = bk.id;
  const svcKey = SERVICE_KEY_MAP[(bk.service || '').toLowerCase()];
  if (svcKey) {
    bkService.setAttribute('data-i18n', svcKey);
    bkService.textContent = t(svcKey);
  } else {
    bkService.removeAttribute('data-i18n');
    bkService.textContent = bk.service;
  }
  bkDate.textContent    = translateDateTime(bk.date);
  bkTime.textContent    = translateDateTime(bk.time);

  // Status badge
  const statusKey = bk.status || 'Booked';
  const statusCls = STATUS_CLASS[statusKey] || 'bk-status-badge--booked';
  bkStatusBadge.className = `bk-status-badge ${statusCls}`;
  const transKey = 'status_' + statusKey.toLowerCase().replace(/\s+/g, '_');
  bkStatusText.setAttribute('data-i18n', transKey);
  bkStatusText.textContent = t(transKey);

  // Cancelled banner
  if (statusKey === 'Cancelled') {
    bkCancelledBannerWrap.hidden = false;
    bkCancelBtn.disabled = true;
    bkCancelBtn.style.opacity = '0.45';
    bkCancelBtn.style.pointerEvents = 'none';
  }

  // Timeline
  renderTimeline(statusKey);

  // Technician
  const tech = bk.technician || {};
  bkTechInitials.textContent = tech.initials || getInitials(tech.name || '');
  bkTechName.textContent     = tech.name      || '—';
  const roleKey = 'tech_role_hvac';
  bkTechSpecialty.setAttribute('data-i18n', roleKey);
  bkTechSpecialty.textContent = t(roleKey) || tech.specialty || '—';
  bkTechRating.textContent   = tech.rating    || '—';
  if (tech.phone) bkCallLink.href = `tel:${tech.phone}`;

  // Job details
  const catKey = 'home_cat_' + (bk.category || bk.service || '').toLowerCase().replace(' ', '_');
  bkCategory.setAttribute('data-i18n', catKey);
  bkCategory.textContent = t(catKey) || bk.category || bk.service || '—';

  bkLocation.textContent             = bk.location       || '—';
  bkScheduledDate.textContent        = translateDateTime(bk.scheduledDate  || bk.date);
  bkScheduledTime.textContent        = translateDateTime(bk.scheduledTime  || bk.time);
  bkDuration.textContent             = bk.duration       || '—';

  const payMethKey = 'payment_' + (bk.paymentMethod || '').toLowerCase().replace(' ', '_');
  bkPaymentMethodDetail.setAttribute('data-i18n', payMethKey);
  bkPaymentMethodDetail.textContent  = t(payMethKey) || bk.paymentMethod || '—';

  // PIN — space out digits for readability
  const pin = String(bk.pin || '7429');
  bkPin.textContent = pin.split('').join(' ');

  // Payment summary
  bkPaySummaryMethod.setAttribute('data-i18n', payMethKey);
  bkPaySummaryMethod.textContent = t(payMethKey) || bk.paymentMethod || '—';
  bkPayAmount.textContent = bk.paymentAmount || '—';
  const payStatusKey = 'status_' + (bk.paymentStatus || 'Pending').toLowerCase().replace(' ', '_');
  bkPayStatus.setAttribute('data-i18n', payStatusKey);
  bkPayStatus.textContent = t(payStatusKey) || bk.paymentStatus || 'Pending';

  // Mobile bar
  bkBarInitials.textContent = tech.initials || getInitials(tech.name || '');
  bkBarName.textContent     = tech.name     || '—';

  // Dialog booking ID
  if (bkDialogId) bkDialogId.textContent = bk.id;
}

function renderTimeline(currentStatus) {
  const steps = getSteps();
  const currentIndex = steps.findIndex(s => s.key === currentStatus);
  const isCancelled = currentStatus === 'Cancelled';
  const t = window.t || function(k){ return k; };

  bkTimeline.innerHTML = '';
  steps.forEach((step, i) => {
    let state;
    if (isCancelled) {
      state = i < currentIndex ? 'done' : 'pending';
    } else {
      if (i < currentIndex)      state = 'done';
      else if (i === currentIndex) state = 'active';
      else                         state = 'pending';
    }

    const li = document.createElement('li');
    li.className = `bk-timeline__step bk-timeline__step--${state}`;

    let iconSvg;
    if (state === 'done') {
      iconSvg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>`;
    } else if (state === 'active') {
      iconSvg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4" fill="currentColor"/></svg>`;
    } else {
      iconSvg = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/></svg>`;
    }

    const ariaLabel = state === 'done' ? t('bkd_step_state_done') || 'Completed'
                    : state === 'active' ? t('bkd_step_state_active') || 'Current step'
                    : t('bkd_step_state_pending') || 'Pending';

    li.innerHTML = `
      <div class="bk-timeline__node" aria-label="${ariaLabel}">
        ${iconSvg}
      </div>
      <div class="bk-timeline__content">
        <span class="bk-timeline__label" data-i18n="${step.labelKey}">${step.label}</span>
        <span class="bk-timeline__sub" data-i18n="${step.subKey}">${step.sub}</span>
      </div>
    `;
    bkTimeline.appendChild(li);
  });
}

function getInitials(name) {
  return name
    .split(' ')
    .map(w => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();
}

// ─── Always render content — empty state is never shown in demo mode ──────────
// Use style.display (inline) so it overrides the CSS display:flex on .bk-empty
bkEmptyState.style.display = 'none';
bkContent.style.display    = 'block';
renderPage(booking);

// ─── Cancel dialog ────────────────────────────────────────────────────────────
bkCancelBtn.addEventListener('click', () => {
  bkCancelDialog.hidden = false;
  bkDialogKeep.focus();
});

bkDialogKeep.addEventListener('click', () => {
  bkCancelDialog.hidden = true;
  bkCancelBtn.focus();
});

bkDialogConfirm.addEventListener('click', () => {
  bkCancelDialog.hidden = true;

  // Update booking status
  booking.status = 'Cancelled';
  try {
    if (localStorage.getItem('servio_active_booking')) {
      localStorage.setItem('servio_active_booking', JSON.stringify(booking));
    }
  } catch (_) {}

  // Re-render with cancelled state
  renderPage(booking);

  // Disable cancel btn
  bkCancelBtn.disabled = true;
  bkCancelBtn.style.opacity = '0.45';
  bkCancelBtn.style.pointerEvents = 'none';

  showToast((window.getLang || function(k){return k;})('bkd_toast_cancelled'), 'danger');
});

// Close dialog on overlay click
bkCancelDialog.addEventListener('click', (e) => {
  if (e.target === bkCancelDialog) {
    bkCancelDialog.hidden = true;
    bkCancelBtn.focus();
  }
});

// Close dialog on Escape
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !bkCancelDialog.hidden) {
    bkCancelDialog.hidden = true;
    bkCancelBtn.focus();
  }
});

// ─── Reschedule functionality ──────────────────────────────────────────────
const bkRescheduleDialog  = document.getElementById('bkRescheduleDialog');
const bkRsDialogCancel     = document.getElementById('bkRsDialogCancel');
const bkRsDialogConfirm    = document.getElementById('bkRsDialogConfirm');
const newBookingDate       = document.getElementById('newBookingDate');
const newBookingSlot       = document.getElementById('newBookingSlot');

bkRescheduleBtn.addEventListener('click', () => {
  if (booking.status === 'Cancelled') {
    showToast((window.getLang || function(k){return k;})('bkd_toast_no_reschedule'), 'warning');
    return;
  }
  // Pre-fill date (default to tomorrow)
  const today = new Date();
  today.setDate(today.getDate() + 1); 
  const yyyy = today.getFullYear();
  const mm = String(today.getMonth() + 1).padStart(2, '0');
  const dd = String(today.getDate()).padStart(2, '0');
  newBookingDate.value = `${yyyy}-${mm}-${dd}`;
  newBookingDate.min = `${yyyy}-${mm}-${dd}`;
  
  bkRescheduleDialog.hidden = false;
});

bkRsDialogCancel.addEventListener('click', () => {
  bkRescheduleDialog.hidden = true;
});

bkRsDialogConfirm.addEventListener('click', () => {
  const dateVal = newBookingDate.value;
  const slotVal = newBookingSlot.value;

  if (!dateVal) {
    showToast((window.getLang || function(k){return k;})('bkd_toast_select_date'), 'warning');
    return;
  }

  // Format the date for display (e.g. Thu, 27 Mar 2026)
  const d = new Date(dateVal);
  const options = { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' };
  const formattedDate = d.toLocaleDateString('en-US', options);

  // Apply changes
  booking.date = formattedDate;
  booking.scheduledDate = formattedDate;
  booking.time = slotVal.split(' – ')[0];
  booking.scheduledTime = slotVal;

  // Persist
  try {
    localStorage.setItem('servio_active_booking', JSON.stringify(booking));
    // Also update in list if it came from there
    const rawList = localStorage.getItem('servio_bookings');
    if (rawList) {
      const list = JSON.parse(rawList);
      const idx = list.findIndex(b => b.id === booking.id);
      if (idx !== -1) {
        list[idx] = { ...list[idx], ...booking };
        localStorage.setItem('servio_bookings', JSON.stringify(list));
      }
    }
  } catch (_) {}

  renderPage(booking);
  bkRescheduleDialog.hidden = true;
  showToast((window.getLang || function(k){return k;})('bkd_toast_rescheduled'), 'success');
});

// Reschedule dialog overlay click
bkRescheduleDialog.addEventListener('click', (e) => {
  if (e.target === bkRescheduleDialog) {
    bkRescheduleDialog.hidden = true;
  }
});

bkReceiptBtn.addEventListener('click', () => {
  showToast((window.t || function(k){return k;})('bkd_toast_receipt'), 'info');
});

// ─── Toast system ─────────────────────────────────────────────────────────────
/**
 * @param {string} message
 * @param {'success'|'info'|'warning'|'danger'} type
 * @param {number} duration ms
 */
function showToast(message, type = 'info', duration = 3800) {
  const icons = {
    success: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`,
    info:    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`,
    warning: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`,
    danger:  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`,
  };

  const toast = document.createElement('div');
  toast.className = `bk-toast bk-toast--${type}`;
  toast.innerHTML = `
    <span class="bk-toast__icon" aria-hidden="true">${icons[type] || icons.info}</span>
    <span class="bk-toast__text">${message}</span>
  `;
  bkToastWrap.appendChild(toast);

  // Auto dismiss
  const remove = () => {
    toast.classList.add('bk-toast--out');
    toast.addEventListener('animationend', () => toast.remove(), { once: true });
  };
  setTimeout(remove, duration);
}

// .
