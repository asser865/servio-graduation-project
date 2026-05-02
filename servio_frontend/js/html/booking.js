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

  // ── Role Guard ──────────────────────────────────────────
  if (session.role === 'admin') {
    window.location.href = './admin-dashboard.html';
    throw new Error('Role redirect — admin');
  } else if (session.role === 'technician') {
    window.location.href = './technician-dashboard.html';
    throw new Error('Role redirect — technician');
  }
})();

/**
 * booking.js — Multi-step booking flow with Motion One animations
 * Uses Motion One (vanilla JS Framer Motion) for smooth step transitions
 */

import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';
import { createBooking } from '../api/bookings.js';
import { getServices } from '../api/services.js';
import { getWorker, getWorkers } from '../api/users.js';
import { createPaymentIntent } from '../api/payments.js';

// ─── URL Params ───────────────────────────────────────────────────────────────
function getParam(key) {
  return new URLSearchParams(window.location.search).get(key);
}
const _workerIdFromUrl   = getParam('worker')  || '';
const _serviceKeyFromUrl = getParam('service') || '';

// ─── State ────────────────────────────────────────────────────────────────────

const state = {
  currentStep: 1,
  totalSteps: 3,
  selectedTime: null,
  selectedPayment: 'online',
  worker: null,
  services: [],
  data: {
    serviceType: '',
    serviceId: '',
    date: '',
    time: '',
    address: '',
    notes: '',
    payment: 'online',
  },
};

const MONGO_ID_RE = /^[a-f\d]{24}$/i;
const LEGACY_SERVICE_CATEGORY = {
  'pipe-repair': 'plumbing',
  'drain-cleaning': 'plumbing',
  'fixture-install': 'plumbing',
  'water-heater': 'plumbing',
  'full-inspection': 'plumbing',
  emergency: 'plumbing',
  plumbing: 'plumbing',
  electrical: 'electrical',
  painting: 'painting',
  flooring: 'flooring',
  carpentry: 'carpentry',
  cleaning: 'cleaning',
  hvac: 'hvac',
  ac: 'hvac',
  'ac-maintenance': 'hvac',
  other: 'other',
};

function isMongoId(value) {
  return MONGO_ID_RE.test(String(value || ''));
}

