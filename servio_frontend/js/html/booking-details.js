(function () {
  let session = null;
  try { session = JSON.parse(localStorage.getItem('servio_session') || 'null'); } catch (_) { session = null; }
  if (!session) {
    const currentPath = window.location.pathname;
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
    const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
    window.location.href = './login.html?redirect=' + redirectParam;
    throw new Error('Unauthenticated - redirecting to login');
  }

  if (session.role === 'admin') {
    window.location.href = './admin-dashboard.html';
  } else if (session.role === 'technician') {
    window.location.href = './technician-dashboard.html';
  }
})();

import { getBooking, cancelBooking, rescheduleBooking } from '../api/bookings.js';
import { snapshotFeeFromBooking, formatMoney as formatFeeMoney, paymentMethodLabel } from '../utils/fee.js';
import { holdPayment, confirmCompletion, openDispute } from '../api/payments.js';
import { createSupportIssue } from '../api/support.js';
import { openCardPickerModal } from '../components/card-picker-modal.js';
import { uploadPublicFile } from '../api/uploads.js';

const POLL_MS = 45000;
const FINAL_STATUSES = new Set(['completed', 'cancelled', 'rejected', 'disputed']);
const TRACKER_STEPS = ['pending', 'accepted', 'en_route', 'arrived', 'in_progress', 'completed'];
const ACTIVE_STATUSES = new Set(['pending', 'accepted', 'en_route', 'arrived', 'in_progress']);
const CANCELLABLE_STATUSES = new Set(['pending']);
const RESCHEDULABLE_STATUSES = new Set(['pending', 'accepted']);
const DISPUTABLE_STATUSES = new Set(['awaiting_customer_confirmation']);
const SUPPORT_ISSUE_STATUSES = new Set(['accepted', 'en_route', 'arrived', 'in_progress', 'completed']);

const STATUS_UI = {
  pending: {
    label: 'Request Sent',
    eyebrow: 'Awaiting technician confirmation',
    body: 'Your request is reserved while the technician confirms availability.',
    badge: 'warning',
    nextTitle: 'Technician response pending',
    nextBody: 'Most technicians respond within 30 minutes. If the window passes, support can help you find another professional.',
    primary: 'Message Technician',
    policy: 'Free cancellation while the request is awaiting confirmation.',
  },
  accepted: {
    label: 'Booking Confirmed',
    eyebrow: 'Technician assigned',
    body: 'Your technician confirmed the appointment and will update the trip status here.',
    badge: 'success',
    nextTitle: 'Technician preparing',
    nextBody: 'You will see live updates when the technician starts heading to your address.',
    primary: 'Message Technician',
    policy: 'You can reschedule before the technician starts travelling.',
  },
  en_route: {
    label: 'Technician On The Way',
    eyebrow: 'Live arrival update',
    body: 'Keep your phone nearby and keep the Arrival PIN private until arrival.',
    badge: 'warning',
    nextTitle: 'Arrival is next',
    nextBody: 'The PIN unlocks only after the technician marks arrival. Do not share it by phone or chat.',
    primary: 'Call Technician',
    policy: 'Self-service cancellation is closed. Contact support if there is a problem.',
  },
  arrived: {
    label: 'Technician Arrived',
    eyebrow: 'Verify before work starts',
    body: 'Reveal the Arrival PIN only after confirming the technician is physically at your door.',
    badge: 'warning',
    nextTitle: 'Verify arrival',
    nextBody: 'After the technician enters the PIN, the job clock starts and the booking moves to in progress.',
    primary: 'Reveal PIN',
    policy: 'The technician has arrived. Contact support for cancellation or safety issues.',
  },
  in_progress: {
    label: 'Job In Progress',
    eyebrow: 'PIN verified',
    body: 'The PIN was verified and the service is underway.',
    badge: 'warning',
    nextTitle: 'Service underway',
    nextBody: 'Use messages for job details and support if anything changes during the visit.',
    primary: 'Message Technician',
    policy: 'This job is in progress. Support can help with urgent issues.',
  },
  completed: {
    label: 'Service Complete',
    eyebrow: 'Booking completed',
    body: 'Your service is complete. Review the final details and download your receipt.',
    badge: 'success',
    nextTitle: 'Review and receipt',
    nextBody: 'Keep the receipt for your records. Final price can include approved parts or extra work.',
    primary: 'Download Receipt',
    policy: 'Completed bookings cannot be cancelled.',
  },
  cancelled: {
    label: 'Booking Cancelled',
    eyebrow: 'No visit scheduled',
    body: 'This booking has been cancelled.',
    badge: 'danger',
    nextTitle: 'Booking cancelled',
    nextBody: 'No technician will be dispatched for this booking.',
    primary: 'Book Another Service',
    policy: 'This booking is already cancelled.',
  },
  rejected: {
    label: 'Request Declined',
    eyebrow: 'Technician unavailable',
    body: 'The technician could not accept this request.',
    badge: 'danger',
    nextTitle: 'Find another technician',
    nextBody: 'Start a new booking or contact support to choose another available professional.',
    primary: 'Book Another Service',
    policy: 'Declined requests cannot be cancelled.',
  },
  disputed: {
    label: 'Booking Under Review',
    eyebrow: 'Support case active',
    body: 'SERVIO support is reviewing this booking.',
    badge: 'danger',
    nextTitle: 'Support review active',
    nextBody: 'Keep messages and receipt details available while support reviews the case.',
    primary: 'Contact Support',
    policy: 'This booking is under review. Contact support for next steps.',
  },
  awaiting_customer_confirmation: {
    label:   'Awaiting Confirmation',
    badge:   'warning',
    primary: 'Confirm Complete',
    body:    'Your technician has finished. Please confirm the job is complete or report an issue.',
  },
  pending_admin_review: {
    label:   'Under Review',
    badge:   'info',
    primary: null,
    body:    null,
  },
};

