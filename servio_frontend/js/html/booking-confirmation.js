import { showToast } from '../components/toast.js';
import { cancelBooking, getBooking } from '../api/bookings.js';
import { snapshotFeeFromBooking, formatMoney, paymentMethodLabel } from '../utils/fee.js';

const POLL_MS = 45000;
const FINAL_STATUSES = new Set(['completed', 'cancelled', 'rejected', 'disputed']);
const TRACKER_STEPS = ['pending', 'accepted', 'en_route', 'arrived', 'in_progress', 'completed'];

let currentBooking = readStoredBooking();
let pinRevealed = false;
let pollTimer = null;
let lastUpdatedAt = Date.now();

const statusCopy = {
  pending: {
    tone: 'warning',
    title: 'Request Sent',
    eyebrow: 'Awaiting technician confirmation',
    status: 'Awaiting Technician Confirmation',
    hero: tech => `Your request has been sent${tech ? ` to ${tech}` : ''}. We will notify you as soon as it is accepted.`,
    nextTitle: 'Waiting for technician confirmation',
    nextBody: 'The technician has 30 minutes to accept. If they do not, SERVIO can help you find another available professional.',
    techBadge: 'Awaiting Confirmation',
    cancelPolicy: 'Free cancellation while the request is awaiting confirmation.',
  },
  accepted: {
    tone: 'success',
    title: 'Booking Confirmed',
    eyebrow: 'Technician confirmed',
    status: 'Technician Confirmed',
    hero: tech => `${tech || 'Your technician'} confirmed the booking. We will keep this page updated until arrival.`,
    nextTitle: 'Your technician is preparing',
    nextBody: 'You will receive updates when the technician starts heading to your address.',
    techBadge: 'Confirmed',
    cancelPolicy: 'This booking is confirmed. Contact support if you need to cancel.',
  },
  en_route: {
    tone: 'warning',
    title: 'Technician On The Way',
    eyebrow: 'Live service update',
    status: 'Technician En Route',
    hero: tech => `${tech || 'Your technician'} is on the way. Keep your phone nearby for arrival updates.`,
    nextTitle: 'Technician is heading to you',
    nextBody: 'Keep the Arrival PIN private. It unlocks on arrival and starts the job clock after verification.',
    techBadge: 'En Route',
    cancelPolicy: 'Cancellation is no longer self-service. Contact support if there is a problem.',
  },
  arrived: {
    tone: 'warning',
    title: 'Technician Arrived',
    eyebrow: 'Verify before work starts',
    status: 'Technician Arrived',
    hero: tech => `${tech || 'Your technician'} has arrived. Reveal the PIN only after confirming they are at your door.`,
    nextTitle: 'Verify the technician',
    nextBody: 'Reveal the Arrival PIN only after the technician is physically present. Do not share it by chat or phone.',
    techBadge: 'Arrived',
    cancelPolicy: 'The technician has arrived. Contact support for cancellation or safety issues.',
  },
  in_progress: {
    tone: 'warning',
    title: 'Job In Progress',
    eyebrow: 'PIN verified',
    status: 'Job In Progress',
    hero: () => 'Your Arrival PIN was verified and the job clock has started.',
    nextTitle: 'Service is underway',
    nextBody: 'You can message the technician or contact support if anything changes during the service.',
    techBadge: 'Working',
    cancelPolicy: 'This job is in progress. Contact support if you need assistance.',
  },
  completed: {
    tone: 'success',
    title: 'Service Complete',
    eyebrow: 'Booking completed',
    status: 'Service Complete',
    hero: () => 'Your service has been marked complete. You can review the details and receipt.',
    nextTitle: 'Review your service',
    nextBody: 'Check the final details and leave a review to help other customers choose trusted professionals.',
    techBadge: 'Completed',
    cancelPolicy: 'Completed bookings cannot be cancelled.',
  },
  cancelled: {
    tone: 'danger',
    title: 'Booking Cancelled',
    eyebrow: 'No technician visit scheduled',
    status: 'Cancelled',
    hero: () => 'This booking has been cancelled. You can book another service from your dashboard.',
    nextTitle: 'Booking cancelled',
    nextBody: 'No technician will be dispatched for this booking.',
    techBadge: 'Cancelled',
    cancelPolicy: 'This booking is already cancelled.',
  },
  rejected: {
    tone: 'danger',
    title: 'Request Declined',
    eyebrow: 'Technician unavailable',
    status: 'Request Declined',
    hero: () => 'The technician could not accept this request. SERVIO can help you book another available professional.',
    nextTitle: 'Choose another technician',
    nextBody: 'Your slot is no longer reserved with this technician. Start a new booking or contact support for help.',
    techBadge: 'Declined',
    cancelPolicy: 'This request was declined and cannot be cancelled.',
  },
  disputed: {
    tone: 'danger',
    title: 'Booking Under Review',
    eyebrow: 'Support case active',
    status: 'Disputed',
    hero: () => 'This booking is under review by SERVIO support.',
    nextTitle: 'Support is reviewing this booking',
    nextBody: 'Keep messages and receipts available while the support team reviews the case.',
    techBadge: 'Under Review',
    cancelPolicy: 'This booking is under review. Contact support for next steps.',
  },
};