function normalizeKey(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function categoryFromKey(value) {
  return LEGACY_SERVICE_CATEGORY[normalizeKey(value)] || '';
}

function formatBookingError(err) {
  const validation = err?.data?.errors;
  if (Array.isArray(validation) && validation.length) {
    return validation
      .map((item) => item?.message)
      .filter(Boolean)
      .join('\n');
  }
  return err?.message || 'Booking failed. Please try again.';
}

function findServiceForKey(key, services = state.services) {
  if (!key || !services.length) return null;
  if (isMongoId(key)) {
    return services.find((service) => service._id === key || service.id === key) || null;
  }

  const normalized = normalizeKey(key);
  const category = categoryFromKey(key);
  return services.find((service) => {
    const serviceId = service._id || service.id || '';
    const title = normalizeKey(service.title || service.name || '');
    const titleAr = normalizeKey(service.titleAr || '');
    return serviceId === key ||
      service.category === key ||
      (category && service.category === category) ||
      title === normalized ||
      titleAr === normalized;
  }) || null;
}

async function ensureServicesLoaded() {
  if (state.services.length) return state.services;
  const svcRes = await getServices({ limit: 50, _: Date.now().toString() });
  state.services = svcRes.services || svcRes.data?.services || [];
  return state.services;
}

function renderServiceOptions(services) {
  if (!serviceType) return;

  if (!services.length) {
    serviceType.innerHTML = `<option value="" selected>${t('booking_svc_unavailable')}</option>`;
    serviceType.value = '';
    serviceType.disabled = true;
    return;
  }

  serviceType.disabled = false;
  const requested = _serviceKeyFromUrl || serviceType.value || '';
  const selectedService = findServiceForKey(requested, services);
  serviceType.innerHTML =
    `<option value="" disabled>${t('booking_svc_select_ph')}</option>` +
    services.map((service) => {
      const id = service._id || service.id;
      const title = service.title || service.name || 'Service';
      const category = service.category || '';
      return `<option value="${id}" data-category="${category}">${title}</option>`;
    }).join('') +
    `<option value="other">${t('booking_svc_other')}</option>`;

  serviceType.value = selectedService?._id || selectedService?.id || '';
}

async function resolveSelectedService() {
  const services = await ensureServicesLoaded();
  if (!services.length) {
    throw new Error(t('booking_err_no_services'));
  }

  const selectedOption = serviceType?.options[serviceType.selectedIndex];
  const selectedValue = serviceType?.value || '';
  const lookupValue = selectedValue === 'other'
    ? 'other'
    : selectedValue || _serviceKeyFromUrl || selectedOption?.dataset.category || '';
  const service = findServiceForKey(lookupValue, services) ||
    findServiceForKey(selectedOption?.dataset.category, services);

  if (!service?._id && !service?.id) {
    throw new Error(t('booking_err_service_catalog'));
  }

  return service;
}

async function resolveSelectedWorker(service) {
  const existingWorkerId = _workerIdFromUrl || state.worker?._id || state.worker?.id || '';
  if (isMongoId(existingWorkerId)) return existingWorkerId;

  const category = service?.category ||
    serviceType?.options[serviceType.selectedIndex]?.dataset.category ||
    categoryFromKey(_serviceKeyFromUrl);
  const workerRes = await getWorkers({
    limit: 1,
    ...(category ? { category } : {}),
  });
  const workers = workerRes.workers || workerRes.data?.workers || [];
  const worker = workers.find((item) => isMongoId(item._id || item.id));

  if (!worker) {
    throw new Error(t('booking_err_no_worker'));
  }

  state.worker = worker;
  updateWorkerUI(worker);
  return worker._id || worker.id;
}

// ─── Initialize ─────────────────────────────────────────────────────────────
async function init() {
  if (isMongoId(_workerIdFromUrl)) {
    try {
      const res = await getWorker(_workerIdFromUrl);
      state.worker = res.worker || res;
      updateWorkerUI(state.worker);
    } catch (err) {
      console.error('Failed to fetch worker:', err);
    }
  }

  // Populate services list if possible
  try {
     const svcs = await ensureServicesLoaded();
     renderServiceOptions(svcs);
  } catch(e) {
    console.warn('Failed to load services:', e);
  }
}
init();

function updateWorkerUI(w) {
  if (!w) return;
  // Hero elements
  const heroName = document.querySelector('.tech-hero-card__name');
  const heroService = document.querySelector('.tech-hero-card__service');
  const heroAvatar = document.querySelector('.tech-hero-card__avatar');
  const heroRating = document.querySelector('.hero-rating-num');
  
  if (heroName) heroName.textContent = w.name;
  if (heroService) heroService.textContent = w.category || 'Professional';
  if (heroAvatar) {
     if (w.profileImage) {
        heroAvatar.innerHTML = `<img src="${w.profileImage}" alt="${w.name}" style="width:100%;height:100%;border-radius:inherit;object-fit:cover;">`;
     } else {
        heroAvatar.textContent = w.name.split(' ').map(n=>n[0]).join('').slice(0,2).toUpperCase();
     }
  }
  if (heroRating) heroRating.textContent = (w.averageRating || 4.9).toFixed(1);

  // Strip
  const stripName = document.querySelector('.service-strip__name');
  const stripRate = document.querySelector('.service-strip__rate');
  const stripAvatar = document.querySelector('.service-strip__avatar');
  if (stripName) stripName.textContent = w.name;
  if (stripRate) stripRate.textContent = `${w.hourlyRate || 50} EGP / hr`;
  if (stripAvatar && w.profileImage) stripAvatar.src = w.profileImage;

  // Sidebar
  const sideName = document.querySelector('.summary-tech__name');
  const sideAvatar = document.querySelector('.summary-tech__avatar');
  const sideBaseRate = document.querySelector('[data-i18n="booking_summary_base_rate_val"]');
  const sideTotal = document.querySelector('[data-i18n="booking_summary_total_val"]');
  const reviewRate = document.querySelector('[data-i18n="booking_review_base_rate_val"]');
  const reviewTotal = document.querySelector('[data-i18n="booking_review_total_val"]');

  if (sideName) sideName.textContent = w.name;
  if (sideAvatar && w.profileImage) sideAvatar.src = w.profileImage;
  
  const rate = w.hourlyRate || 50;
  const fee = (rate * 0.10);
  const total = rate + fee;

  const fmt = (n) => n.toFixed(2) + ' EGP';
  if (sideBaseRate) sideBaseRate.textContent = fmt(rate);
  if (sideTotal) sideTotal.textContent = fmt(total) + '+';
  if (reviewRate) reviewRate.textContent = fmt(rate) + ' / hr';
  if (reviewTotal) reviewTotal.textContent = fmt(total) + ' EGP+';
}

// ─── DOM refs ─────────────────────────────────────────────────────────────────

const panels       = document.querySelectorAll('.step-panel');
const stepItems    = document.querySelectorAll('.step-item');
const timeslots    = document.querySelectorAll('.timeslot-pill');
const paymentOpts  = document.querySelectorAll('.payment-option');
const cardFields   = document.getElementById('cardFields');

// Step 1
const step1Next    = document.getElementById('step1Next');
const serviceType  = document.getElementById('serviceType');
const bookDate     = document.getElementById('bookDate');
const bookAddress  = document.getElementById('bookAddress');

// Step 2
const step2Back    = document.getElementById('step2Back');
const step2Next    = document.getElementById('step2Next');

// Step 3
const step3Back    = document.getElementById('step3Back');
const confirmBtn   = document.getElementById('confirmBtn');
const termsCheck   = document.getElementById('termsCheck');

// Review values
const reviewService  = document.getElementById('reviewService');
const reviewDate     = document.getElementById('reviewDate');
const reviewTime     = document.getElementById('reviewTime');
const reviewAddress  = document.getElementById('reviewAddress');
const reviewPayment  = document.getElementById('reviewPayment');

// ─── "Other" service type – show/hide problem description field ───────────────

const otherProblemRow = document.getElementById('otherProblemRow');
const otherProblem    = document.getElementById('otherProblem');

if (serviceType && otherProblemRow && otherProblem) {
  serviceType.addEventListener('change', () => {
    const isOther = serviceType.value === 'other';
    otherProblemRow.style.display = isOther ? '' : 'none';
    otherProblem.required = isOther;
    if (!isOther) otherProblem.value = '';
  });
}

// ─── Date input: set min to today ─────────────────────────────────────────────

(function setMinDate() {
  if (!bookDate) return;
  const today = new Date().toISOString().split('T')[0];
  bookDate.min = today;
})();

// ─── Time slot selection ──────────────────────────────────────────────────────

// Use event delegation for more robustness
document.addEventListener('click', (e) => {
  const pill = e.target.closest('.timeslot-pill');
  if (!pill || pill.disabled || pill.classList.contains('is-unavailable')) return;

  // Toggle selection
  document.querySelectorAll('.timeslot-pill').forEach((p) => p.classList.remove('is-selected'));
  pill.classList.add('is-selected');
  
  state.selectedTime = pill.dataset.time;
  state.data.time = pill.textContent.trim();

  // Trigger feedback animation
  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animate(pill,
      { scale: [0.94, 1.05, 1], boxShadow: ["0 0 0 rgba(0,0,0,0)", "0 8px 20px rgba(154,140,115,0.3)", "0 4px 15px rgba(154,140,115,0.3)"] },
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

    // Toggle card fields
    if (cardFields) {
      const show = val === 'card';
      cardFields.classList.toggle('is-hidden', !show);
      if (show && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        animate(cardFields, { opacity: [0, 1], y: [-8, 0] }, { duration: 0.28 });
      }
    }

    // Selection animation
    if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      animate(opt, { scale: [0.97, 1.02, 1] }, { duration: 0.22 });
    }
  });
});