let booking = null;
let pollTimer = null;
let lastUpdatedAt = Date.now();
let pinRevealed = false;
let lastFocus = null;
let disputeDeepLinkHandled = false;

const $ = (id) => document.getElementById(id);

function t(key, fallback) {
  return typeof window.t === 'function' ? window.t(key) || fallback : fallback;
}

function setText(id, value) {
  const el = $(id);
  if (el) el.textContent = safeText(value);
}

function safeText(value, fallback = '-') {
  if (value === null || value === undefined || value === '') return fallback;
  if (typeof value === 'string' || typeof value === 'number') return String(value);
  if (Array.isArray(value)) return value.map((item) => safeText(item, '')).filter(Boolean).join(', ') || fallback;
  if (typeof value === 'object') return value.label || value.name || value.title || value.city || value.address || fallback;
  return fallback;
}

function isObjectId(value) {
  return /^[a-f0-9]{24}$/i.test(String(value || ''));
}

function formatEstimatedDuration(bk) {
  const min = Number(bk?.estimatedDurationMin);
  if (Number.isFinite(min) && min > 0) {
    const h = Math.floor(min / 60);
    const m = min % 60;
    const dur = h > 0 ? (m > 0 ? `${h}h ${m}m` : `${h}h`) : `${m}m`;
    if (bk?.estimatedFinishAt) {
      const finish = new Date(bk.estimatedFinishAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
      return `${dur} · finish ~${finish}`;
    }
    return dur;
  }
  return safeText(bk?.duration, 'Estimated 1 hour');
}

function getBookingId(bk = booking) {
  const id = bk?._id || bk?.bookingId || bk?.id;
  return isObjectId(id) ? String(id) : '';
}

function getDisplayId(bk = booking) {
  return safeText(bk?.reference || bk?.bookingRef || bk?._id || bk?.id, '-');
}

function getStatus(bk = booking) {
  const raw = String(bk?.rawStatus || bk?.status || 'pending').toLowerCase().replace(/\s+/g, '_');
  const map = {
    booked: 'pending',
    confirmed: 'accepted',
    complete: 'completed',
    cancelled: 'cancelled',
  };
  return map[raw] || raw;
}

function getWorker(bk = booking) {
  return bk?.worker || bk?.technician || {};
}

function getWorkerName(bk = booking) {
  const worker = getWorker(bk);
  return safeText(worker.name || bk?.workerName || bk?.technicianName, 'Technician');
}

function getWorkerPhone(bk = booking) {
  const worker = getWorker(bk);
  return safeText(worker.phone || bk?.workerPhone, '');
}

function getServiceName(bk = booking) {
  return safeText(bk?.serviceName || bk?.service?.title || bk?.service || bk?.serviceCategory || bk?.category, 'Service');
}

function getCategory(bk = booking) {
  return safeText(bk?.serviceCategory || bk?.service?.category || bk?.category || getServiceName(bk), 'Service');
}

function getAddress(bk = booking) {
  return safeText(bk?.address || bk?.location || bk?.locationLabel, '-');
}

function getDescription(bk = booking) {
  return safeText(bk?.description, 'No customer notes were added.');
}

function getSpecialty(bk = booking) {
  const worker = getWorker(bk);
  const firstService = Array.isArray(worker.services) ? worker.services.map((item) => safeText(item, '')).filter(Boolean)[0] : '';
  const firstSkill = Array.isArray(worker.skills) ? worker.skills.map((item) => safeText(item, '')).filter(Boolean)[0] : '';
  const firstCategory = Array.isArray(worker.categories) ? worker.categories.map((item) => safeText(item, '')).filter(Boolean)[0] : '';
  return firstService || firstSkill || firstCategory || safeText(worker.specialty || getCategory(bk), 'Verified professional');
}

function getWorkerLocation(bk = booking) {
  const worker = getWorker(bk);
  return safeText(worker.locationLabel || worker.serviceArea || worker.location || bk?.workerLocation, '');
}

function getRatingLabel(bk = booking) {
  const worker = getWorker(bk);
  const rating = worker.averageRating ?? worker.rating ?? bk?.workerRating;
  const reviews = worker.totalReviews ?? worker.reviewCount ?? bk?.workerReviewCount;
  if (Number.isFinite(Number(rating))) {
    return reviews ? `${Number(rating).toFixed(1)} · ${reviews} reviews` : `${Number(rating).toFixed(1)} out of 5`;
  }
  return 'New technician';
}

function getInitials(name) {
  return safeText(name, 'T')
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join('')
    .toUpperCase() || 'T';
}

function getLocale() {
  return document.documentElement.lang || localStorage.getItem('servio_lang') || 'en-US';
}

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return safeText(value);
  return date.toLocaleDateString(getLocale(), { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' });
}

function formatInputDate(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) return '';
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

function formatTime(value) {
  if (!value) return '-';
  const raw = String(value);
  const match = raw.match(/^(\d{1,2}):(\d{2})/);
  if (!match) return safeText(value);
  const date = new Date();
  date.setHours(Number(match[1]), Number(match[2]), 0, 0);
  return date.toLocaleTimeString(getLocale(), { hour: 'numeric', minute: '2-digit' });
}

function getMoneyValue(bk = booking) {
  return Number(bk?.totalPrice ?? bk?.rate ?? bk?.service?.basePrice ?? bk?.price ?? 0);
}

function formatMoney(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) return '-';
  return `${amount.toFixed(2)} EGP`;
}

function getPaymentMethod(bk = booking) {
  return paymentMethodLabel(bk?.paymentMethod || bk?.payment || 'online', bk?.paymentMeta);
}

function normalizeBooking(apiBooking) {
  if (!apiBooking) return null;
  return {
    ...(booking || {}),
    ...apiBooking,
    worker: apiBooking.worker || apiBooking.technician || booking?.worker,
    technician: apiBooking.worker || apiBooking.technician || booking?.technician,
    serviceName: apiBooking.serviceName || apiBooking.service?.title || booking?.serviceName,
    serviceCategory: apiBooking.serviceCategory || apiBooking.service?.category || booking?.serviceCategory,
    rate: apiBooking.totalPrice ?? apiBooking.rate ?? booking?.rate,
  };
}

function readCachedBooking(targetId) {
  try {
    const raw = localStorage.getItem('servio_active_booking');
    if (raw) {
      const parsed = JSON.parse(raw);
      if (!targetId || parsed?._id === targetId || parsed?.id === targetId) return parsed;
    }
  } catch (_) {}
  return null;
}

function persistBooking(bk) {
  try { localStorage.setItem('servio_active_booking', JSON.stringify(bk)); } catch (_) {}
}

function showEmptyState() {
  stopPolling();
  const content = $('bkContent');
  const empty = $('bkEmptyState');
  if (content) content.hidden = true;
  if (empty) empty.hidden = false;
  const bar = $('bkMobileBar');
  if (bar) bar.hidden = true;
}

function showContent() {
  const content = $('bkContent');
  const empty = $('bkEmptyState');
  if (content) content.hidden = false;
  if (empty) empty.hidden = true;
  const bar = $('bkMobileBar');
  if (bar) bar.hidden = false;
}

function showLoading() {
  showContent();
  ['bkId', 'bkService', 'bkDate', 'bkTime', 'bkStatusText', 'bkTechnicianName'].forEach((id) => setText(id, '...'));
}

async function loadBooking() {
  const idFromUrl = new URLSearchParams(window.location.search).get('id');
  const cached = readCachedBooking(idFromUrl);
  const candidateId = isObjectId(idFromUrl) ? idFromUrl : getBookingId(cached);

  if (!candidateId && cached) {
    booking = cached;
    renderBooking();
    return;
  }

  if (!candidateId) {
    showEmptyState();
    return;
  }

  showLoading();
  try {
    const apiBooking = await getBooking(candidateId);
    booking = normalizeBooking(apiBooking);
    lastUpdatedAt = Date.now();
    persistBooking(booking);
    renderBooking();
    maybeOpenDisputeFromQuery();
    startPolling();
  } catch (err) {
    if (cached) {
      booking = cached;
      renderBooking();
      showToast('Showing cached booking details. Live refresh is unavailable.', 'info');
      return;
    }
    showEmptyState();
  }
}

function renderEscrowActions(booking) {
  const bar = document.getElementById('bkEscrowActions');
  if (!bar) return;

  const status = booking?.status;
  if (status === 'awaiting_customer_confirmation') {
    bar.hidden = false;

    // Compute actual elapsed time from server timestamps
    const startedAt   = booking.actualStartedAt   ? new Date(booking.actualStartedAt)   : null;
    const completedAt = booking.actualCompletedAt  ? new Date(booking.actualCompletedAt) : null;
    const billedMin   = booking.actualBilledMin    ?? (
      (startedAt && completedAt)
        ? Math.round((completedAt - startedAt) / 60_000)
        : null
    );

    const formatDuration = (min) => {
      if (!Number.isFinite(min) || min < 0) return null;
      const h = Math.floor(min / 60);
      const m = min % 60;
      return h > 0 ? (m > 0 ? `${h}h ${m}m` : `${h}h`) : `${m}m`;
    };

    const durationLabel  = formatDuration(billedMin);
    const isFlagged      = !!booking.flaggedForReview;
    const flagReason     = booking.flagReason || '';

    const durationBanner = durationLabel ? `
      <div class="bk-duration-summary ${isFlagged ? 'bk-duration-summary--flagged' : ''}">
        <div class="bk-duration-summary__row">
          <span class="bk-duration-summary__label">Actual job time</span>
          <span class="bk-duration-summary__value">${durationLabel}</span>
        </div>
        ${isFlagged ? `
        <div class="bk-duration-summary__flag">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
          <span>Duration flagged for admin review${flagReason ? ' — ' + flagReason : ''}. Admin will verify before releasing payment.</span>
        </div>` : ''}
      </div>` : '';

    bar.innerHTML = `
      ${durationBanner}
      <button id="bkConfirmCompleteBtn" class="btn btn--primary">
        ${window.t?.('bkd_confirm_complete') || 'Confirm Service Complete'}
      </button>
      <button id="bkReportIssueBtn" class="btn btn--ghost btn--danger">
        Open Dispute
      </button>
    `;

    document.getElementById('bkConfirmCompleteBtn')?.addEventListener('click', async () => {
      try {
        await confirmCompletion(booking._id || booking.bookingId);
        showToast('Confirmed! Awaiting admin review.', 'success');
        await refreshBooking();
      } catch (err) {
        showToast(err?.data?.message || err?.message || 'Failed to confirm. Please try again.', 'error');
      }
    });

    document.getElementById('bkReportIssueBtn')?.addEventListener('click', () => openDisputeDialog());
  } else if (SUPPORT_ISSUE_STATUSES.has(status)) {
    const completedAt = new Date(booking.updatedAt || booking.customerConfirmedAt || 0).getTime();
    const withinCompletedWindow = status !== 'completed' || (completedAt && Date.now() - completedAt <= 48 * 60 * 60 * 1000);
    if (!withinCompletedWindow) {
      bar.hidden = true;
      return;
    }
    const mode = ['accepted', 'en_route'].includes(status) ? 'prework' : (status === 'completed' ? 'post' : 'during');
    bar.hidden = false;
    bar.innerHTML = `
      <button id="bkSupportIssueBtn" class="btn btn--ghost btn--danger">
        ${mode === 'prework' ? 'Report late / no-show' : 'Report problem'}
      </button>
    `;
    document.getElementById('bkSupportIssueBtn')?.addEventListener('click', () => openSupportIssueDialog(mode));
  } else {
    bar.hidden = true;
  }
}

function renderPaymentNote(booking) {
  const note = document.getElementById('bkPaymentNote');
  if (!note) return;

  const status = booking?.status;
  const payStatus = booking?.paymentStatus;
  const method = String(booking?.paymentMethod || '').toLowerCase();

  if (payStatus === 'failed' || payStatus === 'unpaid') {
    note.textContent = 'Payment not yet processed. Use the retry button below to complete payment.';
    const retryWrap = document.getElementById('bkRetryPayment');
    if (retryWrap) retryWrap.hidden = false;
    return;
  }
  if (status === 'pending_admin_review') {
    note.textContent = method === 'cash'
      ? (window.t?.('bkd_review_cash') || 'Completion under review — commission settlement will be processed after approval.')
      : (window.t?.('bkd_review_online') || "Payment under review — we'll notify you once approved.");
    return;
  }
  if (method === 'cash') {
    note.textContent = 'Pay after arrival when the job details match. Avoid off-platform payment requests.';
  } else if (status === 'pending') {
    note.textContent = 'Card payment selected. No real charge will be made in this preview.';
  } else {
    note.textContent = 'Saved-card details are attached to this booking. Final price may change if approved parts or extra work are required.';
  }
}

function attachRetryHandler(booking) {
  const retryBtn = document.getElementById('bkRetryBtn');
  if (!retryBtn) return;
  retryBtn.addEventListener('click', async () => {
    const total = booking.estimatedTotal || booking.totalPrice;
    openCardPickerModal(total, async (paymentMeta) => {
      try {
        await holdPayment(booking._id || booking.bookingId, { savedCardId: paymentMeta.savedCardId, useCredit: true });
        showToast('Payment held successfully.', 'success');
        await refreshBooking();
      } catch (err) {
        showToast(err?.data?.message || err?.message || 'Payment failed. Try another card.', 'error');
      }
    });
  });
}

function renderBooking() {
  if (!booking) {
    showEmptyState();
    return;
  }

  showContent();
  const status = getStatus();
  const ui = STATUS_UI[status] || STATUS_UI.pending;
  const workerName = getWorkerName();
  const phone = getWorkerPhone();
  const date = formatDate(booking.scheduledDate || booking.date);
  const time = formatTime(booking.scheduledTime || booking.time);
  const totals = snapshotFeeFromBooking(booking);

  setText('bkId', getDisplayId());
  setText('bkService', getServiceName());
  setText('bkDate', date);
  setText('bkTime', time);
  setText('bkStatusEyebrow', ui.eyebrow);
  setText('bkStatusText', ui.label);
  setText('bkHeroBody', ui.body);
  setText('bkNextTitle', ui.nextTitle);
  setText('bkNextBody', ui.nextBody);
  setText('bkLastUpdated', formatLastUpdated());
  setText('bkPolicyText', ui.policy);

  const badge = $('bkStatusBadge');
  if (badge) {
    badge.className = `bk-status-badge bk-status-badge--${ui.badge}`;
    badge.setAttribute('aria-label', `Booking status: ${ui.label}`);
  }

  renderTracker(status);
  renderSummary(date, time, totals.estimatedTotal);
  renderTechnician(workerName, phone);
  renderPin(status);
  renderPayment(totals.base, totals.feeAmount, totals.estimatedTotal, status, totals.feeRate);
  renderActions(status);
  renderTerminalBanner(status, ui);
  renderEscrowActions(booking);
  renderPaymentNote(booking);
  attachRetryHandler(booking);
}

function renderSummary(date, time, total) {

  setText('bkCategory', getCategory());
  setText('bkLocation', getAddress());
  setText('bkScheduledDate', date);
  setText('bkScheduledTime', time);
  setText('bkDuration', formatEstimatedDuration(booking));
  setText('bkDescription', getDescription());
}

function renderTechnician(workerName, phone) {
  const initials = getInitials(workerName);
  const avatar = getWorker().profileImage || booking?.workerAvatar || '';
  const avatarImg = $('bkTechAvatarImg');

  setText('bkTechInitials', initials);
  setText('bkBarInitials', initials);
  setText('bkTechnicianName', workerName);
  setText('bkBarName', workerName);
  setText('bkTechSpecialty', [getSpecialty(), getWorkerLocation()].filter(Boolean).join(' · ') || 'Verified professional');
  setText('bkTechRating', getRatingLabel());

  if (avatarImg) {
    avatarImg.hidden = !avatar;
    if (avatar) {
      avatarImg.src = avatar;
      avatarImg.alt = workerName;
    }
  }

  const callLinks = [$('bkCallLink'), $('bkSupportCall')].filter(Boolean);
  callLinks.forEach((link) => {
    if (phone && link.id === 'bkCallLink') {
      link.href = `tel:${phone}`;
      link.removeAttribute('aria-disabled');
    } else if (link.id === 'bkCallLink') {
      link.removeAttribute('href');
      link.setAttribute('aria-disabled', 'true');
    }
  });
}

function renderTracker(status) {
  const timeline = $('bkTimeline');
  if (!timeline) return;
  const current = TRACKER_STEPS.indexOf(status);
  const terminal = ['cancelled', 'rejected', 'disputed'].includes(status);

  timeline.replaceChildren();
  TRACKER_STEPS.forEach((step, index) => {
    const stepUi = STATUS_UI[step] || {};
    const done = status === 'completed' || (!terminal && current > index);
    const active = !terminal && current === index && status !== 'completed';
    const state = done ? 'done' : active ? 'active' : 'pending';

    const li = document.createElement('li');
    li.className = `bk-timeline__step bk-timeline__step--${state}`;
    li.innerHTML = `
      <div class="bk-timeline__node" aria-label="${state === 'done' ? 'Completed' : active ? 'Current step' : 'Pending'}">
        ${done ? checkIcon() : active ? activeIcon() : pendingIcon()}
      </div>
      <div class="bk-timeline__content">
        <strong class="bk-timeline__label">${stepUi.label || step}</strong>
        <span class="bk-timeline__sub">${stepUi.eyebrow || ''}</span>
      </div>
    `;
    timeline.appendChild(li);
  });
}

function renderPin(status) {
  const pin = String(booking?.pin || '').replace(/\D/g, '').slice(0, 4);
  const card = $('bkPinCard');
  const action = $('bkRevealPinBtn');
  const value = $('bkPinValue');
  const help = $('bkPinHelp');
  const label = $('bkPinState');
  if (!card || !value || !help || !label) return;

  card.classList.remove('is-ready', 'is-open', 'is-verified', 'is-disabled');
  if (action) action.hidden = true;

  if (status === 'arrived') {
    card.classList.add(pinRevealed ? 'is-open' : 'is-ready');
    value.textContent = pinRevealed && pin ? pin.split('').join(' ') : 'PIN ready';
    help.textContent = pinRevealed
      ? 'Share this PIN only after confirming the technician is at your door. Never send it by chat or phone.'
      : 'Reveal the PIN only when the technician is physically with you.';
    label.textContent = pinRevealed ? 'Revealed' : 'Ready';
    if (action) action.hidden = pinRevealed || !pin;
    return;
  }

  if (status === 'in_progress') {
    card.classList.add('is-verified');
    value.textContent = 'PIN verified';
    help.textContent = 'The technician verified the PIN and the job clock has started.';
    label.textContent = 'Verified';
    return;
  }

  if (status === 'completed') {
    card.classList.add('is-verified');
    value.textContent = 'Verification complete';
    help.textContent = 'The service is complete. The arrival PIN is no longer shown.';
    label.textContent = 'Complete';
    return;
  }

  if (['cancelled', 'rejected', 'disputed'].includes(status)) {
    card.classList.add('is-disabled');
    value.textContent = 'PIN unavailable';
    help.textContent = 'Arrival verification is disabled for this booking state.';
    label.textContent = 'Closed';
    return;
  }

  value.textContent = 'PIN locked';
  help.textContent = status === 'pending'
    ? 'The PIN unlocks when your technician arrives. Do not share it by message or phone.'
    : 'Keep this private. The PIN unlocks when the technician marks arrival.';
  label.textContent = 'Locked';
}

function renderPayment(rate, fee, total, status, feeRate = 10) {
  setText('bkPaySummaryMethod', getPaymentMethod());
  setText('bkPayBase', formatFeeMoney(rate));
  setText('bkPayFee', `${formatFeeMoney(fee)} (${feeRate}%)`);
  setText('bkPayAmount', formatFeeMoney(total));
  setText('bkPayStatus', paymentStatusText(status));
  setText('bkPaymentMethodDetail', getPaymentMethod());

  const note = $('bkPaymentNote');
  if (note) {
    if (String(booking?.paymentMethod || booking?.payment || '').toLowerCase().includes('cash')) {
      note.textContent = 'Pay after arrival when the job details match. Avoid off-platform payment requests.';
    } else if (status === 'pending') {
      note.textContent = 'Card payment selected. No real charge will be made in this preview.';
    } else {
      note.textContent = 'Saved-card details are attached to this booking. Final price may change if approved parts or extra work are required.';
    }
  }
}

function paymentStatusText(status) {
  const labels = {
    unpaid:                  'Awaiting payment',
    held:                    'Payment held in escrow',
    released:                'Payment released',
    refunded:                'Refunded',
    failed:                  'Payment failed',
    disputed:                'Disputed',
    cash_pending_settlement: 'Cash — commission pending',
    cash_settled:            'Cash settled',
    not_required:            'No charge',
    demo_pending:            'Awaiting payment',
    cash_pending:            'Cash pending',
    paid:                    'Paid',
    pending:                 'Not charged yet',
    completed:               'Receipt ready',
    cancelled:               'No charge',
    rejected:                'No charge',
  };
  return labels[status] || 'Payment pending';
}

function renderActions(status) {
  const cancelBtn = $('bkCancelBtn');
  const rescheduleBtn = $('bkRescheduleBtn');
  const primary = $('bkMobilePrimary');
  const canCancel = CANCELLABLE_STATUSES.has(status);
  const canReschedule = RESCHEDULABLE_STATUSES.has(status);

  if (cancelBtn) {
    cancelBtn.disabled = !canCancel;
    cancelBtn.setAttribute('aria-disabled', String(!canCancel));
  }
  if (rescheduleBtn) {
    rescheduleBtn.disabled = !canReschedule;
    rescheduleBtn.setAttribute('aria-disabled', String(!canReschedule));
  }

  if (primary) {
    primary.textContent = (STATUS_UI[status] || STATUS_UI.pending).primary;
  }
}

function renderTerminalBanner(status, ui) {
  const wrap = $('bkStateBanner');
  if (!wrap) return;
  const terminal = ['cancelled', 'rejected', 'disputed'].includes(status);
  wrap.hidden = !terminal;
  if (terminal) {
    wrap.className = `bk-state-banner bk-state-banner--${ui.badge}`;
    wrap.textContent = ui.body;
  }
}

function checkIcon() {
  return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>';
}

function activeIcon() {
  return '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle></svg>';
}

function pendingIcon() {
  return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="4"></circle></svg>';
}

function formatLastUpdated() {
  const seconds = Math.max(0, Math.floor((Date.now() - lastUpdatedAt) / 1000));
  if (seconds < 10) return 'Last updated just now';
  if (seconds < 60) return `Last updated ${seconds}s ago`;
  return `Last updated ${Math.floor(seconds / 60)} min ago`;
}

async function refreshBooking() {
  const id = getBookingId();
  if (!id) return;
  try {
    const prevEstMin = Number(booking?.estimatedDurationMin) || null;
    const apiBooking = await getBooking(id);
    booking = normalizeBooking(apiBooking);
    lastUpdatedAt = Date.now();
    persistBooking(booking);
    const newEstMin = Number(booking?.estimatedDurationMin) || null;
    if (prevEstMin && newEstMin && newEstMin !== prevEstMin) {
      const finish = booking?.estimatedFinishAt
        ? new Date(booking.estimatedFinishAt).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
        : null;
      showToast(
        finish
          ? `Technician updated the estimate. New finish time: ~${finish}.`
          : `Technician updated the duration estimate to ${formatEstimatedDuration(booking)}.`,
        'info'
      );
    }
    renderBooking();
    if (FINAL_STATUSES.has(getStatus())) stopPolling();
  } catch (_) {
    stopPolling();
    showToast('Live refresh paused. Reload to try again.', 'info');
  }
}

function startPolling() {
  stopPolling();
  if (!getBookingId() || !ACTIVE_STATUSES.has(getStatus())) return;
  pollTimer = setInterval(refreshBooking, POLL_MS);
}

function stopPolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
}