function t(key, fallback) {
  return typeof window.t === 'function' ? window.t(key) || fallback : fallback;
}

function $(id) {
  return document.getElementById(id);
}

function setText(id, text) {
  const el = $(id);
  if (el) el.textContent = safeText(text);
}

function safeText(value, fallback = '-') {
  if (value === null || value === undefined || value === '') return fallback;
  if (typeof value === 'string' || typeof value === 'number') return String(value);
  if (Array.isArray(value)) return value.map(v => safeText(v, '')).filter(Boolean).join(', ') || fallback;
  if (typeof value === 'object') {
    return value.label || value.name || value.title || value.city || value.address || value.locationLabel || fallback;
  }
  return fallback;
}

function readStoredBooking() {
  try {
    return JSON.parse(localStorage.getItem('servio_active_booking') || 'null');
  } catch {
    return null;
  }
}

function getApiId(booking) {
  const id = booking?._id || booking?.id;
  return /^[a-f0-9]{24}$/i.test(String(id || '')) ? String(id) : '';
}

function getStatus(booking) {
  return booking?.status || 'pending';
}

function getWorker(booking) {
  return booking?.worker || booking?.technician || {};
}

function getTechName(booking) {
  const worker = getWorker(booking);
  return safeText(worker.name || booking?.workerName || booking?.technicianName, 'Technician');
}

function getServiceName(booking) {
  return safeText(booking?.serviceName || booking?.service?.title || booking?.service || booking?.serviceType || booking?.serviceCategory || booking?.category, 'Service');
}

function getAddress(booking) {
  return safeText(booking?.address || booking?.location || booking?.locationLabel, '-');
}

