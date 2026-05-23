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
import { getWorker, getMe, addAddress }  from '../api/users.js';
import { getServices }       from '../api/services.js';
import { createBooking, getWorkerBookedSlots } from '../api/bookings.js';
import { getPlatformSettings } from '../api/platform.js';
import { holdPayment } from '../api/payments.js';
import { openCardPickerModal, closeCardPickerModal } from '../components/card-picker-modal.js';
import { showToast } from '../components/toast.js';
import { calculateBookingFee, formatMoney, DEFAULT_PLATFORM_FEE_RATE } from '../utils/fee.js';

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
  platformSettings: { commissionRate: DEFAULT_PLATFORM_FEE_RATE, cashPaymentsEnabled: true },
  data: {
    serviceId: '',
    serviceCategory: '',
    serviceType: '',
    date: '',
    time: '',
    address: '',
    notes: '',
    payment: 'online',
  },
  addresses: [], // List of { id, label, street, city, state, full }
};

// ─── DOM refs ─────────────────────────────────────────────────────────────────

const stepItems   = document.querySelectorAll('.step-item');
const paymentOpts = document.querySelectorAll('.payment-option');

const step1Next   = document.getElementById('step1Next');
const serviceType     = document.getElementById('serviceType');
const serviceCategory = document.getElementById('serviceCategory');
const serviceName     = document.getElementById('serviceName');
const bookDate    = document.getElementById('bookDate');
const bookAddress = document.getElementById('bookAddress');
const bookNotes   = document.getElementById('bookNotes');
const bookNotesCounter = document.getElementById('bookNotesCounter');

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
const reviewCard     = document.getElementById('reviewCard');
const reviewNotes    = document.getElementById('reviewNotes');

// otherProblemRow removed — general bookings use bookNotes textarea instead

// ─── Service picker state ─────────────────────────────────────────────────────

const pickerState = { category: '', serviceId: '', label: '' };

function setPickerSelection(catKey, svcId, label) {
  pickerState.category  = catKey;
  pickerState.serviceId = svcId;
  pickerState.label     = label;
  if (serviceType)     serviceType.value     = svcId || catKey;
  if (serviceCategory) serviceCategory.value = catKey;
  if (serviceName)     serviceName.value     = label;

  const confirmed = document.getElementById('svcPickerConfirmed');
  const lbl       = document.getElementById('svcConfirmedLabel');
  const cats      = document.getElementById('svcPickerCats');
  const subs      = document.getElementById('svcPickerSubs');
  if (lbl)       lbl.textContent = label;
  if (confirmed) confirmed.hidden = false;
  if (cats)      cats.hidden = true;
  if (subs)      subs.hidden = true;
}

function resetPicker() {
  pickerState.category = pickerState.serviceId = pickerState.label = '';
  if (serviceType)     serviceType.value     = '';
  if (serviceCategory) serviceCategory.value = '';
  if (serviceName)     serviceName.value     = '';
  const confirmed = document.getElementById('svcPickerConfirmed');
  const cats      = document.getElementById('svcPickerCats');
  const subs      = document.getElementById('svcPickerSubs');
  if (confirmed) confirmed.hidden = true;
  if (cats)      cats.hidden      = false;
  if (subs)      subs.hidden      = true;
}

// ─── Date validation helpers ──────────────────────────────────────────────────

const DAY_ABBR = { monday:'Mon', tuesday:'Tue', wednesday:'Wed', thursday:'Thu', friday:'Fri', saturday:'Sat', sunday:'Sun' };

function validateBookingDate(dateStr, availability) {
  const sel   = new Date(dateStr + 'T00:00:00');
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const max   = new Date(); max.setDate(max.getDate() + 30); max.setHours(0, 0, 0, 0);

  if (sel < today) return 'Please select a date that is today or in the future.';
  if (sel > max)   return 'You can only book up to 30 days in advance.';

  if (availability.length) {
    const dayName = sel.toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
    if (!availability.find(a => a.day === dayName)) {
      const available = availability.map(a => DAY_ABBR[a.day] || a.day).join(', ');
      return `Technician is not available on ${dayName.charAt(0).toUpperCase() + dayName.slice(1)}s. Available: ${available}.`;
    }
  }
  return null;
}

function showDateError(msg) {
  const el = document.getElementById('dateError');
  if (!el) return;
  el.textContent = msg;
  el.style.display = 'block';
  const input = document.getElementById('bookDate');
  if (input) input.style.borderColor = '#e74c3c';
}

function clearDateError() {
  const el = document.getElementById('dateError');
  if (el) { el.textContent = ''; el.style.display = 'none'; }
}

// ─── Custom calendar ──────────────────────────────────────────────────────────

const calState = {
  year:  new Date().getFullYear(),
  month: new Date().getMonth(), // 0-based
};