function openDialog(dialog) {
  if (!dialog) return;
  lastFocus = document.activeElement;
  dialog.hidden = false;
  const first = dialog.querySelector('button, input, select, a[href]');
  first?.focus();
}

function closeDialog(dialog) {
  if (!dialog) return;
  dialog.hidden = true;
  lastFocus?.focus?.();
  lastFocus = null;
}

function setDisputeError(message = '') {
  const error = $('bkDisputeError');
  if (!error) return;
  error.hidden = !message;
  error.textContent = message;
}

function setDisputeBusy(isBusy) {
  const submit = $('bkDisputeSubmit');
  const cancel = $('bkDisputeCancel');
  const form = $('bkDisputeForm');
  if (submit) {
    submit.disabled = isBusy;
    submit.textContent = isBusy ? 'Opening...' : 'Open Dispute';
  }
  if (cancel) cancel.disabled = isBusy;
  form?.querySelectorAll('input, select, textarea').forEach((field) => { field.disabled = isBusy; });
}

function resetDisputeDialog() {
  $('bkDisputeForm')?.reset();
  setDisputeError('');
  const list = $('bkDisputeEvidenceList');
  if (list) {
    list.hidden = true;
    list.replaceChildren();
  }
  setDisputeBusy(false);
}

function openDisputeDialog() {
  if (!booking || !DISPUTABLE_STATUSES.has(getStatus())) {
    showToast('This booking is not eligible for a dispute right now.', 'info');
    return;
  }
  resetDisputeDialog();
  openDialog($('bkDisputeDialog'));
}

