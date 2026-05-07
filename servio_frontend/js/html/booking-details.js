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

import { getBooking, cancelBooking } from '../api/bookings.js';

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

// ─── Map API status → display status ─────────────────────────────────────────
function mapApiStatus(s) {
  const map = {
    pending:     'Booked',
    accepted:    'Confirmed',
    in_progress: 'In Progress',
    completed:   'Complete',
    cancelled:   'Cancelled',
    rejected:    'Cancelled',
  };
  return map[s] || s || 'Booked';
}

// ─── Map an API booking object → the shape renderPage expects ─────────────────
function mapApiBooking(b) {
  const workerName     = b.worker?.name || '';
  const workerInitials = workerName
    ? workerName.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase()
    : 'T';

  // Derive specialty from worker's categories/skills list
  const workerSkills = b.worker?.categories || b.worker?.skills || [];
  const workerSpecialty = Array.isArray(workerSkills) && workerSkills.length
    ? workerSkills[0]
    : (b.worker?.specialty || b.service?.category || '—');

  return {
    id:            b._id,
    _id:           b._id,
    service:       b.service?.title || b.serviceId || 'Service',
    category:      b.service?.category || b.service?.title || '',
    status:        mapApiStatus(b.status),
    rawStatus:     b.status,
    date:          b.scheduledDate
      ? new Date(b.scheduledDate).toLocaleDateString('en-US', { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' })
      : '—',
    scheduledDate: b.scheduledDate
      ? new Date(b.scheduledDate).toLocaleDateString('en-US', { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' })
      : '—',
    time:          b.scheduledTime || '—',
    scheduledTime: b.scheduledTime || '—',
    duration:      b.duration || '—',
    location:      b.address || '—',
    paymentMethod: b.paymentMethod === 'cash' ? 'Cash' : 'Online Payment',
    paymentAmount: b.totalPrice != null
      ? `EGP ${Number(b.totalPrice).toLocaleString('en-US')}`
      : (b.amount != null ? `EGP ${(b.amount / 100).toFixed(2)}` : '—'),
    paymentStatus: b.paymentStatus || 'Pending',
    pin:           b.pin || '—',
    technician: {
      name:      workerName || '—',
      initials:  workerInitials,
      specialty: workerSpecialty,
      rating:    b.worker?.averageRating != null ? Number(b.worker.averageRating).toFixed(1) : '—',
      phone:     b.worker?.phone || '',
    },
  };
}

// ─── Show skeleton while loading ──────────────────────────────────────────────
function showSkeleton() {
  bkEmptyState.style.display = 'none';
  bkContent.style.display    = 'block';

  const skeletonText = '—';
  if (bkId)            bkId.textContent           = '…';
  if (bkService)       bkService.textContent       = '…';
  if (bkDate)          bkDate.textContent          = '…';
  if (bkTime)          bkTime.textContent          = '…';
  if (bkTechName)      bkTechName.textContent      = '…';
  if (bkTechInitials)  bkTechInitials.textContent  = '…';
  if (bkTechSpecialty) bkTechSpecialty.textContent = '…';
  if (bkTechRating)    bkTechRating.textContent    = '…';
  if (bkLocation)      bkLocation.textContent      = '…';
  if (bkPayAmount)     bkPayAmount.textContent     = '…';
}

// ─── Show empty state when no booking is available ────────────────────────────
function showEmptyState() {
  bkContent.style.display    = 'none';
  bkEmptyState.style.display = '';
  // If empty state has a CTA link, ensure it navigates to the dashboard
  const cta = bkEmptyState.querySelector('a, button[data-href]');
  if (cta && !cta.href) cta.href = './customer-dashboard.html';
}

// ─── Date/Time Translation Helper ─────────────────────────────────────────────
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
    'Sun': 'الأحد', 'Mon': 'الاثنين', 'Tue': 'الثلاثاء', 'Wed': 'الأربعاء',
    'Thu': 'الخميس', 'Fri': 'الجمعة', 'Sat': 'السبت',
  };
  const ampmMap = { 'AM': 'صباحاً', 'PM': 'مساءً' };

  let res = str;
  Object.keys(monthsMap).forEach(k => { res = res.replace(new RegExp('\\b' + k + '\\b', 'g'), monthsMap[k]); });
  Object.keys(ampmMap).forEach(k => { res = res.replace(new RegExp('\\b' + k + '\\b', 'g'), ampmMap[k]); });
  return res;
}

// ─── Render ───────────────────────────────────────────────────────────────────
function renderPage(bk) {
  const t = (window.t || function(k){ return k; });

  bkEmptyState.style.display = 'none';
  bkContent.style.display    = 'block';

  // Header card
  bkId.textContent = bk.id;
  const svcKey = SERVICE_KEY_MAP[(bk.service || '').toLowerCase()];
  if (svcKey) {
    bkService.setAttribute('data-i18n', svcKey);
    bkService.textContent = t(svcKey);
  } else {
    bkService.removeAttribute('data-i18n');
    bkService.textContent = bk.service;
  }
  bkDate.textContent = translateDateTime(bk.date);
  bkTime.textContent = translateDateTime(bk.time);

  // Status badge
  const statusKey = bk.status || 'Booked';
  const statusCls = STATUS_CLASS[statusKey] || 'bk-status-badge--booked';
  bkStatusBadge.className = `bk-status-badge ${statusCls}`;
  const transKey = 'status_' + statusKey.toLowerCase().replace(/\s+/g, '_');
  bkStatusText.setAttribute('data-i18n', transKey);
  bkStatusText.textContent = t(transKey);

  // Cancelled banner
  if (statusKey === 'Cancelled') {
    if (bkCancelledBannerWrap) bkCancelledBannerWrap.hidden = false;
    bkCancelBtn.disabled = true;
    bkCancelBtn.style.opacity = '0.45';
    bkCancelBtn.style.pointerEvents = 'none';
  } else {
    if (bkCancelledBannerWrap) bkCancelledBannerWrap.hidden = true;
    bkCancelBtn.disabled = false;
    bkCancelBtn.style.opacity = '';
    bkCancelBtn.style.pointerEvents = '';
  }

  // Timeline
  renderTimeline(statusKey);

  // Technician
  const tech = bk.technician || {};
  bkTechInitials.textContent = tech.initials || getInitials(tech.name || '');
  bkTechName.textContent     = tech.name || '—';

  // Use the actual specialty from the worker — not a hardcoded i18n key
  const specialty = tech.specialty || '—';
  bkTechSpecialty.removeAttribute('data-i18n');
  bkTechSpecialty.textContent = specialty;

  bkTechRating.textContent = tech.rating || '—';
  if (tech.phone) bkCallLink.href = `tel:${tech.phone}`;
  else bkCallLink.removeAttribute('href');

  // Job details
  const catStr = (bk.category || bk.service || '').toLowerCase().replace(/\s+/g, '_');
  const catKey = 'home_cat_' + catStr;
  const catTranslated = t(catKey);
  if (catTranslated && catTranslated !== catKey) {
    bkCategory.setAttribute('data-i18n', catKey);
    bkCategory.textContent = catTranslated;
  } else {
    bkCategory.removeAttribute('data-i18n');
    bkCategory.textContent = bk.category || bk.service || '—';
  }

  bkLocation.textContent      = bk.location || '—';
  bkScheduledDate.textContent = translateDateTime(bk.scheduledDate || bk.date);
  bkScheduledTime.textContent = translateDateTime(bk.scheduledTime || bk.time);
  bkDuration.textContent      = bk.duration || '—';

  const payMethKey = 'payment_' + (bk.paymentMethod || '').toLowerCase().replace(/\s+/g, '_');
  const payMethTranslated = t(payMethKey);
  if (payMethTranslated && payMethTranslated !== payMethKey) {
    bkPaymentMethodDetail.setAttribute('data-i18n', payMethKey);
    bkPaymentMethodDetail.textContent = payMethTranslated;
  } else {
    bkPaymentMethodDetail.removeAttribute('data-i18n');
    bkPaymentMethodDetail.textContent = bk.paymentMethod || '—';
  }

  // PIN — space out digits for readability
  const pin = bk.pin && bk.pin !== '—' ? String(bk.pin) : null;
  bkPin.textContent = pin ? pin.split('').join(' ') : (t('bkd_pin_unavailable') || 'PIN not available');

  // Payment summary
  bkPaySummaryMethod.textContent = bkPaymentMethodDetail.textContent;
  bkPayAmount.textContent = bk.paymentAmount || '—';
  const payStatusKey = 'status_' + (bk.paymentStatus || 'pending').toLowerCase().replace(/\s+/g, '_');
  bkPayStatus.textContent = t(payStatusKey) || bk.paymentStatus || 'Pending';

  // Mobile bar
  bkBarInitials.textContent = tech.initials || getInitials(tech.name || '');
  bkBarName.textContent     = tech.name || '—';

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
      if (i < currentIndex)        state = 'done';
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

    const ariaLabel = state === 'done'   ? (t('bkd_step_state_done')   || 'Completed')
                    : state === 'active' ? (t('bkd_step_state_active') || 'Current step')
                    :                      (t('bkd_step_state_pending') || 'Pending');

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
  return name.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
}

// ─── Booking state (starts empty — always loaded from API) ────────────────────
let booking = null;

// ─── Main load logic ──────────────────────────────────────────────────────────
const _bookingIdFromUrl = new URLSearchParams(window.location.search).get('id');

async function loadBooking() {
  // 1. If URL has ?id= → fetch from API (authoritative)
  if (_bookingIdFromUrl) {
    showSkeleton();
    try {
      const b = await getBooking(_bookingIdFromUrl);
      if (!b?._id) { showEmptyState(); return; }
      booking = mapApiBooking(b);
      renderPage(booking);
      // Persist so back-navigation keeps the last viewed booking
      try { localStorage.setItem('servio_active_booking', JSON.stringify(booking)); } catch (_) {}
    } catch (err) {
      // Try localStorage fallback
      const cached = tryLoadFromStorage(_bookingIdFromUrl);
      if (cached) { booking = cached; renderPage(booking); showToast(t_('bkd_toast_cached_data') || 'Showing cached data', 'info'); }
      else showEmptyState();
    }
    return;
  }

  // Helper: a real MongoDB ObjectId is 24 hex characters
  function isRealId(id) {
    return typeof id === 'string' && /^[a-f0-9]{24}$/i.test(id);
  }

  // 2. No URL param — look for a real booking ID in localStorage, then fetch from API
  let candidateId = null;

  try {
    const raw = localStorage.getItem('servio_active_booking');
    if (raw) {
      const parsed = JSON.parse(raw);
      const id = parsed?._id || parsed?.bookingId || parsed?.id;
      if (isRealId(id)) candidateId = id;
      // If only a fake S- id, wipe the stale entry so it never shows again
      else if (parsed?.id) {
        try { localStorage.removeItem('servio_active_booking'); } catch (_) {}
      }
    }
  } catch (_) {}

  if (!candidateId) {
    // 3. Fall back to most-recent real booking in the list
    try {
      const rawList = localStorage.getItem('servio_bookings');
      if (rawList) {
        const list = JSON.parse(rawList);
        if (Array.isArray(list)) {
          const sorted = list
            .filter(b => isRealId(b?._id || b?.bookingId || b?.id))
            .sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
          if (sorted.length > 0) {
            candidateId = sorted[0]._id || sorted[0].bookingId || sorted[0].id;
          }
        }
      }
    } catch (_) {}
  }

  if (candidateId) {
    showSkeleton();
    try {
      const b = await getBooking(candidateId);
      if (!b?._id) { showEmptyState(); return; }
      booking = mapApiBooking(b);
      renderPage(booking);
      try { localStorage.setItem('servio_active_booking', JSON.stringify(booking)); } catch (_) {}
    } catch (_) {
      showEmptyState();
    }
    return;
  }

  // 4. Nothing valid found → empty state
  showEmptyState();
}

function t_(key) { return typeof window.t === 'function' ? window.t(key) : key; }

function tryLoadFromStorage(id) {
  try {
    const raw = localStorage.getItem('servio_active_booking');
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && (parsed._id === id || parsed.id === id)) return parsed;
    }
    const rawList = localStorage.getItem('servio_bookings');
    if (rawList) {
      const list = JSON.parse(rawList);
      if (Array.isArray(list)) {
        const found = list.find(b => b._id === id || b.id === id);
        if (found) return found;
      }
    }
  } catch (_) {}
  return null;
}

