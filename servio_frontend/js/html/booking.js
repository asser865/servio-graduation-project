(function() {
  let session = null;
  try { session = JSON.parse(localStorage.getItem('servio_session') || 'null'); } catch (_) { session = null; }
  if (!session) {
    const currentPath = window.location.pathname;
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
    const redirectUrl = encodeURIComponent('./' + currentPage + window.location.search);
    window.location.href = './login.html?redirect=' + redirectUrl;
    throw new Error('Unauthenticated — redirecting to login');
  }
  if (session.role === 'admin') {
    window.location.href = './admin-dashboard.html';
    throw new Error('Role redirect — admin');
  } else if (session.role === 'technician') {
    window.location.href = './technician-dashboard.html';
    throw new Error('Role redirect — technician');
  }
})();

import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { getWorker, getMe }  from '../api/users.js';
import { getServices }       from '../api/services.js';
import { createBooking, getWorkerBookedSlots } from '../api/bookings.js';

// ─── URL params ───────────────────────────────────────────────────────────────

const params     = new URLSearchParams(window.location.search);
const workerId   = params.get('worker') || '';
const serviceIdParam = params.get('service') || '';

// ─── State ────────────────────────────────────────────────────────────────────

const state = {
  currentStep: 1,
  totalSteps: 3,
  worker: null,
  selectedTime: null,
  selectedPayment: 'online',
  data: {
    serviceId: '',
    serviceType: '',
    date: '',
    time: '',
    address: '',
    notes: '',
    payment: 'online',
  },
};

// ─── DOM refs ─────────────────────────────────────────────────────────────────

const panels      = document.querySelectorAll('.step-panel');
const stepItems   = document.querySelectorAll('.step-item');
const paymentOpts = document.querySelectorAll('.payment-option');

const step1Next   = document.getElementById('step1Next');
const serviceType = document.getElementById('serviceType');
const bookDate    = document.getElementById('bookDate');
const bookAddress = document.getElementById('bookAddress');

const step2Back   = document.getElementById('step2Back');
const step2Next   = document.getElementById('step2Next');
const step3Back   = document.getElementById('step3Back');
const confirmBtn  = document.getElementById('confirmBtn');
const termsCheck  = document.getElementById('termsCheck');

const reviewTechName = document.getElementById('reviewTechName');
const reviewService  = document.getElementById('reviewService');
const reviewDate     = document.getElementById('reviewDate');
const reviewTime     = document.getElementById('reviewTime');
const reviewAddress  = document.getElementById('reviewAddress');
const reviewPayment  = document.getElementById('reviewPayment');
const reviewBaseRate = document.getElementById('reviewBaseRate');
const reviewFee      = document.getElementById('reviewFee');
const reviewTotal    = document.getElementById('reviewTotal');

const otherProblemRow = document.getElementById('otherProblemRow');
const otherProblem    = document.getElementById('otherProblem');

// ─── "Other" service toggle ────────────────────────────────────────────────────

if (serviceType && otherProblemRow && otherProblem) {
  serviceType.addEventListener('change', () => {
    const isOther = serviceType.value === 'other';
    otherProblemRow.style.display = isOther ? '' : 'none';
    otherProblem.required = isOther;
    if (!isOther) otherProblem.value = '';
  });
}

// ─── Date input: set min + trigger slot render ────────────────────────────────

(function setMinDate() {
  if (!bookDate) return;
  const d = new Date();
  bookDate.min = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
})();

bookDate?.addEventListener('change', () => {
  if (bookDate.value) {
    renderTimeSlotsForDate(bookDate.value, state.worker?.availability || []);
  }
});

// ─── Time slot selection (event delegation) ───────────────────────────────────

document.addEventListener('click', (e) => {
  const pill = e.target.closest('.timeslot-pill');
  if (!pill || pill.disabled || pill.classList.contains('is-unavailable')) return;

  document.querySelectorAll('.timeslot-pill').forEach((p) => p.classList.remove('is-selected'));
  pill.classList.add('is-selected');

  state.selectedTime = pill.dataset.time;
  state.data.time = pill.textContent.trim();

  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animate(pill,
      { scale: [0.94, 1.05, 1], boxShadow: ['0 0 0 rgba(0,0,0,0)', '0 8px 20px rgba(154,140,115,0.3)', '0 4px 15px rgba(154,140,115,0.3)'] },
      { duration: 0.3 }
    );
  }
});