function maybeOpenDisputeFromQuery() {
  if (disputeDeepLinkHandled) return;
  const action = new URLSearchParams(window.location.search).get('action');
  if (action !== 'dispute') return;
  disputeDeepLinkHandled = true;
  setTimeout(openDisputeDialog, 80);
}

function updateEvidencePreview() {
  const input = $('bkDisputeEvidence');
  const list = $('bkDisputeEvidenceList');
  if (!input || !list) return;
  const files = [...(input.files || [])].slice(0, 6);
  list.hidden = files.length === 0;
  list.innerHTML = files.map(file => `
    <span class="bk-dispute-evidence__item">
      <span>${file.name}</span>
      <small>${Math.ceil(file.size / 1024)} KB</small>
    </span>
  `).join('');
}

async function submitDispute(event) {
  event.preventDefault();
  const id = getBookingId();
  const category = $('bkDisputeCategory')?.value || 'other';
  const reason = String($('bkDisputeReason')?.value || '').trim();
  const files = [...($('bkDisputeEvidence')?.files || [])].slice(0, 6);

  if (!id) {
    setDisputeError('Booking ID is missing. Refresh the page and try again.');
    return;
  }
  if (reason.length < 20) {
    setDisputeError('Describe the issue in at least 20 characters.');
    return;
  }

  setDisputeBusy(true);
  setDisputeError('');
  try {
    const evidence = [];
    for (const file of files) {
      const uploaded = await uploadPublicFile(file, 'dispute');
      if (uploaded?.url) evidence.push(uploaded.url);
    }
    await openDispute({ bookingId: id, category, reason, evidence });
    closeDialog($('bkDisputeDialog'));
    showToast('Dispute opened. SERVIO support is reviewing it.', 'info');
    await refreshBooking();
  } catch (err) {
    setDisputeError(err?.data?.message || err?.message || 'Failed to open dispute.');
    setDisputeBusy(false);
  }
}