// ─── "Edit" buttons in review step ───────────────────────────────────────────

document.querySelectorAll('.review-block__edit').forEach((btn) => {
  btn.addEventListener('click', () => {
    const targetStep = parseInt(btn.dataset.goto, 10);
    goToStep(targetStep);
  });
});

// ─── Confirm button: require terms ───────────────────────────────────────────

if (confirmBtn) {
  confirmBtn.addEventListener('click', async (e) => {
    e.preventDefault();
    if (!termsCheck || !termsCheck.checked) {
      animate(termsCheck?.closest('.terms-check') || confirmBtn,
        { x: [0, -6, 6, -4, 4, 0] }, { duration: 0.4 });
      return;
    }

    collectStep1();
    collectStep2();

    const selectedOption = serviceType?.options[serviceType?.selectedIndex];
    const serviceName = selectedOption?.text || '';
    const rawDate      = bookDate?.value || state.data.date || '';
    const readableDate = formatDate(rawDate);
    const selectedTime = state.data.time || '';
    const paymentMethod = PAYMENT_LABELS[state.data.payment] || state.data.payment || 'Online Payment';

    // Disable button to prevent double-submit
    confirmBtn.disabled = true;
    confirmBtn.innerHTML = `
      <svg class="spinner" width="16" height="16" viewBox="0 0 24 24" style="margin-right:8px; animation: rotate 1s linear infinite"><circle cx="12" cy="12" r="10" fill="none" stroke="currentColor" stroke-width="3" stroke-dasharray="31.4 31.4"/></svg>
      Processing...
    `;

    try {
      const selectedService = await resolveSelectedService();
      const workerId = await resolveSelectedWorker(selectedService);
      const resolvedServiceId = selectedService._id || selectedService.id;

      const bookingPayload = {
        workerId:      workerId,
        serviceId:     resolvedServiceId,
        scheduledDate: rawDate || new Date().toISOString().split('T')[0],
        address:       state.data.address,
        notes:         state.data.notes || '',
      };

      const res  = await createBooking(bookingPayload);
      const booking = res.booking || res;
      const bookingId = booking._id;

      // ── Handle Payment ──
      if (state.data.payment === 'online') {
        try {
          const intentRes = await createPaymentIntent(bookingId);
          const { clientSecret } = intentRes;

          if (clientSecret && window.Stripe) {
            const stripe = Stripe(window.SERVIO_CONFIG.STRIPE_PUBLIC_KEY || 'pk_test_placeholder');
            // For a production app, we would mount Stripe Elements or use redirect
            // Here we simulate the successful payment redirect if it's a test environment
            console.log('Payment Intent Created:', clientSecret);
            // Example: const result = await stripe.confirmCardPayment(clientSecret, { ... });
          }
        } catch (payErr) {
          console.warn('Payment intent failed, proceeding as cash/pending:', payErr);
        }
      }

      const bookingData = {
        id:            bookingId,
        _id:           bookingId,
        service:       serviceName,
        category:      serviceName,
        payment:       state.data.payment,
        paymentMethod: paymentMethod,
        date:          readableDate,
        scheduledDate: readableDate,
        time:          selectedTime,
        scheduledTime: selectedTime,
        pin:           booking.pin || '—',
        status:        'Booked',
        timestamp:     Date.now(),
      };

      localStorage.setItem('servio_active_booking', JSON.stringify(bookingData));

      animate(confirmBtn, { scale: [1, 0.95, 1.02, 1] }, { duration: 0.3 });
      setTimeout(() => { window.location.href = './booking-confirmation.html'; }, 500);

    } catch (err) {
      confirmBtn.disabled = false;
      confirmBtn.innerHTML = `<span>${t('booking_confirm')}</span> <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"></polyline></svg>`;
      
      const errEl = document.querySelector('[data-booking-error]') || document.querySelector('.booking-error');
      const msg = formatBookingError(err);
      if (errEl) {
        errEl.textContent = msg;
        errEl.hidden = false;
        animate(errEl, { opacity: [0, 1], y: [-10, 0] });
      } else {
        alert(msg);
      }
    }
  });
}

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