// ─── Payment option selection ─────────────────────────────────────────────────

paymentOpts.forEach((opt) => {
  opt.addEventListener('click', () => {
    paymentOpts.forEach((o) => o.classList.remove('is-selected'));
    opt.classList.add('is-selected');
    const val = opt.dataset.payment;
    state.selectedPayment = val;
    state.data.payment = val;
    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      animate(opt, { scale: [0.97, 1.02, 1] }, { duration: 0.22 });
    }
  });
});

// ─── Edit buttons in review step ─────────────────────────────────────────────

document.querySelectorAll('.review-block__edit').forEach((btn) => {
  btn.addEventListener('click', () => goToStep(parseInt(btn.dataset.goto, 10)));
});

// ─── Step navigation ──────────────────────────────────────────────────────────

step1Next?.addEventListener('click', () => {
  if (!validateStep1()) return;
  collectStep1();
  goToStep(2);
});

step2Back?.addEventListener('click', () => goToStep(1));

step2Next?.addEventListener('click', () => {
  collectStep2();
  populateReview();
  goToStep(3);
});

step3Back?.addEventListener('click', () => goToStep(2));

// ─── Confirm button ───────────────────────────────────────────────────────────

confirmBtn?.addEventListener('click', (e) => {
  e.preventDefault();
  if (!termsCheck || !termsCheck.checked) {
    animate(termsCheck?.closest('.terms-check') || confirmBtn,
      { x: [0, -6, 6, -4, 4, 0] }, { duration: 0.4 }
    );
    return;
  }
  collectStep1();
  collectStep2();

  if (state.data.payment === 'online') {
    openPaymentModal();
  } else {
    animate(confirmBtn, { scale: [1, 0.95, 1.02, 1] }, { duration: 0.3 });
    setTimeout(() => finalizeBooking(), 320);
  }
});

// ─── Validation ──────────────────────────────────────────────────────────────

function validateStep1() {
  const errors = [];

  if (!serviceType?.value) errors.push(serviceType);
  if (serviceType?.value === 'other' && !otherProblem?.value.trim()) errors.push(otherProblem);
  if (!bookDate?.value) errors.push(bookDate);
  if (!bookAddress?.value.trim()) errors.push(bookAddress);
  if (!state.selectedTime) {
    const grid = document.querySelector('.timeslot-grid');
    if (grid) animate(grid, { x: [0, -5, 5, -3, 3, 0] }, { duration: 0.35 });
    errors.push(null);
  }

  errors.forEach((el) => {
    if (!el) return;
    el.style.borderColor = '#e74c3c';
    el.focus();
    animate(el, { x: [0, -5, 5, -3, 3, 0] }, { duration: 0.35 });
    el.addEventListener('input', () => { el.style.borderColor = ''; }, { once: true });
  });

  return errors.length === 0;
}

// ─── Data collection ──────────────────────────────────────────────────────────

function collectStep1() {
  const opt = serviceType?.options[serviceType.selectedIndex];
  state.data.serviceId   = opt?.value === 'other' ? '' : (opt?.value || '');
  state.data.serviceType = serviceType?.value === 'other' && otherProblem?.value.trim()
    ? `Other: ${otherProblem.value.trim()}`
    : (opt?.text || '');
  state.data.date    = bookDate?.value || '';
  state.data.address = bookAddress?.value.trim() || '';
  state.data.time    = state.data.time || '';
}

function collectStep2() {
  const selected = document.querySelector('.payment-option.is-selected input[type="radio"]');
  state.data.payment = selected?.value || 'online';
}

// ─── Populate review step ─────────────────────────────────────────────────────

const PAYMENT_LABELS = { online: 'Online Payment', cash: 'Cash on Arrival' };