function supportIssueOptions(mode) {
  if (mode === 'prework') {
    return [['late', 'Technician is late'], ['no_show', 'Technician did not show up'], ['other', 'Other scheduling issue']];
  }
  if (mode === 'post') {
    return [['post_completion', 'Problem after completion'], ['other', 'Other completed-service issue']];
  }
  return [['during_work_problem', 'Problem during work'], ['safety', 'Safety concern'], ['other', 'Other work issue']];
}

function openSupportIssueDialog(mode = 'during') {
  if (!booking || !SUPPORT_ISSUE_STATUSES.has(getStatus())) {
    showToast('This booking is not eligible for a support case right now.', 'info');
    return;
  }
  $('bkSupportIssueForm')?.reset();
  const type = $('bkSupportIssueType');
  if (type) {
    type.innerHTML = supportIssueOptions(mode)
      .map(([value, label]) => `<option value="${value}">${label}</option>`)
      .join('');
  }
  const title = $('bkSupportIssueTitle');
  if (title) title.textContent = mode === 'prework' ? 'Report late / no-show' : 'Report a problem';
  const list = $('bkSupportIssueEvidenceList');
  if (list) {
    list.hidden = true;
    list.innerHTML = '';
  }
  const error = $('bkSupportIssueError');
  if (error) {
    error.hidden = true;
    error.textContent = '';
  }
  openDialog($('bkSupportIssueDialog'));
}