// ─── Validation ──────────────────────────────────────────────────────────────

function validateStep1() {
  const errors = [];

  if (!serviceType?.value) errors.push(serviceType);
  if (serviceType?.value === 'other' && !otherProblem?.value.trim()) errors.push(otherProblem);
  if (!bookDate?.value)    errors.push(bookDate);
  if (!bookAddress?.value.trim()) errors.push(bookAddress);
  if (!state.selectedTime) {
    // Shake timeslot grid
    const grid = document.querySelector('.timeslot-grid');
    if (grid) animate(grid, { x: [0, -5, 5, -3, 3, 0] }, { duration: 0.35 });
    errors.push(null);
  }

  errors.forEach((el) => {
    if (!el) return;
    el.style.borderColor = '#e74c3c';
    el.focus();
    animate(el, { x: [0, -5, 5, -3, 3, 0] }, { duration: 0.35 });
    el.addEventListener('input', () => {
      el.style.borderColor = '';
    }, { once: true });
  });

  return errors.length === 0;
}

// ─── Data collection ──────────────────────────────────────────────────────────

function collectStep1() {
  const svcLabel = serviceType?.options[serviceType.selectedIndex]?.text || '';
  state.data.serviceType = serviceType?.value === 'other' && otherProblem?.value.trim()
    ? `Other: ${otherProblem.value.trim()}`
    : svcLabel;
  state.data.date = bookDate?.value || '';
  state.data.address = bookAddress?.value.trim() || '';
  state.data.time = state.data.time || '';
}