function populateReview() {
  if (reviewTechName) reviewTechName.textContent = state.worker?.name || '—';
  if (reviewService)  reviewService.textContent  = state.data.serviceType || '—';
  if (reviewDate)     reviewDate.textContent      = formatDate(state.data.date);
  if (reviewTime)     reviewTime.textContent      = state.data.time || '—';
  if (reviewAddress)  reviewAddress.textContent   = state.data.address || '—';
  if (reviewPayment)  reviewPayment.textContent   = PAYMENT_LABELS[state.data.payment] || state.data.payment;

  const rate = state.worker?.hourlyRate || 0;
  const fee  = rate * 0.10;
  const total = rate + fee;

  if (reviewBaseRate) reviewBaseRate.textContent = `${rate.toFixed(2)} EGP / hr`;
  if (reviewFee)      reviewFee.textContent      = `${fee.toFixed(2)} EGP`;
  if (reviewTotal)    reviewTotal.textContent    = `${total.toFixed(2)} EGP+`;
}

function formatDate(raw) {
  if (!raw) return '—';
  const d = new Date(raw + 'T00:00:00');
  return d.toLocaleDateString('en-EG', { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' });
}

// ─── Date helpers ─────────────────────────────────────────────────────────────

function getLocalDateStr(offset = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function findNextAvailableDate(availability, fromDateStr) {
  if (!availability || !availability.length) return fromDateStr;
  const avDays = availability.map(a => a.day);
  const DAY_NAMES = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
  for (let i = 0; i <= 13; i++) {
    const d = new Date(fromDateStr + 'T00:00:00');
    d.setDate(d.getDate() + i);
    if (avDays.includes(DAY_NAMES[d.getDay()])) {
      return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
    }
  }
  return fromDateStr;
}

// ─── Dynamic time slot generation ────────────────────────────────────────────

function renderTimeSlotsForDate(dateString, availability) {
  const container = document.getElementById('timeslotContainer');
  if (!container) return;

  const dayName = new Date(dateString + 'T00:00:00')
    .toLocaleDateString('en-US', { weekday: 'long' })
    .toLowerCase();

  const daySlot = (availability || []).find(a => a.day === dayName);

  container.innerHTML = '';

  if (!daySlot) {
    container.innerHTML = `
      <div class="timeslot-unavailable-msg">
        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
        Technician is not available on ${dayName.charAt(0).toUpperCase() + dayName.slice(1)}. Please select another date.
      </div>`;
    state.selectedTime = null;
    state.data.time = '';
    return;
  }

  const allSlots = generateHourlySlots(daySlot.from, daySlot.to);

  const morningSlots   = allSlots.filter(s => { const h = parseInt(s); return h >= 6  && h < 12; });
  const afternoonSlots = allSlots.filter(s => { const h = parseInt(s); return h >= 12 && h < 18; });
  const eveningSlots   = allSlots.filter(s => { const h = parseInt(s); return h >= 18 && h < 22; });

  const groups = [
    { label: 'Morning (6 AM – 12 PM)',   slots: morningSlots },
    { label: 'Afternoon (12 PM – 6 PM)', slots: afternoonSlots },
    { label: 'Evening (6 PM – 10 PM)',   slots: eveningSlots },
  ].filter(g => g.slots.length > 0);

  if (groups.length === 0) {
    container.innerHTML = `<div class="timeslot-unavailable-msg">No time slots available for this day.</div>`;
    return;
  }

  const clockSvg = `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`;

  groups.forEach(group => {
    const section = document.createElement('div');
    section.className = 'timeslot-section';
    section.innerHTML = `
      <div class="timeslot-section__label">
        ${clockSvg}
        <span>${group.label}</span>
      </div>
      <div class="timeslot-grid" role="group" aria-label="${group.label} time slots">
        ${group.slots.map(slot => {
          const label = formatTimeLabel(slot);
          return `<button type="button" class="timeslot-pill" data-time="${slot}">${label}</button>`;
        }).join('')}
      </div>`;
    container.appendChild(section);
  });

  // Fetch and mark booked slots for this date
  if (workerId) {
    getWorkerBookedSlots(workerId, dateString)
      .then(res => {
        const booked = res.data?.bookedSlots || res.bookedSlots || [];
        booked.forEach(t => {
          const pill = container.querySelector(`.timeslot-pill[data-time="${t}"]`);
          if (pill) {
            pill.classList.add('is-unavailable');
            pill.disabled = true;
            pill.setAttribute('aria-disabled', 'true');
          }
        });
      })
      .catch(() => {});
  }

  // Reset selection
  state.selectedTime = null;
  state.data.time = '';
}

function generateHourlySlots(from, to) {
  const slots = [];
  let [h] = from.split(':').map(Number);
  const [endH] = to.split(':').map(Number);
  while (h < endH) {
    slots.push(`${String(h).padStart(2, '0')}:00`);
    h++;
  }
  return slots;
}

function formatTimeLabel(slot) {
  const [hStr] = slot.split(':');
  const h = parseInt(hStr);
  const suffix = h >= 12 ? 'PM' : 'AM';
  const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
  return `${h12}:00 ${suffix}`;
}

// ─── Worker UI population ─────────────────────────────────────────────────────

function updateWorkerUI(worker) {
  const name     = worker.name     || 'Professional';
  const rating   = typeof worker.averageRating === 'number' ? worker.averageRating.toFixed(1) : '5.0';
  const reviews  = worker.totalReviews || 0;
  const years    = worker.yearsExperience;
  const jobs     = worker.completedJobs;
  const rate     = worker.hourlyRate || 0;
  const specialty= (Array.isArray(worker.categories) && worker.categories[0]) || 'Home Services';
  const location = worker.locationLabel || '';
  const initials = name.split(' ').filter(Boolean).map(n => n[0]).join('').slice(0, 2).toUpperCase() || '?';

  // Page title
  document.title = `Book Service – ${name} | SERVIO`;

  // Breadcrumb
  const breadcrumb = document.getElementById('breadcrumbTechLink');
  const breadcrumbSep = document.getElementById('breadcrumbTechSep');
  if (breadcrumb) {
    breadcrumb.textContent = name;
    breadcrumb.style.display = '';
  }
  if (breadcrumbSep) {
    breadcrumbSep.style.display = '';
  }

  // Hero card
  const avatarEl = document.getElementById('heroCardAvatar');
  if (avatarEl) {
    if (worker.profileImage) {
      avatarEl.innerHTML = `<img src="${worker.profileImage}" alt="${name}" style="width:48px;height:48px;border-radius:12px;object-fit:cover;" />`;
    } else {
      avatarEl.textContent = initials;
    }
  }
  setText('heroCardName', name);
  setText('heroCardService', specialty);
  setText('heroRatingNum', rating);
  const ratingCount = document.getElementById('heroRatingCount');
  if (ratingCount) ratingCount.textContent = `(${reviews} review${reviews !== 1 ? 's' : ''})`;
  setText('heroStatYears', years ? `${years}+` : '—');
  setText('heroStatJobs', jobs ? `${jobs}+` : '—');

  // Service strip
  const stripImg = document.getElementById('stripAvatar');
  const stripInit = document.getElementById('stripAvatarInitials');
  if (worker.profileImage && stripImg && stripInit) {
    stripImg.src = worker.profileImage;
    stripImg.alt = name;
    stripImg.style.display = '';
    stripInit.style.display = 'none';
  } else if (stripInit) {
    stripInit.textContent = initials;
  }
  setText('stripName', name);
  setText('stripRole', [specialty, location].filter(Boolean).join(' · '));
  setText('stripRate', `${rate} EGP / hr`);

  // Sidebar
  const sidebarImg  = document.getElementById('sidebarAvatar');
  const sidebarInit = document.getElementById('sidebarAvatarInitials');
  if (worker.profileImage && sidebarImg && sidebarInit) {
    sidebarImg.src = worker.profileImage;
    sidebarImg.alt = name;
    sidebarImg.style.display = '';
    sidebarInit.style.display = 'none';
  } else if (sidebarInit) {
    sidebarInit.textContent = initials;
  }
  setText('sidebarTechName', name);
  setText('sidebarTechRole', years ? `${specialty} · ${years} yrs exp.` : specialty);
  const sidebarRatingText = document.getElementById('sidebarRatingText');
  if (sidebarRatingText) sidebarRatingText.textContent = `${rating} · ${reviews} reviews`;
  const sidebarTechRating = document.getElementById('sidebarTechRating');
  if (sidebarTechRating) sidebarTechRating.style.opacity = '1';

  const fee   = rate * 0.10;
  const total = rate + fee;
  setText('sidebarBaseRate', `${rate.toFixed(2)} EGP`);
  setText('sidebarFee',      `${fee.toFixed(2)} EGP`);
  setText('sidebarTotal',    `${total.toFixed(2)} EGP+`);
}

function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

// ─── Services dropdown ────────────────────────────────────────────────────────

async function loadServices(worker) {
  if (!serviceType) return;

  let allServices = [];
  try {
    const res = await getServices({ limit: 100, isActive: true });
    allServices = res.data?.services || res.services || res.data || [];
  } catch (e) {
    console.warn('Could not load services:', e);
  }

  const workerServiceIds = (worker.services || []).map(s => (s._id || s).toString());
  const workerCategories = worker.categories || [];

  let filtered = allServices.filter(svc => {
    const svcId  = (svc._id || svc.id || '').toString();
    const inList = workerServiceIds.includes(svcId);
    const inCat  = workerCategories.includes(svc.category);
    return inList || inCat;
  });

  if (filtered.length === 0) filtered = allServices;

  // Clear default options except placeholder
  while (serviceType.options.length > 1) serviceType.remove(1);

  if (filtered.length === 0) {
    const opt = document.createElement('option');
    opt.disabled = true;
    opt.textContent = 'No services available — contact support.';
    serviceType.appendChild(opt);
  } else {
    filtered.forEach(svc => {
      const opt = document.createElement('option');
      opt.value = svc._id || svc.id || '';
      opt.textContent = svc.category ? `${svc.title} — ${svc.category}` : svc.title;
      serviceType.appendChild(opt);
    });

    // "Other" catch-all
    const otherOpt = document.createElement('option');
    otherOpt.value = 'other';
    otherOpt.textContent = 'Other';
    serviceType.appendChild(otherOpt);

    // Pre-select from URL param
    if (serviceIdParam) {
      const match = Array.from(serviceType.options).find(o => o.value === serviceIdParam);
      if (match) serviceType.value = serviceIdParam;
    }
  }
}

// ─── Address prefill ──────────────────────────────────────────────────────────

async function prefillUserAddress() {
  if (!bookAddress) return;
  try {
    const res  = await getMe();
    const user = res.user || res.data?.user || res;
    const addr = user.address;
    if (addr) {
      const parts = [addr.street, addr.city, addr.state].filter(Boolean);
      if (parts.length) {
        bookAddress.value = parts.join(', ');
        bookAddress.dataset.autofilled = 'true';

        // Visual autofill state via CSS class on wrapper
        const wrap = bookAddress.closest('.field-icon-wrap');
        if (wrap) wrap.classList.add('field-icon-wrap--autofilled');

        // Polished autofill badge below the input
        const badge = document.createElement('div');
        badge.className = 'field-autofill-badge';
        badge.innerHTML = `
          <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
          </svg>
          Auto-filled from your profile — click to edit`;
        bookAddress.closest('.field')?.appendChild(badge);

        bookAddress.addEventListener('input', () => {
          badge.style.opacity = '0';
          setTimeout(() => badge.remove(), 220);
          if (wrap) wrap.classList.remove('field-icon-wrap--autofilled');
          delete bookAddress.dataset.autofilled;
        }, { once: true });
      }
    }
  } catch (e) {
    console.warn('Could not prefill address:', e);
  }
}

// ─── Init: load worker data ───────────────────────────────────────────────────

async function init() {
  const layout    = document.getElementById('bookingLayout');
  const unavail   = document.getElementById('bookingUnavailableState');

  function showUnavailable(msg) {
    if (layout) layout.style.display = 'none';
    if (unavail) {
      unavail.style.display = '';
      const msgEl = document.getElementById('bookingUnavailableMsg');
      if (msgEl) msgEl.textContent = msg;
    }
    setText('heroCardName', '—');
    setText('heroCardService', '');
    setText('heroRatingNum', '—');
    const heroAvatar = document.getElementById('heroCardAvatar');
    if (heroAvatar) heroAvatar.textContent = '?';
  }

  if (!workerId) {
    window.location.replace('./technician-listing.html');
    return;
  }

  let worker;
  try {
    const res = await getWorker(workerId);
    worker = res.data?.user || res.data?.worker || res.user || res.worker || res.data || res;
  } catch (e) {
    showUnavailable('Could not load technician details. Please try again.');
    return;
  }

  if (!worker || !worker.name) {
    showUnavailable('Technician not found.');
    return;
  }

  if (!worker.isActive) {
    showUnavailable('This technician is currently unavailable.');
    return;
  }

  // Real-time availability check — technician must have their toggle enabled
  if (worker.isAvailable === false) {
    showUnavailable('This technician is currently offline and not accepting new bookings. Please check back later or find another professional.');
    return;
  }

  if (!worker.isVerified || worker.verificationStatus === 'pending') {
    showUnavailable('This technician is pending verification. Please check back later or find another pro.');
    return;
  }

  state.worker = worker;

  updateWorkerUI(worker);

  // Auto-select the nearest day the technician is available (local date, not UTC)
  const todayStr   = getLocalDateStr();
  const startDate  = findNextAvailableDate(worker.availability || [], todayStr);
  if (bookDate) {
    bookDate.min   = todayStr;
    bookDate.value = startDate;
    renderTimeSlotsForDate(startDate, worker.availability || []);
  }

  await Promise.all([
    loadServices(worker),
    prefillUserAddress(),
  ]);
}

init().catch(err => console.error('Booking init error:', err));

// ─── Payment modal ────────────────────────────────────────────────────────────

function openPaymentModal() {
  const rate  = state.worker?.hourlyRate || 0;
  const total = (rate * 1.10).toFixed(2);
  setText('payModalAmount', `Total: ${total} EGP`);

  const overlay = document.getElementById('paymentModalOverlay');
  const modal   = document.getElementById('paymentModal');
  if (!overlay || !modal) return;

  overlay.hidden = false;
  document.body.style.overflow = 'hidden';

  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animate(overlay, { opacity: [0, 1] }, { duration: 0.25 });
    animate(modal, { opacity: [0, 1], y: [30, 0], scale: [0.95, 1] }, { duration: 0.35, easing: [0.22, 1, 0.36, 1] });
  }

  document.getElementById('pmCardHolder')?.focus();
}

function closePaymentModal() {
  const overlay = document.getElementById('paymentModalOverlay');
  if (!overlay) return;
  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animate(overlay, { opacity: [1, 0] }, { duration: 0.2 }).then(() => {
      overlay.hidden = true;
      document.body.style.overflow = '';
      resetPaymentModal();
    });
  } else {
    overlay.hidden = true;
    document.body.style.overflow = '';
    resetPaymentModal();
  }
}

function resetPaymentModal() {
  const form       = document.getElementById('payModalForm');
  const processing = document.getElementById('payModalProcessing');
  const success    = document.getElementById('payModalSuccess');
  const errorMsg   = document.getElementById('payModalErrorMsg');
  if (form)       { form.hidden = false; }
  if (processing) { processing.hidden = true; }
  if (success)    { success.hidden = true; }
  if (errorMsg)   { errorMsg.style.display = 'none'; errorMsg.textContent = ''; }
  ['pmCardHolder', 'pmCardNumber', 'pmExpiry', 'pmCVV'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
}

function validatePaymentForm() {
  const name = document.getElementById('pmCardHolder')?.value.trim() || '';
  const num  = (document.getElementById('pmCardNumber')?.value || '').replace(/\s/g, '');
  const exp  = document.getElementById('pmExpiry')?.value.trim() || '';
  const cvv  = document.getElementById('pmCVV')?.value.trim() || '';

  if (!name)                                          return 'Please enter the cardholder name.';
  if (num.length !== 16 || !/^\d+$/.test(num))       return 'Please enter a valid 16-digit card number.';
  if (!/^\d{2}\s*\/\s*\d{2}$/.test(exp))             return 'Please enter a valid expiry (MM / YY).';
  if (cvv.length < 3 || !/^\d+$/.test(cvv))          return 'Please enter a valid CVV.';
  return null;
}

// Card number formatting
document.getElementById('pmCardNumber')?.addEventListener('input', (e) => {
  const raw = e.target.value.replace(/\D/g, '').slice(0, 16);
  e.target.value = raw.replace(/(.{4})/g, '$1 ').trim();
});

document.getElementById('pmExpiry')?.addEventListener('input', (e) => {
  const raw = e.target.value.replace(/\D/g, '').slice(0, 4);
  e.target.value = raw.length > 2 ? raw.slice(0, 2) + ' / ' + raw.slice(2) : raw;
});

// Pay Now
document.getElementById('payModalSubmit')?.addEventListener('click', async () => {
  const error = validatePaymentForm();
  const errorMsg = document.getElementById('payModalErrorMsg');
  if (error) {
    if (errorMsg) { errorMsg.textContent = error; errorMsg.style.display = 'block'; }
    return;
  }
  if (errorMsg) { errorMsg.style.display = 'none'; }

  const form       = document.getElementById('payModalForm');
  const processing = document.getElementById('payModalProcessing');
  const success    = document.getElementById('payModalSuccess');

  if (form)       form.hidden = true;
  if (processing) processing.hidden = false;

  await new Promise(resolve => setTimeout(resolve, 2000));

  if (processing) processing.hidden = true;
  if (success) {
    success.hidden = false;
    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      animate(success, { opacity: [0, 1], scale: [0.9, 1] }, { duration: 0.4 });
    }
  }
});

document.getElementById('payModalContinue')?.addEventListener('click', async () => {
  closePaymentModal();
  await finalizeBooking();
});

document.getElementById('payModalClose')?.addEventListener('click', closePaymentModal);

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    const overlay = document.getElementById('paymentModalOverlay');
    if (overlay && !overlay.hidden) closePaymentModal();
  }
});