function updateSupportIssueEvidencePreview() {
  const input = $('bkSupportIssueEvidence');
  const list = $('bkSupportIssueEvidenceList');
  if (!input || !list) return;
  const files = [...(input.files || [])].slice(0, 6);
  list.hidden = files.length === 0;
  list.innerHTML = files.map(file => `
    <span class="bk-dispute-evidence__item">
      <span>${file.name}</span>
      <small>${Math.ceil(file.size / 1024)} KB</small>
    </span>
  `).join('');
}

async function submitSupportIssue(event) {
  event.preventDefault();
  const id = getBookingId();
  const type = $('bkSupportIssueType')?.value || 'other';
  const description = String($('bkSupportIssueDescription')?.value || '').trim();
  const files = [...($('bkSupportIssueEvidence')?.files || [])].slice(0, 6);
  const error = $('bkSupportIssueError');
  const submit = $('bkSupportIssueSubmit');

  if (description.length < 20) {
    if (error) {
      error.textContent = 'Describe the issue in at least 20 characters.';
      error.hidden = false;
    }
    return;
  }

  if (submit) {
    submit.disabled = true;
    submit.textContent = 'Submitting...';
  }
  try {
    const evidence = [];
    for (const file of files) {
      const uploaded = await uploadPublicFile(file, 'support');
      if (uploaded?.url) evidence.push(uploaded.url);
    }
    await createSupportIssue({ bookingId: id, type, description, evidence });
    closeDialog($('bkSupportIssueDialog'));
    showToast('Support case opened.', 'success');
  } catch (err) {
    if (error) {
      error.textContent = err?.data?.message || err?.message || 'Failed to open support case.';
      error.hidden = false;
    }
  } finally {
    if (submit) {
      submit.disabled = false;
      submit.textContent = 'Submit Case';
    }
  }
}