function formatDate(value) {
  if (!value) return '-';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return safeText(value);
  return d.toLocaleDateString(document.documentElement.lang || 'en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function formatTime(value) {
  if (!value) return '-';
  const match = String(value).match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return safeText(value);
  const d = new Date();
  d.setHours(Number(match[1]), Number(match[2]), 0, 0);
  return d.toLocaleTimeString(document.documentElement.lang || 'en-US', { hour: 'numeric', minute: '2-digit' });
}

function getRate(booking) {
  return Number(booking?.rate ?? booking?.totalPrice ?? booking?.service?.basePrice ?? booking?.price ?? 0);
}

function getPaymentMethod(booking) {
  return paymentMethodLabel(booking?.paymentMethod || booking?.payment || 'online', booking?.paymentMeta);
}

function paymentStatusLabel(paymentStatus, paymentMethod) {
  if (paymentMethod === 'cash') {
    if (paymentStatus === 'cash_settled') return 'Commission settled';
    return 'Cash — commission pending';
  }
  const map = {
    unpaid:   'Awaiting payment',
    held:     'Payment held',
    released: 'Released',
    refunded: 'Refunded',
    failed:   'Payment failed — retry needed',
    disputed: 'Disputed',
    // Legacy values — keep working
    demo_pending: 'Awaiting payment',
    paid:         'Paid',
    cash_pending: 'Cash pending',
    not_required: 'No charge',
  };
  return map[paymentStatus] || 'Pending';
}

function paymentStatusText(status) {
  if (status === 'pending') return 'Not charged yet';
  if (['cancelled', 'rejected'].includes(status)) return 'No charge';
  if (status === 'completed') return 'Receipt ready';
  if (status === 'held') return 'Payment held';
  if (status === 'released') return 'Payment released';
  if (status === 'failed') return 'Payment failed';
  return 'Payment pending';
}

function getSpecialty(booking) {
  const worker = getWorker(booking);
  const services = Array.isArray(worker.services) ? worker.services.map(s => safeText(s, '')).filter(Boolean) : [];
  const category = safeText(booking?.serviceCategory || booking?.category || worker.specialty || worker.skills?.[0], '');
  return services[0] || category || 'Verified professional';
}

function getWorkerLocation(booking) {
  const worker = getWorker(booking);
  return safeText(booking?.workerLocation || worker.locationLabel || worker.serviceArea || worker.location, '');
}

function getRating(booking) {
  const worker = getWorker(booking);
  const rating = worker.averageRating ?? worker.rating ?? booking?.workerRating ?? '-';
  const reviews = worker.totalReviews ?? booking?.workerReviewCount;
  return reviews ? `${safeText(rating)} · ${reviews} reviews` : safeText(rating, 'New technician');
}

function normalizeApiBooking(apiBooking) {
  if (!apiBooking) return currentBooking;
  return {
    ...(currentBooking || {}),
    ...apiBooking,
    technician: apiBooking.worker || apiBooking.technician || currentBooking?.technician,
    workerName: apiBooking.worker?.name || currentBooking?.workerName,
    workerAvatar: apiBooking.worker?.profileImage || currentBooking?.workerAvatar,
    workerReviewCount: apiBooking.worker?.totalReviews || currentBooking?.workerReviewCount,
    rate: apiBooking.totalPrice ?? currentBooking?.rate,
    totalPrice: apiBooking.totalPrice ?? currentBooking?.totalPrice,
    platformFeeRate: apiBooking.platformFeeRate ?? currentBooking?.platformFeeRate,
    platformFeeAmount: apiBooking.platformFeeAmount ?? currentBooking?.platformFeeAmount,
    estimatedTotal: apiBooking.estimatedTotal ?? currentBooking?.estimatedTotal,
    paymentMethod: apiBooking.paymentMethod ?? currentBooking?.paymentMethod,
    paymentStatus: apiBooking.paymentStatus ?? currentBooking?.paymentStatus,
    paymentMeta: apiBooking.paymentMeta ?? currentBooking?.paymentMeta,
    serviceName: apiBooking.serviceName || apiBooking.service?.title || currentBooking?.serviceName,
  };
}

function stepIndex(status) {
  if (status === 'cancelled' || status === 'rejected' || status === 'disputed') return 0;
  return Math.max(0, TRACKER_STEPS.indexOf(status));
}

function renderTracker(status) {
  const current = stepIndex(status);
  const steps = [...document.querySelectorAll('.tracker-step')];
  const connectors = [...document.querySelectorAll('.tracker-connector')];
  steps.forEach((step, index) => {
    step.classList.toggle('is-done', index < current || status === 'completed');
    step.classList.toggle('is-current', index === current && status !== 'completed' && !['cancelled', 'rejected', 'disputed'].includes(status));
    const circle = step.querySelector('.tracker-step__circle');
    if (circle && step.classList.contains('is-done')) {
      circle.innerHTML = '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    } else if (circle) {
      circle.textContent = String(index + 1);
    }
  });
  connectors.forEach((connector, index) => {
    connector.classList.toggle('is-done', index < current || status === 'completed');
  });
}

function renderTone(tone) {
  const orb = $('successIcon');
  const pill = $('trackerCurrentPill');
  orb?.classList.toggle('is-warning', tone === 'warning');
  orb?.classList.toggle('is-danger', tone === 'danger');
  pill?.classList.toggle('is-success', tone === 'success');
  pill?.classList.toggle('is-danger', tone === 'danger');
}

function renderDeadline(booking, status) {
  if (status !== 'pending') {
    setText('responseDeadline', status === 'accepted' ? 'Confirmed' : 'Status updated');
    return;
  }

  const created = new Date(booking?.createdAt || Date.now());
  const deadline = new Date(created.getTime() + 30 * 60 * 1000);
  const expired = Date.now() > deadline.getTime();
  const timeText = deadline.toLocaleTimeString(document.documentElement.lang || 'en-US', { hour: 'numeric', minute: '2-digit' });
  setText('responseDeadline', expired ? 'Confirmation window passed - we can help find another technician' : `Expected confirmation by ${timeText}`);
}

function renderNextSteps(booking, status, techName) {
  const expired = status === 'pending' && Date.now() > new Date(booking?.createdAt || Date.now()).getTime() + 30 * 60 * 1000;
  const items = expired
    ? [
        ['Choose a fallback', 'Open support or book another available technician.'],
        ['No real charge', 'Saved-card details are attached to this request for preview only.'],
        ['Keep reference', 'Use your booking reference when contacting support.'],
      ]
    : [
        ['Status updates', 'This page refreshes while your booking is active.'],
        ['Secure PIN', 'The Arrival PIN unlocks only when the technician arrives.'],
        ['Support ready', 'Call or chat with SERVIO if anything feels wrong.'],
      ];
  const list = $('nextStepsList');
  if (!list) return;
  list.replaceChildren();
  items.forEach(([title, body]) => {
    const item = document.createElement('div');
    item.className = 'conf-next-item';
    const strong = document.createElement('strong');
    strong.textContent = title;
    const span = document.createElement('span');
    span.textContent = body.replace('technician', techName || 'technician');
    item.append(strong, span);
    list.appendChild(item);
  });
}

function renderPin(booking, status) {
  const pinEl = $('confirmationPin');
  const helpEl = $('pinHelpText');
  const visual = $('pinVisual');
  const label = $('pinStateLabel');
  const revealBtn = $('revealPinBtn');
  const pin = booking?.pin ? String(booking.pin).replace(/\D/g, '').slice(0, 4) : '';

  visual?.classList.remove('is-revealed');
  label?.classList.remove('is-open');
  if (revealBtn) revealBtn.hidden = true;

  if (status === 'arrived') {
    if (pinRevealed && pin) {
      setText('confirmationPin', pin.split('').join(' '));
      setText('pinHelpText', 'Share this PIN only after confirming the technician is at your door. Never send it by chat or phone.');
      setText('pinStateLabel', 'Revealed');
      visual?.classList.add('is-revealed');
      label?.classList.add('is-open');
    } else {
      setText('confirmationPin', 'PIN ready');
      setText('pinHelpText', 'Reveal the PIN only when the technician is physically with you.');
      setText('pinStateLabel', 'Ready');
      if (revealBtn) revealBtn.hidden = !pin;
    }
    return;
  }

  if (status === 'in_progress') {
    setText('confirmationPin', 'PIN verified');
    setText('pinHelpText', 'The technician verified the PIN and the job clock has started.');
    setText('pinStateLabel', 'Verified');
    label?.classList.add('is-open');
    return;
  }

  if (status === 'completed') {
    setText('confirmationPin', 'Verification complete');
    setText('pinHelpText', 'This service has been completed. The arrival PIN is no longer shown.');
    setText('pinStateLabel', 'Complete');
    label?.classList.add('is-open');
    return;
  }

  if (status === 'accepted' || status === 'en_route') {
    setText('confirmationPin', 'PIN locked');
    setText('pinHelpText', 'Keep this private. The PIN unlocks when your technician marks arrival.');
    setText('pinStateLabel', 'Locked');
    return;
  }

  setText('confirmationPin', 'PIN locked');
  setText('pinHelpText', 'The PIN will unlock when your technician arrives. Do not share it by message or phone.');
  setText('pinStateLabel', 'Locked');
}

function renderPayment(booking, status) {
  const totals = snapshotFeeFromBooking(booking);
  setText('conf-payment-method-value', getPaymentMethod(booking));
  setText('conf-base-rate-value', formatMoney(totals.base));
  setText('conf-platform-fee-value', `${formatMoney(totals.feeAmount)} (${totals.feeRate}%)`);
  setText('conf-total-value', formatMoney(totals.estimatedTotal));
  setText('summaryTotal', formatMoney(totals.estimatedTotal));

  const method = String(booking?.payment || booking?.paymentMethod || '').toLowerCase();
  let note = 'Final price may change if parts, materials, or extra work are required.';
  if (method.includes('cash')) {
    note = 'You will pay the technician after arrival. Do not pay outside SERVIO unless the job details match.';
  } else if (status === 'pending') {
    note = 'Card payment selected. No real charge will be made in this preview.';
  } else {
    note = 'Saved-card details are attached to this booking. No real payment was processed.';
  }
  setText('confirmationPaymentDetails', note);
}

function renderBooking(booking) {
  if (!booking) {
    setText('confTitle', 'No Active Booking Found');
    setText('conf-hero-sub', 'We could not find a booking to display right now.');
    return;
  }

  const status = getStatus(booking);
  const copy = statusCopy[status] || statusCopy.pending;
  const techName = getTechName(booking);
  const service = getServiceName(booking);
  const date = formatDate(booking.scheduledDate || booking.date);
  const time = formatTime(booking.scheduledTime || booking.time);
  const address = getAddress(booking);
  const totals = snapshotFeeFromBooking(booking);

  renderTone(copy.tone);
  renderTracker(status);

  setText('confStatusEyebrow', copy.eyebrow);
  setText('confTitle', copy.title);
  setText('conf-hero-sub', copy.hero(techName));
  setText('confTrackerStatus', copy.status);
  setText('nextTitle', copy.nextTitle);
  setText('nextBody', copy.nextBody);
  setText('confTechStatus', copy.techBadge);
  setText('cancelPolicyText', copy.cancelPolicy);

  document.querySelectorAll('[data-booking-ref]').forEach(el => {
    el.textContent = `Booking #${booking.id || booking._id || '-'}`;
  });

  setText('summaryService', service);
  setText('summarySchedule', `${date}${time !== '-' ? ` · ${time}` : ''}`);
  setText('summaryTechnician', techName);
  setText('summaryAddress', address);
  setText('summaryTotal', formatMoney(totals.estimatedTotal));

  setText('conf-tech-name', techName);
  setText('conf-tech-role', [getSpecialty(booking), getWorkerLocation(booking)].filter(Boolean).join(' · ') || 'Verified professional');
  setText('conf-tech-rating', getRating(booking));

  const avatar = $('conf-tech-avatar');
  const avatarSrc = booking.workerAvatar || booking.workerPhoto || getWorker(booking).profileImage;
  if (avatar) {
    avatar.src = avatarSrc || '../assets/images/avatar-placeholder.svg';
    avatar.alt = techName;
  }

  setText('conf-service-value', service);
  setText('conf-date-value', date);
  setText('conf-time-value', time);
  setText('conf-address-value', address);

  const badge = $('confTechStatus');
  badge?.classList.toggle('status-badge--success', ['accepted', 'en_route', 'arrived', 'in_progress', 'completed'].includes(status));
  badge?.classList.toggle('status-badge--danger', ['cancelled', 'rejected', 'disputed'].includes(status));

  renderDeadline(booking, status);
  renderNextSteps(booking, status, techName);
  renderPin(booking, status);
  renderPayment(booking, status);
  renderActions(booking, status, techName);
  renderLastUpdated();
}

function renderActions(booking, status, techName) {
  setText('conf-msg-tech-name', techName ? `Message ${techName}` : 'Message Technician');

  const viewDetailsBtn = $('viewDetailsBtn');
  const id = getApiId(booking);
  if (viewDetailsBtn && id) viewDetailsBtn.href = `./booking-details.html?id=${id}`;
  const findAnotherBtn = $('findAnotherBtn');
  const expired = status === 'pending' && Date.now() > new Date(booking?.createdAt || Date.now()).getTime() + 30 * 60 * 1000;
  if (findAnotherBtn) findAnotherBtn.hidden = !expired;

  const cancelBtn = $('cancelBtn');
  if (!cancelBtn) return;
  const canCancel = status === 'pending';
  cancelBtn.disabled = !canCancel;
  cancelBtn.title = canCancel ? '' : 'Contact support to cancel after confirmation.';
}

function renderLastUpdated() {
  const seconds = Math.max(0, Math.floor((Date.now() - lastUpdatedAt) / 1000));
  const text = seconds < 10 ? 'Last updated just now' : seconds < 60 ? `Last updated ${seconds}s ago` : `Last updated ${Math.floor(seconds / 60)} min ago`;
  setText('confLastUpdated', text);
}

async function refreshBooking() {
  const id = getApiId(currentBooking);
  if (!id) return;
  try {
    const apiBooking = await getBooking(id);
    currentBooking = normalizeApiBooking(apiBooking);
    localStorage.setItem('servio_active_booking', JSON.stringify(currentBooking));
    lastUpdatedAt = Date.now();
    renderBooking(currentBooking);
    if (FINAL_STATUSES.has(getStatus(currentBooking))) stopPolling();
  } catch {
    stopPolling();
  }
}

function startPolling() {
  const id = getApiId(currentBooking);
  if (!id || FINAL_STATUSES.has(getStatus(currentBooking))) return;
  stopPolling();
  pollTimer = setInterval(refreshBooking, POLL_MS);
}

function stopPolling() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
}