document.getElementById('paymentModalOverlay')?.addEventListener('click', (e) => {
  if (e.target === e.currentTarget) closePaymentModal();
});

// ─── Finalize booking ─────────────────────────────────────────────────────────

async function finalizeBooking() {
  collectStep1();
  collectStep2();

  const pin = Math.floor(1000 + Math.random() * 9000);
  const paymentMethod = PAYMENT_LABELS[state.data.payment] || state.data.payment;
  const readableDate  = formatDate(state.data.date);

  // Try real API first
  let bookingId = null;
  if (workerId && state.data.serviceId && state.data.serviceId !== 'other') {
    try {
      const payload = {
        workerId,
        serviceId:     state.data.serviceId,
        scheduledDate: state.data.date,
        scheduledTime: state.selectedTime || '',
        address:       state.data.address,
        description:   document.getElementById('bookNotes')?.value.trim() || '',
      };
      const res = await createBooking(payload);
      bookingId = res.data?._id || res._id || res.data?.booking?._id || null;
    } catch (e) {
      console.warn('createBooking API error (falling back to local):', e);
    }
  }

  const bookingData = {
    id: bookingId || ('S-' + Math.floor(2900 + Math.random() * 100)),
    bookingId,
    workerId,
    workerName: state.worker?.name || '',
    service:    state.data.serviceType,
    category:   state.data.serviceType,
    payment:    state.data.payment,
    paymentMethod,
    date:          readableDate,
    scheduledDate: readableDate,
    time:          state.data.time,
    scheduledTime: state.selectedTime || state.data.time,
    address:       state.data.address,
    pin,
    status:    'Booked',
    timestamp: Date.now(),
  };

  localStorage.setItem('servio_active_booking', JSON.stringify(bookingData));
  const existing = JSON.parse(localStorage.getItem('servio_bookings') || '[]');
  existing.push(bookingData);
  if (existing.length > 50) existing.splice(0, existing.length - 50);
  localStorage.setItem('servio_bookings', JSON.stringify(existing));

  window.location.href = './booking-confirmation.html';
}