function setupDialog(dialog, closeIds = []) {
  if (!dialog) return;
  closeIds.forEach((id) => $(id)?.addEventListener('click', () => closeDialog(dialog)));
  dialog.addEventListener('click', (event) => {
    if (event.target === dialog) closeDialog(dialog);
  });
}

function wireEvents() {
  $('bkRevealPinBtn')?.addEventListener('click', () => {
    pinRevealed = true;
    renderPin(getStatus());
  });

  $('bkCopyRefBtn')?.addEventListener('click', async () => {
    const ref = `Booking #${getDisplayId()}`;
    try { await navigator.clipboard.writeText(ref); } catch (_) {}
    showToast('Booking reference copied.', 'success');
  });

  $('bkCancelBtn')?.addEventListener('click', () => {
    if (!CANCELLABLE_STATUSES.has(getStatus())) {
      showToast('Contact support to cancel after technician confirmation.', 'info');
      return;
    }
    setText('bkDialogId', getDisplayId());
    openDialog($('bkCancelDialog'));
  });

  $('bkDialogConfirm')?.addEventListener('click', async () => {
    const id = getBookingId();
    if (!id) return;
    try {
      const reason = $('bkCancelReason')?.value || 'Other';
      await cancelBooking(id, reason);
      booking = { ...booking, status: 'cancelled', cancellationReason: reason };
      persistBooking(booking);
      lastUpdatedAt = Date.now();
      closeDialog($('bkCancelDialog'));
      renderBooking();
      stopPolling();
      showToast('Booking cancelled.', 'success');
    } catch (err) {
      closeDialog($('bkCancelDialog'));
      showToast(err?.message || 'Could not cancel booking. Please try again.', 'error');
    }
  });

  $('bkRescheduleBtn')?.addEventListener('click', () => {
    if (!RESCHEDULABLE_STATUSES.has(getStatus())) {
      showToast('Reschedule is available only before the technician is on the way.', 'info');
      return;
    }
    const input = $('newBookingDate');
    const slot = $('newBookingSlot');
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    if (input) {
      input.min = formatInputDate(new Date());
      input.max = formatInputDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000));
      input.value = formatInputDate(booking?.scheduledDate || tomorrow);
    }
    if (slot) slot.value = normalizeSlotValue(booking?.scheduledTime) || '09:00';
    openDialog($('bkRescheduleDialog'));
  });

  $('bkRsDialogConfirm')?.addEventListener('click', async () => {
    const id = getBookingId();
    const scheduledDate = $('newBookingDate')?.value;
    const scheduledTime = $('newBookingSlot')?.value;
    if (!id || !scheduledDate || !scheduledTime) {
      showToast('Choose a valid date and time.', 'info');
      return;
    }
    try {
      const updated = await rescheduleBooking(id, { scheduledDate, scheduledTime });
      booking = normalizeBooking(updated);
      persistBooking(booking);
      lastUpdatedAt = Date.now();
      closeDialog($('bkRescheduleDialog'));
      renderBooking();
      showToast('Booking rescheduled.', 'success');
    } catch (err) {
      showToast(err?.message || 'Could not reschedule this booking.', 'error');
    }
  });

  $('bkReceiptBtn')?.addEventListener('click', downloadReceipt);

  $('bkMobilePrimary')?.addEventListener('click', () => {
    const status = getStatus();
    if (status === 'arrived') {
      pinRevealed = true;
      renderPin(status);
      document.getElementById('bkPinCard')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } else if (status === 'completed') {
      downloadReceipt();
    } else if (['cancelled', 'rejected'].includes(status)) {
      window.location.href = './services-marketplace.html';
    } else if (status === 'en_route') {
      $('bkCallLink')?.click();
    } else {
      window.location.href = './messages.html';
    }
  });

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    closeDialog($('bkCancelDialog'));
    closeDialog($('bkRescheduleDialog'));
    closeDialog($('bkDisputeDialog'));
    closeDialog($('bkSupportIssueDialog'));
  });

  setupDialog($('bkCancelDialog'), ['bkDialogKeep']);
  setupDialog($('bkRescheduleDialog'), ['bkRsDialogCancel']);
  setupDialog($('bkDisputeDialog'), ['bkDisputeCancel']);
  setupDialog($('bkSupportIssueDialog'), ['bkSupportIssueCancel']);
  $('bkDisputeEvidence')?.addEventListener('change', updateEvidencePreview);
  $('bkDisputeForm')?.addEventListener('submit', submitDispute);
  $('bkSupportIssueEvidence')?.addEventListener('change', updateSupportIssueEvidencePreview);
  $('bkSupportIssueForm')?.addEventListener('submit', submitSupportIssue);
}