function buildCalendar(availability, blockedDates) {
  const today    = new Date(); today.setHours(0,0,0,0);
  const maxDate  = new Date(); maxDate.setDate(maxDate.getDate() + 30); maxDate.setHours(0,0,0,0);
  const avDays   = (availability || []).map(a => a.day);
  const DAY_NAMES = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];

  const grid      = document.getElementById('calGrid');
  const monthLbl  = document.getElementById('calMonthLabel');
  const prevBtn   = document.getElementById('calPrev');
  const nextBtn   = document.getElementById('calNext');
  if (!grid) return;

  const firstDay  = new Date(calState.year, calState.month, 1);
  const lastDay   = new Date(calState.year, calState.month + 1, 0);
  const monthName = firstDay.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  if (monthLbl) monthLbl.textContent = monthName;

  // Disable prev if entire prev month is before today
  const prevMonthEnd = new Date(calState.year, calState.month, 0);
  if (prevBtn) prevBtn.disabled = prevMonthEnd < today;

  // Disable next if entire next month is after maxDate
  const nextMonthStart = new Date(calState.year, calState.month + 1, 1);
  if (nextBtn) nextBtn.disabled = nextMonthStart > maxDate;

  // Leading empty cells
  let html = '';
  for (let i = 0; i < firstDay.getDay(); i++) html += '<div class="cal-day cal-day--empty"></div>';

  for (let day = 1; day <= lastDay.getDate(); day++) {
    const date    = new Date(calState.year, calState.month, day);
    const dateStr = `${calState.year}-${String(calState.month+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`;
    const isToday    = date.getTime() === today.getTime();
    const isPast     = date < today;
    const isFar      = date > maxDate;
    const dayName    = DAY_NAMES[date.getDay()];
    const isOffSched = avDays.length > 0 && !avDays.includes(dayName);
    const isBlocked  = (blockedDates || []).includes(dateStr);
    const isSelected = bookDate?.value === dateStr;

    let cls = 'cal-day';
    if      (isSelected)  cls += ' cal-day--selected';
    if      (isToday)     cls += ' cal-day--today';
    if      (isPast || isFar) cls += ' cal-day--past';
    else if (isBlocked)   cls += ' cal-day--blocked';
    else if (isOffSched)  cls += ' cal-day--off-schedule';
    else                  cls += ' cal-day--available';

    const clickable = !isPast && !isFar && !isBlocked && !isOffSched;
    html += `<div class="${cls}" ${clickable ? `data-date="${dateStr}"` : ''} title="${dateStr}">${day}</div>`;
  }

  grid.innerHTML = html;

  grid.querySelectorAll('.cal-day--available[data-date]').forEach(cell => {
    cell.addEventListener('click', () => {
      const d = cell.dataset.date;
      if (bookDate) bookDate.value = d;
      clearDateError();
      buildCalendar(availability, blockedDates);
      renderTimeSlotsForDate(d, availability);
    });
  });
}

function initCalendar(availability, blockedDates) {
  // Start at the first valid month that contains an available date
  const today = new Date(); today.setHours(0,0,0,0);
  calState.year  = today.getFullYear();
  calState.month = today.getMonth();

  document.getElementById('calPrev')?.addEventListener('click', () => {
    calState.month--;
    if (calState.month < 0) { calState.month = 11; calState.year--; }
    buildCalendar(availability, blockedDates);
  });
  document.getElementById('calNext')?.addEventListener('click', () => {
    calState.month++;
    if (calState.month > 11) { calState.month = 0; calState.year++; }
    buildCalendar(availability, blockedDates);
  });

  buildCalendar(availability, blockedDates);
}

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

const NOTE_PROMPTS = {
  issue: 'Problem: ',
  timing: 'Started: ',
  tried: 'Already tried: ',
  access: 'Access notes: ',
};

function updateNotesCounter() {
  if (!bookNotes || !bookNotesCounter) return;
  const max = Number(bookNotes.getAttribute('maxlength')) || 1000;
  const length = bookNotes.value.length;
  bookNotesCounter.textContent = `${length}/${max}`;
  bookNotesCounter.classList.toggle('is-near-limit', length >= Math.floor(max * 0.9));
}

bookNotes?.addEventListener('input', updateNotesCounter);
document.querySelectorAll('[data-note-prompt]').forEach((btn) => {
  btn.addEventListener('click', () => {
    if (!bookNotes) return;
    const addition = NOTE_PROMPTS[btn.dataset.notePrompt] || '';
    if (!addition) return;
    const current = bookNotes.value.trimEnd();
    const prefix = current ? '\n' : '';
    bookNotes.value = `${current}${prefix}${addition}`;
    bookNotes.focus();
    bookNotes.setSelectionRange(bookNotes.value.length, bookNotes.value.length);
    updateNotesCounter();
  });
});
updateNotesCounter();