loadBooking();

// ─── Cancel dialog ────────────────────────────────────────────────────────────
bkCancelBtn.addEventListener('click', () => {
  if (!booking) return;
  bkCancelDialog.hidden = false;
  bkDialogKeep.focus();
});

bkDialogKeep.addEventListener('click', () => {
  bkCancelDialog.hidden = true;
  bkCancelBtn.focus();
});

bkDialogConfirm.addEventListener('click', async () => {
  bkCancelDialog.hidden = true;
  if (!booking) return;

  const prevStatus = booking.status;
  booking.status = 'Cancelled';

  try { localStorage.setItem('servio_active_booking', JSON.stringify(booking)); } catch (_) {}

  renderPage(booking);

  const id = booking._id || booking.id;
  if (id && !id.startsWith('S-')) {
    try {
      await cancelBooking(id);
    } catch (err) {
      // Revert on failure
      booking.status = prevStatus;
      try { localStorage.setItem('servio_active_booking', JSON.stringify(booking)); } catch (_) {}
      renderPage(booking);
      showToast(t_('bkd_toast_cancel_failed') || 'Could not cancel booking. Please try again.', 'danger');
      return;
    }
  }

  showToast(t_('bkd_toast_cancelled') || 'Booking cancelled.', 'danger');
});

// Close dialog on overlay click or Escape
bkCancelDialog.addEventListener('click', (e) => {
  if (e.target === bkCancelDialog) { bkCancelDialog.hidden = true; bkCancelBtn.focus(); }
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !bkCancelDialog.hidden) { bkCancelDialog.hidden = true; bkCancelBtn.focus(); }
});