// ─── Step navigation ─────────────────────────────────────────────────────────

async function goToStep(target) {
  if (target === state.currentStep) return;

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const direction = target > state.currentStep ? 1 : -1;
  const fromPanel = document.getElementById(`step-${state.currentStep}`);
  const toPanel   = document.getElementById(`step-${target}`);
  if (!fromPanel || !toPanel) return;

  if (!prefersReducedMotion) {
    await animate(fromPanel,
      { opacity: [1, 0], x: [0, direction * -30] },
      { duration: 0.22, easing: 'ease-in' }
    ).finished;
  }

  fromPanel.classList.remove('is-active');
  fromPanel.style.cssText = '';
  toPanel.classList.add('is-active');

  if (!prefersReducedMotion) {
    toPanel.style.opacity = '0';
    toPanel.style.transform = `translateX(${direction * 30}px)`;
    animate(toPanel, { opacity: [0, 1], x: [direction * 30, 0] }, { duration: 0.3, easing: [0.25, 0.46, 0.45, 0.94] });
  }

  const revealEls = toPanel.querySelectorAll('.field, .timeslot-section, .payment-option, .review-block');
  if (revealEls.length && !prefersReducedMotion) {
    animate(revealEls, { opacity: [0, 1], y: [10, 0] }, { duration: 0.3, delay: stagger(0.05), easing: 'ease-out' });
  }

  state.currentStep = target;
  updateStepper(prefersReducedMotion);
  document.querySelector('.booking-stepper')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// ─── Stepper UI ───────────────────────────────────────────────────────────────

function updateStepper(prefersReducedMotion) {
  stepItems.forEach((item, idx) => {
    const stepNum = idx + 1;
    const numEl   = item.querySelector('.step-num');
    item.classList.remove('is-active', 'is-done');

    if (stepNum < state.currentStep) {
      item.classList.add('is-done');
      if (numEl) numEl.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3"><polyline points="20 6 9 17 4 12"></polyline></svg>`;
      if (!prefersReducedMotion) animate(item, { scale: [1, 1.04, 1] }, { duration: 0.25 });
    } else if (stepNum === state.currentStep) {
      item.classList.add('is-active');
      if (numEl) numEl.textContent = stepNum;
      if (!prefersReducedMotion) animate(item.querySelector('.step-num'), { scale: [0.85, 1.1, 1] }, { duration: 0.3 });
    } else {
      if (numEl) numEl.textContent = stepNum;
    }
  });
}

// ─── Entry animation ─────────────────────────────────────────────────────────

(function entryAnimation() {
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReducedMotion) return;

  const heroEyebrow = document.querySelector('.booking-hero__eyebrow');
  const heroTitle   = document.querySelector('.booking-hero__title');
  const heroSub     = document.querySelector('.booking-hero__sub');
  const trustPills  = document.querySelectorAll('.trust-pill');
  const techCard    = document.querySelector('.tech-hero-card');
  const heroStats   = document.querySelectorAll('.hero-stat');

  if (heroEyebrow) animate(heroEyebrow, { opacity: [0, 1], y: [-10, 0] }, { duration: 0.4, easing: 'ease-out' });
  if (heroTitle)   animate(heroTitle,   { opacity: [0, 1], y: [16, 0] },  { duration: 0.45, delay: 0.08, easing: [0.22, 1, 0.36, 1] });
  if (heroSub)     animate(heroSub,     { opacity: [0, 1], y: [10, 0] },  { duration: 0.4, delay: 0.16, easing: 'ease-out' });
  if (trustPills.length) animate(trustPills, { opacity: [0, 1], y: [8, 0] }, { duration: 0.3, delay: stagger(0.06, { start: 0.28 }), easing: 'ease-out' });
  if (techCard) animate(techCard, { opacity: [0, 1], x: [24, 0], scale: [0.97, 1] }, { duration: 0.55, delay: 0.2, easing: [0.22, 1, 0.36, 1] });
  if (heroStats.length) animate(heroStats, { opacity: [0, 1], y: [6, 0] }, { duration: 0.3, delay: stagger(0.07, { start: 0.5 }), easing: 'ease-out' });

  const stepper = document.querySelector('.booking-stepper');
  const formCard = document.querySelector('.booking-form-card');
  const sidebar  = document.querySelector('.booking-sidebar');

  if (stepper) animate(stepper, { opacity: [0, 1], y: [-16, 0] }, { duration: 0.45, delay: 0.35, easing: 'ease-out' });
  if (formCard) animate(formCard, { opacity: [0, 1], y: [20, 0] }, { duration: 0.5, delay: 0.42, easing: 'ease-out' });
  if (sidebar)  animate(sidebar,  { opacity: [0, 1], x: [16, 0] }, { duration: 0.5, delay: 0.5, easing: 'ease-out' });

  const fields = document.querySelectorAll('#step-1 .field');
  if (fields.length) animate(fields, { opacity: [0, 1], y: [8, 0] }, { duration: 0.35, delay: stagger(0.06, { start: 0.55 }), easing: 'ease-out' });
})();