function collectStep2() {
  const selected = document.querySelector('.payment-option.is-selected input[type="radio"]');
  state.data.payment = selected?.value || 'online';
}

// ─── Populate review step ─────────────────────────────────────────────────────

const PAYMENT_LABELS = {
  online: 'Online Payment',
  cash: 'Cash',
};

function populateReview() {
  if (reviewService)  reviewService.textContent  = state.data.serviceType || '—';
  if (reviewDate)     reviewDate.textContent      = formatDate(state.data.date);
  if (reviewTime)     reviewTime.textContent      = state.data.time || '—';
  if (reviewAddress)  reviewAddress.textContent   = state.data.address || '—';
  if (reviewPayment)  reviewPayment.textContent   = PAYMENT_LABELS[state.data.payment] || state.data.payment;
}

function formatDate(raw) {
  if (!raw) return '—';
  const d = new Date(raw + 'T00:00:00');
  return d.toLocaleDateString('en-EG', { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' });
}

// ─── Core: go to step ────────────────────────────────────────────────────────

async function goToStep(target) {
  if (target === state.currentStep) return;

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const direction = target > state.currentStep ? 1 : -1;
  const fromPanel = document.getElementById(`step-${state.currentStep}`);
  const toPanel   = document.getElementById(`step-${target}`);
  if (!fromPanel || !toPanel) return;

  // Animate out current panel
  if (!prefersReducedMotion) {
    await animate(fromPanel,
      { opacity: [1, 0], x: [0, direction * -30] },
      { duration: 0.22, easing: 'ease-in' }
    ).finished;
  }

  fromPanel.classList.remove('is-active');
  fromPanel.style.cssText = '';

  // Show next panel
  toPanel.classList.add('is-active');
  if (!prefersReducedMotion) {
    toPanel.style.opacity = '0';
    toPanel.style.transform = `translateX(${direction * 30}px)`;

    // Animate in
    animate(toPanel,
      { opacity: [0, 1], x: [direction * 30, 0] },
      { duration: 0.3, easing: [0.25, 0.46, 0.45, 0.94] }
    );
  }

  // Stagger-reveal form fields inside new panel
  const revealEls = toPanel.querySelectorAll('.field, .timeslot-section, .payment-option, .review-block');
  if (revealEls.length && !prefersReducedMotion) {
    animate(revealEls,
      { opacity: [0, 1], y: [10, 0] },
      { duration: 0.3, delay: stagger(0.05), easing: 'ease-out' }
    );
  }

  // Update stepper
  state.currentStep = target;
  updateStepper(prefersReducedMotion);

  // Scroll to top of form
  document.querySelector('.booking-stepper')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// ─── Stepper UI update ───────────────────────────────────────────────────────

function updateStepper(prefersReducedMotion) {
  stepItems.forEach((item, idx) => {
    const stepNum  = idx + 1;
    const numEl    = item.querySelector('.step-num');

    item.classList.remove('is-active', 'is-done');

    if (stepNum < state.currentStep) {
      item.classList.add('is-done');
      if (numEl) {
        numEl.innerHTML = `
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>`;
      }
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

// ─── Card number formatting ───────────────────────────────────────────────────

document.getElementById('cardNumber')?.addEventListener('input', (e) => {
  const raw = e.target.value.replace(/\D/g, '').slice(0, 16);
  e.target.value = raw.replace(/(.{4})/g, '$1 ').trim();
});

document.getElementById('cardExpiry')?.addEventListener('input', (e) => {
  const raw = e.target.value.replace(/\D/g, '').slice(0, 4);
  if (raw.length > 2) {
    e.target.value = raw.slice(0, 2) + ' / ' + raw.slice(2);
  } else {
    e.target.value = raw;
  }
});

// ─── Entry animation ─────────────────────────────────────────────────────────

(function entryAnimation() {
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ── Hero animations ──
  const heroEyebrow  = document.querySelector('.booking-hero__eyebrow');
  const heroTitle    = document.querySelector('.booking-hero__title');
  const heroSub      = document.querySelector('.booking-hero__sub');
  const trustPills   = document.querySelectorAll('.trust-pill');
  const techCard     = document.querySelector('.tech-hero-card');
  const heroStats    = document.querySelectorAll('.hero-stat');

  if (!prefersReducedMotion) {
    if (heroEyebrow) animate(heroEyebrow, { opacity: [0, 1], y: [-10, 0] }, { duration: 0.4, easing: 'ease-out' });
    if (heroTitle)   animate(heroTitle,   { opacity: [0, 1], y: [16, 0]  }, { duration: 0.45, delay: 0.08, easing: [0.22, 1, 0.36, 1] });
    if (heroSub)     animate(heroSub,     { opacity: [0, 1], y: [10, 0]  }, { duration: 0.4,  delay: 0.16, easing: 'ease-out' });
    if (trustPills.length) {
      animate(trustPills, { opacity: [0, 1], y: [8, 0] }, { duration: 0.3, delay: stagger(0.06, { start: 0.28 }), easing: 'ease-out' });
    }
    if (techCard) {
      animate(techCard, { opacity: [0, 1], x: [24, 0], scale: [0.97, 1] }, { duration: 0.55, delay: 0.2, easing: [0.22, 1, 0.36, 1] });
    }
    if (heroStats.length) {
      animate(heroStats, { opacity: [0, 1], y: [6, 0] }, { duration: 0.3, delay: stagger(0.07, { start: 0.5 }), easing: 'ease-out' });
    }
  }

  // ── Page body animations ──
  const stepper = document.querySelector('.booking-stepper');
  const formCard = document.querySelector('.booking-form-card');
  const sidebar  = document.querySelector('.booking-sidebar');

  if (!prefersReducedMotion) {
    if (stepper) animate(stepper, { opacity: [0, 1], y: [-16, 0] }, { duration: 0.45, delay: 0.35, easing: 'ease-out' });
    if (formCard) animate(formCard, { opacity: [0, 1], y: [20, 0] }, { duration: 0.5, delay: 0.42, easing: 'ease-out' });
    if (sidebar)  animate(sidebar,  { opacity: [0, 1], x: [16, 0] }, { duration: 0.5, delay: 0.5, easing: 'ease-out' });
  }

  // Stagger initial form fields
  const fields = document.querySelectorAll('#step-1 .field, #step-1 .timeslot-section');
  if (fields.length && !prefersReducedMotion) {
    animate(fields, { opacity: [0, 1], y: [8, 0] }, { duration: 0.35, delay: stagger(0.06, { start: 0.55 }), easing: 'ease-out' });
  }
})();