// ─── Reschedule functionality ──────────────────────────────────────────────
const bkRescheduleDialog = document.getElementById('bkRescheduleDialog');
const bkRsDialogCancel   = document.getElementById('bkRsDialogCancel');
const bkRsDialogConfirm  = document.getElementById('bkRsDialogConfirm');
const newBookingDate      = document.getElementById('newBookingDate');
const newBookingSlot      = document.getElementById('newBookingSlot');

bkRescheduleBtn.addEventListener('click', () => {
  if (!booking || booking.status === 'Cancelled') {
    showToast(t_('bkd_toast_no_reschedule') || 'Cannot reschedule a cancelled booking.', 'warning');
    return;
  }
  const today = new Date();
  today.setDate(today.getDate() + 1);
  const yyyy = today.getFullYear();
  const mm   = String(today.getMonth() + 1).padStart(2, '0');
  const dd   = String(today.getDate()).padStart(2, '0');
  newBookingDate.value = `${yyyy}-${mm}-${dd}`;
  newBookingDate.min   = `${yyyy}-${mm}-${dd}`;
  bkRescheduleDialog.hidden = false;
});

bkRsDialogCancel.addEventListener('click', () => { bkRescheduleDialog.hidden = true; });

bkRsDialogConfirm.addEventListener('click', () => {
  const dateVal = newBookingDate.value;
  const slotVal = newBookingSlot.value;
  if (!dateVal) { showToast(t_('bkd_toast_select_date') || 'Please select a date.', 'warning'); return; }

  const d = new Date(dateVal);
  const formattedDate = d.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });

  booking.date          = formattedDate;
  booking.scheduledDate = formattedDate;
  booking.time          = slotVal.split(' – ')[0];
  booking.scheduledTime = slotVal;

  try {
    localStorage.setItem('servio_active_booking', JSON.stringify(booking));
    const rawList = localStorage.getItem('servio_bookings');
    if (rawList) {
      const list = JSON.parse(rawList);
      const idx = list.findIndex(b => b.id === booking.id || b._id === booking._id);
      if (idx !== -1) { list[idx] = { ...list[idx], ...booking }; localStorage.setItem('servio_bookings', JSON.stringify(list)); }
    }
  } catch (_) {}

  renderPage(booking);
  bkRescheduleDialog.hidden = true;
  showToast(t_('bkd_toast_rescheduled') || 'Booking rescheduled.', 'success');
});

bkRescheduleDialog.addEventListener('click', (e) => {
  if (e.target === bkRescheduleDialog) bkRescheduleDialog.hidden = true;
});

bkReceiptBtn.addEventListener('click', () => {
  showToast(t_('bkd_toast_receipt') || 'Receipt functionality coming soon.', 'info');
});

// ─── Toast system ─────────────────────────────────────────────────────────────
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

  const remove = () => {
    toast.classList.add('bk-toast--out');
    toast.addEventListener('animationend', () => toast.remove(), { once: true });
  };
  setTimeout(remove, duration);
}