paymentOpts.forEach((opt) => {
  opt.addEventListener('click', () => {
    if (opt.classList.contains('is-disabled')) return;
    paymentOpts.forEach((o) => o.classList.remove('is-selected'));
    opt.classList.add('is-selected');
    const radio = opt.querySelector('input[type="radio"]');
    if (radio) radio.checked = true;
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

confirmBtn?.addEventListener('click', async (e) => {
  e.preventDefault();
  if (!termsCheck || !termsCheck.checked) {
    animate(termsCheck?.closest('.terms-check') || confirmBtn,
      { x: [0, -6, 6, -4, 4, 0] }, { duration: 0.4 }
    );
    return;
  }
  if (!state.selectedTime) {
    showToast('Please select a time slot before confirming.', 'error');
    goToStep(1);
    return;
  }
  if (!state.data.date) {
    showToast('Please select a date before confirming.', 'error');
    goToStep(1);
    return;
  }
  collectStep1();
  collectStep2();

  if (state.data.payment === 'online') {
    if (!state.data.paymentMeta?.savedCardId) {
      promptCardThenSubmit();
      return;
    }
    submitOnlineBooking();
  } else {
    state.data.paymentMeta = null;
    animate(confirmBtn, { scale: [1, 0.95, 1.02, 1] }, { duration: 0.3 });
    setTimeout(() => finalizeBooking({}), 320);
  }
});

function promptCardThenSubmit() {
  const rate  = state.worker?.hourlyRate || 0;
  const total = calculateBookingFee(rate, state.platformSettings.commissionRate).estimatedTotal.toFixed(2);
  openCardPickerModal(total, async (paymentMeta) => {
    state.data.paymentMeta = paymentMeta;
    populateReview();
    await submitOnlineBooking();
  });
}

function promptCardOnly() {
  const rate  = state.worker?.hourlyRate || 0;
  const total = calculateBookingFee(rate, state.platformSettings.commissionRate).estimatedTotal.toFixed(2);
  openCardPickerModal(total, (paymentMeta) => {
    state.data.paymentMeta = paymentMeta;
    populateReview();
  });
}

async function submitOnlineBooking() {
  animate(confirmBtn, { scale: [1, 0.95, 1.02, 1] }, { duration: 0.3 });
  const booking = await finalizeBooking({ returnBooking: true });
  if (!booking) throw new Error('Booking creation failed.');
  try {
    await holdPayment(booking._id, { savedCardId: state.data.paymentMeta.savedCardId, useCredit: true });
    goToConfirmationOrNext(booking);
  } catch (err) {
    const msg = err?.data?.message || err?.message || 'Payment authorization failed. Please try another card.';
    showToast(msg, 'error');
    state.data.paymentMeta = null;
    populateReview();
    throw err;
  }
}

// ─── Validation ──────────────────────────────────────────────────────────────

function validateStep1() {
  const errors = [];

  // Service picker — must have a category selected
  if (!pickerState.category) {
    const picker = document.getElementById('svcPicker');
    if (picker) {
      picker.style.borderColor = '#e74c3c';
      picker.scrollIntoView({ behavior: 'smooth', block: 'center' });
      setTimeout(() => { picker.style.borderColor = ''; }, 2000);
    }
    errors.push(null);
  }
  if (!bookDate?.value) {
    errors.push(bookDate);
  } else {
    const dateErr = validateBookingDate(bookDate.value, state.worker?.availability || []);
    if (dateErr) {
      showDateError(dateErr);
      errors.push(null); // date error shown via showDateError, no input to shake
    }
  }
  if (!bookAddress?.value.trim()) {
    const list = document.getElementById('savedAddressesList');
    if (list) {
      list.style.borderColor = '#e74c3c';
      animate(list, { x: [0, -5, 5, -3, 3, 0] }, { duration: 0.35 });
      list.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    errors.push(null);
  }
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
  state.data.serviceId       = pickerState.serviceId;
  state.data.serviceCategory = pickerState.category;
  state.data.serviceType     = pickerState.label;
  state.data.date    = bookDate?.value || '';
  state.data.address = bookAddress?.value.trim() || '';
  state.data.time    = state.data.time || '';
  state.data.notes   = bookNotes?.value.trim() || '';
}

function collectStep2() {
  const selected = document.querySelector('.payment-option.is-selected input[type="radio"]');
  state.data.payment = selected?.value || 'online';
}

// ─── Populate review step ─────────────────────────────────────────────────────

const PAYMENT_LABELS = { online: 'Card payment', cash: 'Cash after service' };

function populateReview() {
  if (reviewTechName) reviewTechName.textContent = state.worker?.name || '—';
  if (reviewService)  reviewService.textContent  = state.data.serviceType || '—';
  if (reviewDate)     reviewDate.textContent      = formatDate(state.data.date);
  if (reviewTime)     reviewTime.textContent      = state.data.time || '—';
  if (reviewAddress)  reviewAddress.textContent   = state.data.address || '—';
  if (reviewPayment)  reviewPayment.textContent   = PAYMENT_LABELS[state.data.payment] || state.data.payment;
  if (reviewCard) {
    const meta = state.data.paymentMeta;
    const isOnline = state.data.payment === 'online';
    const hasCard = !!meta?.last4;
    reviewCard.textContent = isOnline
      ? (hasCard ? `${String(meta.cardType || 'Card').toUpperCase()} ending ${meta.last4} - no real charge` : 'Tap to select a card')
      : 'No card required.';
    reviewCard.classList.toggle('is-actionable', isOnline && !hasCard);
    reviewCard.style.cursor = (isOnline && !hasCard) ? 'pointer' : '';
    reviewCard.onclick = isOnline ? () => promptCardOnly() : null;
  }
  if (reviewNotes)    reviewNotes.textContent     = state.data.notes || 'No additional notes added.';

  const rate = state.worker?.hourlyRate || 0;
  const totals = calculateBookingFee(rate, state.platformSettings.commissionRate);

  setText('reviewFeeLabel', `Platform Fee (${totals.feeRate}%)`);
  if (reviewBaseRate) reviewBaseRate.textContent = `${formatMoney(totals.base)} / hr`;
  if (reviewFee)      reviewFee.textContent      = formatMoney(totals.feeAmount);
  if (reviewTotal)    reviewTotal.textContent    = `${formatMoney(totals.estimatedTotal)}+`;
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

// ─── Slot availability polling ────────────────────────────────────────────────

let slotPollTimer = null;
let slotPollDate  = null;

function refreshBookedSlots(dateStr) {
  if (!workerId) return;
  const container = document.getElementById('timeslotContainer');
  if (!container) return;
  getWorkerBookedSlots(workerId, dateStr)
    .then(res => {
      const booked = new Set(res.data?.bookedSlots || res.bookedSlots || []);
      console.debug('[booking] booked slots for', dateStr, Array.from(booked));
      container.querySelectorAll('.timeslot-pill').forEach(pill => {
        const shouldBlock = booked.has(pill.dataset.time);
        pill.classList.toggle('is-unavailable', shouldBlock);
        pill.disabled = shouldBlock;
        pill.setAttribute('aria-disabled', String(shouldBlock));
        if (shouldBlock && pill.classList.contains('is-selected')) {
          pill.classList.remove('is-selected');
          state.selectedTime = null;
          state.data.time = '';
        }
      });
    })
    .catch(err => {
      console.warn('[booking] failed to fetch booked slots', err);
    });
}

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && slotPollDate) {
    refreshBookedSlots(slotPollDate);
  }
});

function startSlotPoll(dateStr) {
  clearInterval(slotPollTimer);
  slotPollDate  = dateStr;
  slotPollTimer = setInterval(() => refreshBookedSlots(slotPollDate), 10_000);
}

window.addEventListener('beforeunload', () => clearInterval(slotPollTimer));

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

  const PERIOD_ICONS = {
    'morning': `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v8"/><path d="m4.93 10.93 1.41-1.41"/><path d="M2 18h2"/><path d="M20 18h2"/><path d="m19.07 10.93-1.41-1.41"/><path d="M22 22H2"/><path d="m8 6 4-4 4 4"/><path d="M16 18a4 4 0 0 0-8 0"/></svg>`,
    'afternoon': `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>`,
    'evening': `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>`
  };

  groups.forEach(group => {
    const periodKey = group.label.split(' ')[0].toLowerCase();
    const icon = PERIOD_ICONS[periodKey] || PERIOD_ICONS['morning'];
    const section = document.createElement('div');
    section.className = 'timeslot-section';
    section.innerHTML = `
      <div class="timeslot-section__label">
        ${icon}
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

  // Fetch and mark booked slots, then start 30s poll for live updates
  if (workerId) {
    refreshBookedSlots(dateString);
    startSlotPoll(dateString);
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
  const reviews  = worker.totalReviews || 0;
  const hasReviews = reviews > 0 && typeof worker.averageRating === 'number';
  const rating   = hasReviews ? worker.averageRating.toFixed(1) : 'New SERVIO Pro';
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
  if (ratingCount) ratingCount.textContent = hasReviews ? `(${reviews} review${reviews !== 1 ? 's' : ''})` : '';
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
  if (sidebarRatingText && !hasReviews) sidebarRatingText.textContent = 'New SERVIO Pro';
  const starPill = document.querySelector('.trust-pill--star');
  if (starPill) starPill.style.display = hasReviews && Number(worker.averageRating) >= 4.8 ? '' : 'none';

  const totals = calculateBookingFee(rate, state.platformSettings.commissionRate);
  setText('sidebarFeeLabel', `Platform fee (${totals.feeRate}%)`);
  setText('sidebarBaseRate', formatMoney(totals.base));
  setText('sidebarFee',      formatMoney(totals.feeAmount));
  setText('sidebarTotal',    `${formatMoney(totals.estimatedTotal)}+`);
}

function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function applyPaymentSettings() {
  const cashOption = document.querySelector('.payment-option[data-payment="cash"]');
  const cashInput = cashOption?.querySelector('input[type="radio"]');
  if (!cashOption || !cashInput) return;

  const cashEnabled = state.platformSettings.cashPaymentsEnabled !== false;
  cashOption.classList.toggle('is-disabled', !cashEnabled);
  cashInput.disabled = !cashEnabled;
  cashOption.setAttribute('aria-disabled', String(!cashEnabled));

  if (!cashEnabled && state.data.payment === 'cash') {
    state.data.payment = 'online';
    state.selectedPayment = 'online';
    const onlineOption = document.querySelector('.payment-option[data-payment="online"]');
    onlineOption?.classList.add('is-selected');
    const onlineInput = onlineOption?.querySelector('input[type="radio"]');
    if (onlineInput) onlineInput.checked = true;
    cashOption.classList.remove('is-selected');
  }
}

// ─── Two-step service picker ──────────────────────────────────────────────────

const CAT_LABELS = {
  plumbing:'Plumbing', electrical:'Electrical', hvac:'A/C & HVAC',
  carpentry:'Carpentry', appliance:'Appliances', handyman:'Handyman',
  renovation:'Renovation', painting:'Painting', flooring:'Flooring',
  drywall:'Drywall', roofing:'Roofing', cleaning:'Cleaning',
  'pest-control':'Pest Control', landscaping:'Landscaping',
  installation:'Installation', other:'Other',
};

const CAT_ICONS = {
  plumbing:'🔧', electrical:'⚡', hvac:'❄️', carpentry:'🪵',
  appliance:'🏠', handyman:'🔨', renovation:'🏗️', painting:'🎨',
  flooring:'🪨', drywall:'🧱', roofing:'🏠', cleaning:'🧹',
  'pest-control':'🐛', landscaping:'🌿', installation:'📺', other:'⚙️',
};

async function initServicePicker(worker) {
  const catsEl = document.getElementById('svcPickerCats');
  const subsEl = document.getElementById('svcPickerSubs');
  const changeBtn = document.getElementById('svcChangeBtn');
  if (!catsEl) return;

  changeBtn?.addEventListener('click', resetPicker);

  let allServices = [];
  try {
    const res = await getServices({ limit: 200 });
    allServices = res.data?.services || res.services || res.data || [];
  } catch (e) {
    catsEl.innerHTML = '<p style="color:#e74c3c;font-size:0.875rem;">Failed to load services.</p>';
    return;
  }

  // Only show services the worker explicitly selected in their dashboard
  const workerServiceIds = new Set((worker.services || []).map(s => (s._id || s).toString()));
  const workerCategories = new Set(worker.categories || []);

  const grouped = {};
  allServices.forEach(svc => {
    const id  = (svc._id || svc.id || '').toString();
    const cat = svc.category || 'other';
    if (!workerServiceIds.has(id)) return; // only explicitly selected services
    if (!grouped[cat]) grouped[cat] = [];
    grouped[cat].push(svc);
  });

  // For verified categories with no specific services selected → show category card
  // with only the "General" option (empty array triggers auto-general path)
  workerCategories.forEach(cat => {
    if (!grouped[cat]) grouped[cat] = [];
  });

  // Last resort: worker has no data at all — show everything
  if (!Object.keys(grouped).length) {
    allServices.forEach(svc => {
      const cat = svc.category || 'other';
      if (!grouped[cat]) grouped[cat] = [];
      grouped[cat].push(svc);
    });
  }

  // Render category cards
  catsEl.innerHTML = `
    <p class="svc-picker-hint">What type of service do you need?</p>
    <div class="svc-cat-cards">
      ${Object.keys(grouped).map(cat => `
        <button type="button" class="svc-cat-card" data-cat="${cat}">
          <span class="svc-cat-card__icon">${CAT_ICONS[cat] || '⚙️'}</span>
          <span class="svc-cat-card__label">${CAT_LABELS[cat] || cat}</span>
        </button>
      `).join('')}
    </div>`;

  catsEl.querySelectorAll('.svc-cat-card').forEach(btn => {
    btn.addEventListener('click', () => {
      const cat      = btn.dataset.cat;
      const catLabel = CAT_LABELS[cat] || cat;
      const subs     = grouped[cat] || [];

      // Auto-select if only general (no sub-services available)
      if (!subs.length) {
        setPickerSelection(cat, '', `General ${catLabel}`);
        return;
      }

      subsEl.hidden = false;
      subsEl.innerHTML = `
        <button type="button" class="svc-back-btn" id="svcBackBtn">
          ← Back to categories
        </button>
        <p class="svc-picker-hint">Select the specific service — or continue with <strong>General ${catLabel}</strong> if unsure.</p>
        <div class="svc-sub-options">
          <button type="button" class="svc-sub-btn svc-sub-btn--general" data-svc-id="" data-label="General ${catLabel}" data-cat="${cat}">
            <span class="svc-sub-btn__name">General ${catLabel}</span>
            <span class="svc-sub-btn__desc">I'll describe the issue in the notes</span>
          </button>
          ${subs.map(svc => {
            const id    = (svc._id || svc.id || '').toString();
            const price = svc.priceUnit === 'per_hour' ? `From ${svc.basePrice} EGP/hr`
                        : svc.priceUnit === 'per_sqm'  ? `From ${svc.basePrice} EGP/m²`
                        :                                `From ${svc.basePrice} EGP`;
            return `<button type="button" class="svc-sub-btn" data-svc-id="${id}" data-label="${svc.title}" data-cat="${cat}">
              <span class="svc-sub-btn__name">${svc.title}</span>
              <span class="svc-sub-btn__price">${price}</span>
            </button>`;
          }).join('')}
        </div>`;

      catsEl.hidden = true;
      document.getElementById('svcBackBtn')?.addEventListener('click', () => {
        subsEl.hidden = true;
        catsEl.hidden = false;
      });

      subsEl.querySelectorAll('.svc-sub-btn').forEach(subBtn => {
        subBtn.addEventListener('click', () => {
          setPickerSelection(subBtn.dataset.cat, subBtn.dataset.svcId, subBtn.dataset.label);
        });
      });

      // Pre-select if URL param matches one of these subs
      if (serviceIdParam) {
        const match = subs.find(s => (s._id || s.id || '').toString() === serviceIdParam);
        if (match) setPickerSelection(cat, serviceIdParam, match.title);
      }
    });
  });

  // Pre-select from URL param — try service ID first, then category key
  if (serviceIdParam) {
    const match = allServices.find(s => (s._id || s.id || '').toString() === serviceIdParam);
    if (match) {
      catsEl.querySelector(`[data-cat="${match.category}"]`)?.click();
    } else {
      // serviceIdParam is a category key (e.g. "plumbing") — click it directly
      catsEl.querySelector(`[data-cat="${serviceIdParam}"]`)?.click();
    }
  }
}

// ─── Address prefill ──────────────────────────────────────────────────────────

// ─── Address Management (Multiple Saved Addresses) ────────────────────────────

function renderAddresses() {
  const list = document.getElementById('savedAddressesList');
  const hiddenInput = document.getElementById('bookAddress');
  if (!list) return;

  list.innerHTML = '';
  state.addresses.forEach((addr) => {
    const isSelected = state.data.address === addr.full;
    const card = document.createElement('div');
    card.className = `address-card ${isSelected ? 'is-selected' : ''}`;
    card.innerHTML = `
      <div class="address-card__label">${addr.label || 'Saved Address'}</div>
      <div class="address-card__text">${addr.full}</div>
    `;
    card.addEventListener('click', () => {
      state.data.address = addr.full;
      if (hiddenInput) hiddenInput.value = addr.full;
      renderAddresses();
    });
    list.appendChild(card);
  });

  if (hiddenInput) hiddenInput.value = state.data.address;
}

async function prefillUserAddress() {
  try {
    const res  = await getMe();
    const user = res.user || res.data?.user || res;
    const addr = user.address;

    if (addr && addr.street) {
      const full = [addr.street, addr.city, addr.state].filter(Boolean).join(', ');
      const homeAddr = {
        id: 'home',
        label: 'Home',
        street: addr.street,
        city: addr.city,
        state: addr.state,
        full: full
      };
      
      if (!state.addresses.some(a => a.full === full)) {
        state.addresses.push(homeAddr);
      }
      
      // Default select the first one if none selected
      if (!state.data.address) {
        state.data.address = full;
      }
      renderAddresses();
    }
  } catch (e) {
    console.warn('Could not prefill address:', e);
  }
}

// ─── Address Modal Logic ──────────────────────────────────────────────────────

const addrModalOverlay = document.getElementById('addressModalOverlay');
const addrModal        = document.getElementById('addressModal');
const addrForm         = document.getElementById('addressForm');
const addNewBtn        = document.getElementById('addNewAddressBtn');

function openAddressModal() {
  if (!addrModalOverlay || !addrModal) return;
  addrModalOverlay.hidden = false;
  document.body.style.overflow = 'hidden';
  if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    animate(addrModalOverlay, { opacity: [0, 1] }, { duration: 0.25 });
    animate(addrModal, { opacity: [0, 1], y: [30, 0], scale: [0.95, 1] }, { duration: 0.35, easing: [0.22, 1, 0.36, 1] });
  }
}

function closeAddressModal() {
  if (!addrModalOverlay) return;
  addrModalOverlay.hidden = true;
  document.body.style.overflow = '';
  addrForm?.reset();
}

addNewBtn?.addEventListener('click', openAddressModal);
document.getElementById('addressModalClose')?.addEventListener('click', closeAddressModal);
document.getElementById('addressModalCancel')?.addEventListener('click', closeAddressModal);

addrForm?.addEventListener('submit', (e) => {
  e.preventDefault();
  const street = document.getElementById('newAddrStreet').value.trim();
  const city   = document.getElementById('newAddrCity').value.trim();
  const stateVal = document.getElementById('newAddrState').value.trim();
  const label  = document.getElementById('newAddrLabel').value.trim() || 'New Address';

  const full = [street, city, stateVal].filter(Boolean).join(', ');
  const newAddr = {
    id: 'new-' + Date.now(),
    label: label,
    street, city, state: stateVal,
    full
  };

  state.addresses.push(newAddr);
  state.data.address = full;

  renderAddresses();
  closeAddressModal();

  // Persist to user's saved addresses list
  addAddress({ label, street, city, state: stateVal }).then(saved => {
    if (saved?._id) {
      const card = state.addresses.find(a => a.id === newAddr.id);
      if (card) card.id = saved._id;
    }
  }).catch(() => {});
  
  // Visual feedback on the newly selected card
  setTimeout(() => {
    const cards = document.querySelectorAll('.address-card');
    const newCard = cards[cards.length - 1];
    if (newCard && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      animate(newCard, { scale: [1, 1.05, 1] }, { duration: 0.3 });
    }
  }, 100);
});

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

  try {
    const settings = await getPlatformSettings();
    state.platformSettings = {
      commissionRate: settings?.commissionRate ?? DEFAULT_PLATFORM_FEE_RATE,
      cashPaymentsEnabled: settings?.cashPaymentsEnabled !== false,
    };
  } catch (_) {
    state.platformSettings = { commissionRate: DEFAULT_PLATFORM_FEE_RATE, cashPaymentsEnabled: true };
  }
  applyPaymentSettings();
  state.worker = worker;

  // Disable cash option if worker has cash bookings blocked
  const cashOption = document.querySelector('.payment-option[data-payment="cash"]');
  if (cashOption) {
    const cashBlocked = worker?.restrictions?.cashBookingsBlocked === true;
    cashOption.classList.toggle('is-disabled', cashBlocked);
    const cashNote = cashOption.querySelector('.payment-note');
    if (cashNote) cashNote.textContent = cashBlocked
      ? (window.t?.('tech_cash_disabled') || 'Cash payments are not available for this technician.')
      : '';
    if (cashBlocked) {
      const cashInput = cashOption.querySelector('input');
      if (cashInput) cashInput.setAttribute('disabled', 'disabled');
      if (state.data.payment === 'cash') {
        state.data.payment = 'online';
        state.selectedPayment = 'online';
        document.querySelector('.payment-option[data-payment="online"]')?.classList.add('is-selected');
        cashOption.classList.remove('is-selected');
      }
    }
  }

  updateWorkerUI(worker);

  // Auto-select the nearest day the technician is available (local date, not UTC)
  const todayStr   = getLocalDateStr();
  const startDate  = findNextAvailableDate(worker.availability || [], todayStr);
  const hint = document.getElementById('dateAvailHint');
  if (hint && worker.availability?.length) {
    const days = worker.availability.map(a => DAY_ABBR[a.day] || a.day).join(', ');
    hint.textContent = `Available days: ${days}`;
  }

  const blockedDates = worker.blockedDates || [];
  initCalendar(worker.availability || [], blockedDates);

  // Pre-select the next available date
  if (startDate && bookDate) {
    bookDate.value = startDate;
    const [sy, sm] = startDate.split('-').map(Number);
    calState.year  = sy;
    calState.month = sm - 1;
    buildCalendar(worker.availability || [], blockedDates);
    renderTimeSlotsForDate(startDate, worker.availability || []);
  }

  await Promise.all([
    initServicePicker(worker),
    prefillUserAddress(),
  ]);
}

init().catch(err => console.error('Booking init error:', err));

// ─── Finalize booking ─────────────────────────────────────────────────────────

async function finalizeBooking({ returnBooking = false } = {}) {
  collectStep1();
  collectStep2();

  const paymentMethod = PAYMENT_LABELS[state.data.payment] || state.data.payment;
  const readableDate  = formatDate(state.data.date);

  // Try real API first
  let bookingId = null;
  let createdBooking = null;
  if (workerId && state.data.serviceCategory) {
    try {
      const payload = {
        workerId,
        serviceId:       state.data.serviceId || undefined,
        serviceCategory: state.data.serviceCategory,
        serviceName:     state.data.serviceType,
        scheduledDate:   state.data.date,
        scheduledTime:   state.selectedTime || '',
        address:         state.data.address,
        description:     document.getElementById('bookNotes')?.value.trim() || '',
        paymentMethod:   state.data.payment,
        savedCardId:     state.data.paymentMeta?.savedCardId || undefined,
        ...(state.data.paymentMeta ? { paymentMeta: state.data.paymentMeta } : {}),
      };
      const res = await createBooking(payload);
      createdBooking = res.data?.booking || res.data || res.booking || res;
      bookingId = createdBooking?._id || null;
      state.data.backendBooking = createdBooking;
    } catch (e) {
      const msg = e?.message || '';
      if (e?.status === 409 || msg.includes('already booked') || msg.includes('overlap')) {
        showToast('This technician already has a job during your selected time. Please pick another slot.', 'warning');
        goToStep(1);
        document.getElementById('timeslotContainer')?.scrollIntoView({ behavior: 'smooth' });
        return;
      }
      let userMsg = 'Booking failed. Please try again.';
      if      (msg.includes('not currently accepting'))  userMsg = 'This technician is not currently accepting bookings.';
      else if (msg.includes('today or in the future'))   userMsg = 'Please select a valid date.';
      else if (msg.includes('30 days in advance'))       userMsg = 'Bookings can only be made up to 30 days in advance.';
      else if (msg.includes('outside technician'))       userMsg = 'Selected time is outside this technician\'s working hours.';
      else if (msg.includes('not available on this day')) userMsg = 'This technician doesn\'t work on the selected day.';
      else if (msg.includes('time slot'))                userMsg = 'Please select a valid time slot.';
      showToast(userMsg, 'error');
      if (msg.includes('time slot') || msg.includes('outside technician') || msg.includes('not available on this day') || msg.includes('today or in the future') || msg.includes('30 days in advance')) {
        goToStep(1);
      }
      return;
    }
  }

  const bookingData = {
    _id:      bookingId || state.data.backendBooking?._id || null,
    id:       bookingId || state.data.backendBooking?._id || ('S-' + Math.floor(2900 + Math.random() * 100)),
    bookingId,
    workerId,
    workerName: state.worker?.name || '',
    service:    state.data.serviceType,
    category:   state.data.serviceType,
    payment:    state.data.payment,
    paymentMethod,
    paymentStatus: createdBooking?.paymentStatus || (state.data.payment === 'cash' ? 'cash_pending_settlement' : 'unpaid'),
    paymentMeta: createdBooking?.paymentMeta || state.data.paymentMeta || null,
    date:          readableDate,
    scheduledDate: readableDate,
    time:          state.data.time,
    scheduledTime: state.selectedTime || state.data.time,
    address:       state.data.address,
    pin:       createdBooking?.pin || state.data.backendBooking?.pin || null,
    status:    createdBooking?.status || 'pending',
    timestamp: Date.now(),
    technician: {
      name:     state.worker?.name     || '—',
      initials: (state.worker?.name || 'T').split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase(),
      specialty:(state.worker?.categories || state.worker?.skills || [])[0] || '—',
      rating:   state.worker?.averageRating != null ? Number(state.worker.averageRating).toFixed(1) : '—',
      phone:    state.worker?.phone || '',
    },
    rate:              createdBooking?.totalPrice ?? state.worker?.hourlyRate ?? state.worker?.rate ?? state.worker?.baseRate ?? null,
    totalPrice:        createdBooking?.totalPrice ?? state.worker?.hourlyRate ?? 0,
    platformFeeRate:   createdBooking?.platformFeeRate ?? state.platformSettings.commissionRate,
    platformFeeAmount: createdBooking?.platformFeeAmount,
    estimatedTotal:    createdBooking?.estimatedTotal,
    notes:             state.data.notes,
    workerLocation:    state.worker?.location || state.worker?.city || state.worker?.area || '',
    workerReviewCount: state.worker?.reviewCount || state.worker?.totalReviews || 0,
    workerAvatar:      state.worker?.avatar || state.worker?.photo || state.worker?.profileImage || null,
  };

  localStorage.setItem('servio_active_booking', JSON.stringify(bookingData));
  const existing = JSON.parse(localStorage.getItem('servio_bookings') || '[]');
  existing.push(bookingData);
  if (existing.length > 50) existing.splice(0, existing.length - 50);
  localStorage.setItem('servio_bookings', JSON.stringify(existing));

  if (returnBooking) return createdBooking || null;
  window.location.href = './booking-confirmation.html';
}

function goToConfirmationOrNext(booking, paymentMeta) {
  // Save updated booking data with hold status
  const existing = JSON.parse(localStorage.getItem('servio_active_booking') || '{}');
  const updated = Object.assign({}, existing, {
    _id:           booking._id,
    paymentStatus: booking.paymentStatus || 'held',
    paymentMeta:   paymentMeta || null,
  });
  localStorage.setItem('servio_active_booking', JSON.stringify(updated));
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

// ─── Hero Canvas Animation ───────────────────────────────────────────────────

(function initBookingHeroAnimation() {
  const canvas = document.getElementById('hero-booking-canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  let animationFrameId;
  const orbs = [];
  let mousePos = { x: -1000, y: -1000 };

  class Orb {
    constructor() {
      this.init();
    }
    init() {
      this.x = Math.random() * canvas.width;
      this.y = Math.random() * canvas.height;
      this.size = Math.random() * 300 + 150;
      this.baseSize = this.size;
      // Using brand colors: soft gold/brown tones
      this.color = Math.random() > 0.5 ? 'rgba(154, 140, 115, 0.12)' : 'rgba(219, 203, 180, 0.08)';
      this.vx = (Math.random() - 0.5) * 0.4;
      this.vy = (Math.random() - 0.5) * 0.4;
    }
    update() {
      this.x += this.vx;
      this.y += this.vy;

      // Subtle mouse interaction: orbs follow the mouse slightly
      const dx = mousePos.x - this.x;
      const dy = mousePos.y - this.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 500) {
        this.x += dx * 0.005;
        this.y += dy * 0.005;
        this.size = this.baseSize * (1 + (500 - dist) / 1000);
      } else {
        this.size += (this.baseSize - this.size) * 0.02;
      }

      // Edge wrap-around with safety margin
      if (this.x < -this.size) this.x = canvas.width + this.size;
      if (this.x > canvas.width + this.size) this.x = -this.size;
      if (this.y < -this.size) this.y = canvas.height + this.size;
      if (this.y > canvas.height + this.size) this.y = -this.size;
    }
    draw() {
      const gradient = ctx.createRadialGradient(this.x, this.y, 0, this.x, this.y, this.size);
      gradient.addColorStop(0, this.color);
      gradient.addColorStop(0.5, this.color.replace('0.', '0.0')); // Fade out faster
      gradient.addColorStop(1, 'rgba(0,0,0,0)');
      
      ctx.fillStyle = gradient;
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  const initOrbs = () => {
    orbs.length = 0;
    const count = Math.max(6, Math.floor(canvas.width / 200));
    for (let i = 0; i < count; i++) {
      orbs.push(new Orb());
    }
  };

  const animate = () => {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    
    // 'screen' mode creates a beautiful glowing overlap effect
    ctx.globalCompositeOperation = isDark ? 'screen' : 'multiply';
    if (!isDark) ctx.globalAlpha = 0.4; // Soften for light mode
    
    orbs.forEach(orb => {
      orb.update();
      orb.draw();
    });
    
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1.0;
    animationFrameId = requestAnimationFrame(animate);
  };

  window.addEventListener('mousemove', e => {
    const rect = canvas.getBoundingClientRect();
    mousePos = { x: e.clientX - rect.left, y: e.clientY - rect.top };
  });

  const resize = () => {
    const rect = canvas.parentElement.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    initOrbs();
  };

  window.addEventListener('resize', resize);
  resize();
  animate();
})();