function wireEvents() {
  $('viewHistoryBtn')?.addEventListener('click', () => {
    localStorage.setItem('servio_activeTab_customer', 'history');
    window.location.href = './customer-dashboard.html';
  });

  $('revealPinBtn')?.addEventListener('click', () => {
    pinRevealed = true;
    renderPin(currentBooking, getStatus(currentBooking));
  });

  const refBtn = $('refCopyBtn');
  refBtn?.addEventListener('click', async () => {
    const refText = `#${currentBooking?.id || currentBooking?._id || '-'}`;
    try { await navigator.clipboard.writeText(refText); } catch { /* clipboard may be unavailable */ }
    refBtn.classList.add('is-copied');
    setTimeout(() => refBtn.classList.remove('is-copied'), 1800);
  });

  $('cancelBtn')?.addEventListener('click', async () => {
    if (getStatus(currentBooking) !== 'pending') {
      showToast('Contact support to cancel after technician confirmation.', 'info');
      return;
    }

    const msg = t('conf_cancel_confirm', 'Cancel this pending request? You can submit a new booking anytime.');
    if (!confirm(msg)) return;

    const id = getApiId(currentBooking);
    try {
      if (id) await cancelBooking(id);
      currentBooking = { ...(currentBooking || {}), status: 'cancelled' };
      localStorage.setItem('servio_active_booking', JSON.stringify(currentBooking));
      lastUpdatedAt = Date.now();
      renderBooking(currentBooking);
      showToast('Booking cancelled.', 'success');
      stopPolling();
    } catch {
      showToast('Could not cancel booking. Please try again.', 'error');
    }
  });
}

function runIntroAnimation() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  document.querySelectorAll('.confirmation-hero__inner > *, [data-reveal]').forEach((el, index) => {
    el.style.animationDelay = `${Math.min(index * 45, 360)}ms`;
    el.classList.add('conf-intro-in');
  });
}

window.addEventListener('DOMContentLoaded', () => {
  wireEvents();
  renderBooking(currentBooking);
  refreshBooking();
  startPolling();
  runIntroAnimation();
  setInterval(renderLastUpdated, 15000);
  window.addEventListener('langchange', () => renderBooking(currentBooking));
});