function normalizeSlotValue(value) {
  const match = String(value || '').match(/^(\d{1,2}):(\d{2})/);
  if (!match) return '';
  return `${String(Number(match[1])).padStart(2, '0')}:${match[2]}`;
}

function downloadReceipt() {
  if (!booking) return;
  const totals = snapshotFeeFromBooking(booking);
  const lines = [
    'SERVIO Booking Receipt',
    `Booking: ${getDisplayId()}`,
    `Status: ${(STATUS_UI[getStatus()] || STATUS_UI.pending).label}`,
    `Service: ${getServiceName()}`,
    `Technician: ${getWorkerName()}`,
    `Date: ${formatDate(booking.scheduledDate || booking.date)}`,
    `Time: ${formatTime(booking.scheduledTime || booking.time)}`,
    `Address: ${getAddress()}`,
    `Customer notes: ${getDescription()}`,
    '',
    `Payment method: ${getPaymentMethod()}`,
    `Payment status: ${booking.paymentMethod === 'cash' ? 'Cash pending' : 'Card preview - no real charge processed'}`,
    `Base rate: ${formatFeeMoney(totals.base)}`,
    `Platform fee (${totals.feeRate}%): ${formatFeeMoney(totals.feeAmount)}`,
    `Estimated total: ${formatFeeMoney(totals.estimatedTotal)}`,
    '',
    'Final price may change if approved parts or extra work were required.',
  ];
  const blob = new Blob([lines.join('\n')], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `servio-receipt-${getDisplayId().replace(/[^a-z0-9]+/gi, '-')}.txt`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  showToast('Receipt downloaded.', 'success');
}

function showToast(message, type = 'info') {
  const wrap = $('bkToastWrap');
  if (!wrap) return;
  const toast = document.createElement('div');
  toast.className = `bk-toast bk-toast--${type}`;
  toast.textContent = message;
  wrap.appendChild(toast);
  setTimeout(() => {
    toast.classList.add('is-hiding');
    toast.addEventListener('transitionend', () => toast.remove(), { once: true });
  }, 3200);
}

wireEvents();
loadBooking();
setInterval(() => {
  if (booking) setText('bkLastUpdated', formatLastUpdated());
}, 30000);

// â”€â”€ Hero canvas visual effects â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
(function initBookingHeroCanvas() {
  const canvas = document.getElementById('bk-hero-canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  let animationFrameId;
  let mousePos = { x: undefined, y: undefined };
  let frame = 0;

  const initCanvas = () => {
    // Reset or initialize anything if needed when resized
  };

  const animateCanvas = () => {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    frame++;

    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';

    // Wave parameters for elegant flowing ribbons
    const waves = [
      { amplitude: 120, frequency: 0.0012, speed: 0.004, color: isDark ? 'rgba(203, 184, 145, 0.25)' : 'rgba(30, 27, 75, 0.25)', offset: 0 },
      { amplitude: 160, frequency: 0.0008, speed: 0.003, color: isDark ? 'rgba(255, 255, 255, 0.12)' : 'rgba(154, 140, 115, 0.35)', offset: 150 },
      { amplitude: 90, frequency: 0.0015, speed: 0.006, color: isDark ? 'rgba(203, 184, 145, 0.15)' : 'rgba(30, 27, 75, 0.15)', offset: 300 },
      { amplitude: 200, frequency: 0.0006, speed: 0.002, color: isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(154, 140, 115, 0.2)', offset: 450 }
    ];

    const centerY = canvas.height / 2;

    // Draw each wave
    waves.forEach((wave, index) => {
      ctx.beginPath();

      for (let x = 0; x <= canvas.width; x += 10) {
        // Subtle mouse attraction/repulsion
        let mouseInfluence = 0;
        if (mousePos.x !== undefined) {
          const dx = x - mousePos.x;
          // Calculate approximate y for the wave at this x
          const baseWaveY = centerY + Math.sin(x * wave.frequency + frame * wave.speed + wave.offset) * wave.amplitude;
          const dy = baseWaveY - mousePos.y;
          const dist = Math.sqrt(dx * dx + dy * dy);

          if (dist < 400) {
            const force = (400 - dist) / 400;
            // Push away or pull slightly based on index
            mouseInfluence = force * 60 * (index % 2 === 0 ? 1 : -0.8);
          }
        }

        const y = centerY + mouseInfluence + Math.sin(x * wave.frequency + frame * wave.speed + wave.offset) * wave.amplitude;

        if (x === 0) {
          ctx.moveTo(x, y);
        } else {
          // Use quadratic curves for smoother lines
          ctx.lineTo(x, y);
        }
      }

      ctx.strokeStyle = wave.color;
      ctx.lineWidth = isDark ? 1.5 : 2;

      // Add subtle glow
      ctx.shadowBlur = isDark ? 10 : 8;
      ctx.shadowColor = wave.color;

      ctx.stroke();
      ctx.shadowBlur = 0; // Reset
    });

    animationFrameId = requestAnimationFrame(animateCanvas);
  };

  const resizeCanvas = () => {
    const rect = canvas.parentElement.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    initCanvas();
  };

  const handleCanvasMouseMove = (e) => {
    const rect = canvas.getBoundingClientRect();
    mousePos = { x: e.clientX - rect.left, y: e.clientY - rect.top };
  };

  const handleCanvasMouseOut = () => {
    mousePos = { x: undefined, y: undefined };
  }

  window.addEventListener('resize', resizeCanvas);
  canvas.parentElement.addEventListener('mousemove', handleCanvasMouseMove);
  canvas.parentElement.addEventListener('mouseleave', handleCanvasMouseOut);

  resizeCanvas();
  animateCanvas();
})();
