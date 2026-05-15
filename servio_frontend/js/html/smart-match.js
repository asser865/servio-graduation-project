import { smartMatch } from '../api/ai.js';
import { getMe, addAddress } from '../api/users.js';
import { getSession } from '../api/client.js';

const SERVICE_META = {
  Plumbing: { icon: 'droplet', category: 'plumbing', title: 'Plumbing specialist' },
  Electrical: { icon: 'bolt', category: 'electrical', title: 'Licensed electrician' },
  'A/C': { icon: 'snowflake', category: 'hvac', title: 'A/C technician' },
  Carpentry: { icon: 'hammer', category: 'carpentry', title: 'Carpentry specialist' },
  Cleaning: { icon: 'sparkle', category: 'cleaning', title: 'Cleaning professional' },
  Painting: { icon: 'brush', category: 'painting', title: 'Professional painter' },
  'Appliance Repair': { icon: 'wrench', category: 'appliance', title: 'Appliance technician' },
  Handyman: { icon: 'toolbox', category: 'handyman', title: 'General handyman' },
};

let currentLocation = null;          // Display string used for API calls and pill text
let currentLocationCity = null;      // Parsed city/district for addAddress
let _focusoutTimer = null;
let lastSmartMatchRender = null;

const SERVICE_ICONS = {
  droplet: '<path d="M12 3s6 6.4 6 11a6 6 0 0 1-12 0c0-4.6 6-11 6-11z"></path>',
  bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7l1-8z"></path>',
  snowflake: '<path d="M12 2v20M17 4l-5 5-5-5M17 20l-5-5-5 5M2 12h20M4 7l5 5-5 5M20 7l-5 5 5 5"></path>',
  hammer: '<path d="m15 12-8.5 8.5a2.1 2.1 0 0 1-3-3L12 9"></path><path d="m17.5 3.5 3 3L17 10l-3-3 3.5-3.5z"></path><path d="m13 6 5 5"></path>',
  sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8L12 3z"></path><path d="M19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8L19 16z"></path>',
  brush: '<path d="M18.4 3.6a2.1 2.1 0 0 1 3 3L11 17l-4 1 1-4L18.4 3.6z"></path><path d="M6 18c0 2-1.5 3-4 3 .8-1.1 1-2 .8-3.1C2.6 16.6 3.7 15.5 5 16c.7.3 1 1 1 2z"></path>',
  wrench: '<path d="M14.7 6.3a4 4 0 0 0-5 5L3 18v3h3l6.7-6.7a4 4 0 0 0 5-5l-2.6 2.6-2-2 2.6-2.6z"></path>',
  toolbox: '<path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path><path d="M3 7h18v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7z"></path><path d="M3 12h18"></path>',
};

const FRONTEND_GENERIC_TOKENS = new Set([
  'cairo', 'giza', 'egypt', 'city',
  'cairo governorate', 'giza governorate',
]);

function parseCityFromLocation(location) {
  if (!location) return location;
  const tokens = location
    .split(/[,/\n]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 2 && !/^\d+$/.test(s));
  const specific = tokens.filter((t) => !FRONTEND_GENERIC_TOKENS.has(t.toLowerCase()));
  const candidates = specific.length ? specific : tokens;
  return candidates[candidates.length - 1] || location;
}

async function resolveLocation() {
  // 1. User's in-session override for this page (expires on tab close)
  const sessionOverride = sessionStorage.getItem('servio_smart_match_location');
  if (sessionOverride) {
    currentLocationCity = parseCityFromLocation(sessionOverride);
    return sessionOverride;
  }

  // 2. Account address (authoritative for logged-in users)
  const token = localStorage.getItem('servio_token');
  if (token) {
    try {
      const me = await getMe();
      // If user previously saved a Smart Match address, prefer it by stored ID
      const storedId = sessionStorage.getItem('servio_smart_match_address_id');
      let addr = null;
      if (storedId && Array.isArray(me.addresses)) {
        addr = me.addresses.find((a) => String(a._id || a.id) === storedId) || null;
      }
      if (!addr) addr = me.addresses?.[0] || me.address;
      if (addr?.city) {
        const display = [addr.street, addr.state, addr.city].filter(Boolean).join(', ');
        currentLocationCity = addr.state || addr.city;
        return display;
      }
    } catch {
      // Unauthenticated or network failure — fall through
    }
  }

  // 3. Cached session data — guarded against corrupted JSON
  try {
    const session = getSession();
    const addr = session?.address;
    if (addr?.city) {
      currentLocationCity = addr.state || addr.city;
      return [addr.street, addr.state, addr.city].filter(Boolean).join(', ');
    }
  } catch {
    // Corrupted localStorage session data
  }

  return null;
}

function renderLocationPill(state, address) {
  const pin = `<svg class="location-pill__icon" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>`;

  if (state === 'loading') {
    return `<div class="location-pill location-pill--skeleton" aria-hidden="true">
      ${pin}
      <span class="location-pill__label">Loading address...</span>
    </div>`;
  }

  if (state === 'resolved') {
    return `<div class="location-pill">
      ${pin}
      <span>Using your saved address: <strong>${escapeHtml(formatLocation(address))}</strong></span>
      <button class="location-pill__change" id="location-pill-change" type="button">Change</button>
    </div>`;
  }

  if (state === 'resolved-local') {
    const isLoggedIn = !!localStorage.getItem('servio_token');
    return `<div class="location-pill">
      ${pin}
      <span>Using: <strong>${escapeHtml(formatLocation(address))}</strong></span>
      ${isLoggedIn ? `<button class="location-pill__save-account" id="location-pill-save-account" type="button">Save to account</button>` : ''}
      <button class="location-pill__change" id="location-pill-change" type="button">Change</button>
    </div>`;
  }

  if (state === 'editing') {
    return `<div class="location-pill location-pill--editing">
      ${pin}
      <input class="location-pill__input" type="text" value="${escapeAttr(address || '')}"
        placeholder="e.g. Nasr City, Cairo" aria-label="Service location" />
      <span class="location-pill__hint">Press Enter to save</span>
    </div>`;
  }

  if (state === 'save-form') {
    return `<div class="location-pill location-pill--save-form">
      ${pin}
      <div class="location-pill__save-row">
        <label class="location-pill__label-text" for="pill-city-input">City/Area</label>
        <input class="location-pill__input" id="pill-city-input" type="text"
          value="${escapeAttr(address || '')}" placeholder="e.g. Heliopolis" aria-label="City or area" />
      </div>
      <div class="location-pill__save-row">
        <button class="location-pill__save-account" id="location-pill-confirm-save" type="button">Save</button>
        <button class="location-pill__change" id="location-pill-cancel-save" type="button">Cancel</button>
      </div>
    </div>`;
  }

  // guest — no saved address
  return `<div class="location-pill location-pill--guest">
    ${pin}
    <span>Service location:</span>
    <input class="location-pill__input" type="text" placeholder="e.g. Nasr City, Cairo"
      aria-label="Service location" />
  </div>`;
}

function commitLocationEdit(wrapper, value) {
  clearTimeout(_focusoutTimer);
  _focusoutTimer = null;
  if (value) {
    sessionStorage.setItem('servio_smart_match_location', value);
    currentLocation = value;
    currentLocationCity = parseCityFromLocation(value);
    wrapper.innerHTML = renderLocationPill('resolved-local', value);
  } else if (currentLocation) {
    wrapper.innerHTML = renderLocationPill('resolved', currentLocation);
  } else {
    wrapper.innerHTML = renderLocationPill('guest', null);
  }
}

function initLocationPill(composerEl) {
  const wrapper = document.createElement('div');
  wrapper.id = 'location-pill-wrapper';
  wrapper.innerHTML = renderLocationPill('loading', null);
  composerEl.insertBefore(wrapper, composerEl.firstChild);

  // Live-sync currentLocation with input value
  wrapper.addEventListener('input', (e) => {
    if (e.target.matches('.location-pill__input:not(#pill-city-input)')) {
      currentLocation = e.target.value.trim() || null;
      currentLocationCity = parseCityFromLocation(currentLocation);
    }
  });

  // Save on Enter (editing/guest input only)
  wrapper.addEventListener('keydown', (e) => {
    if (e.target.matches('.location-pill__input:not(#pill-city-input)') && e.key === 'Enter') {
      e.preventDefault();
      commitLocationEdit(wrapper, e.target.value.trim());
    }
  });

  // Save on focus-leave
  wrapper.addEventListener('focusout', (e) => {
    if (e.target.matches('.location-pill__input:not(#pill-city-input)')) {
      _focusoutTimer = setTimeout(() => commitLocationEdit(wrapper, e.target.value.trim()), 150);
    }
  });

  wrapper.addEventListener('click', (e) => {
    if (e.target.closest('#location-pill-change')) {
      wrapper.innerHTML = renderLocationPill('editing', currentLocation);
      wrapper.querySelector('.location-pill__input')?.focus();
      return;
    }

    if (e.target.closest('#location-pill-save-account')) {
      wrapper.innerHTML = renderLocationPill('save-form', currentLocationCity || currentLocation);
      document.getElementById('pill-city-input')?.focus();
      return;
    }

    if (e.target.closest('#location-pill-confirm-save')) {
      const cityInput = document.getElementById('pill-city-input');
      const cityValue = cityInput?.value.trim();
      if (!cityValue) return;

      const btn = e.target.closest('#location-pill-confirm-save');
      btn.disabled = true;
      btn.textContent = 'Saving…';

      addAddress({ label: 'Smart Match Area', city: cityValue })
        .then((saved) => {
          const newId = String(saved?._id || saved?.id || '');
          if (newId) sessionStorage.setItem('servio_smart_match_address_id', newId);
          sessionStorage.removeItem('servio_smart_match_location');
          currentLocation = cityValue;
          currentLocationCity = cityValue;
          wrapper.innerHTML = renderLocationPill('resolved', cityValue);
        })
        .catch(() => {
          btn.disabled = false;
          btn.textContent = 'Save';
        });
      return;
    }

    if (e.target.closest('#location-pill-cancel-save')) {
      wrapper.innerHTML = renderLocationPill('resolved-local', currentLocation);
    }
  });

  return wrapper;
}

document.addEventListener('DOMContentLoaded', () => {
  const composerEl     = document.querySelector('.ai-composer');
  const textarea       = document.getElementById('ai-query-input');
  const btnSubmit      = document.getElementById('ai-match-btn');
  const processingArea = document.getElementById('ai-processing');
  const resultsArea    = document.getElementById('ai-results');
  const divider        = document.getElementById('ai-processing-divider');
  setupHeroCanvas();

  if (!composerEl || !textarea || !btnSubmit || !processingArea || !resultsArea || !divider) return;

  const pillWrapper = initLocationPill(composerEl);

  resolveLocation().then((resolved) => {
    currentLocation = resolved;
    const hadSessionOverride = !!sessionStorage.getItem('servio_smart_match_location');
    pillWrapper.innerHTML = renderLocationPill(
      resolved ? (hadSessionOverride ? 'resolved-local' : 'resolved') : 'guest',
      resolved
    );
  });

  textarea.addEventListener('input', () => {
    btnSubmit.disabled = textarea.value.trim().length === 0;
  });

  resultsArea.addEventListener('click', (event) => {
    if (event.target.closest('#change-smart-location')) {
      const pillWrapper = document.getElementById('location-pill-wrapper');
      if (pillWrapper) {
        pillWrapper.innerHTML = renderLocationPill('editing', currentLocation);
        const input = pillWrapper.querySelector('.location-pill__input');
        if (input) {
          input.focus();
          pillWrapper.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }
      return;
    }

    const stageBtn = event.target.closest('[data-go]');
    if (stageBtn) {
      const target = stageBtn.getAttribute('data-go');
      switchBentoStage(resultsArea, target);
      return;
    }

    const safetyMore = event.target.closest('.bento-safety-bar__more');
    if (safetyMore) {
      const panel = safetyMore.parentElement.querySelector('.bento-safety-more');
      const open = panel?.classList.toggle('is-open');
      safetyMore.setAttribute('aria-expanded', open ? 'true' : 'false');
      safetyMore.textContent = open ? 'Hide ▴' : 'How? ▾';
      return;
    }

    const serviceCard = event.target.closest('[data-select-service]');
    if (serviceCard && lastSmartMatchRender) {
      const selectedService = serviceCard.getAttribute('data-select-service');
      renderSmartMatch(
        lastSmartMatchRender.data,
        lastSmartMatchRender.resultsArea,
        lastSmartMatchRender.prompt,
        selectedService
      );
      const stage1Cta = resultsArea.querySelector('.bento-stage__nav-end');
      stage1Cta?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      return;
    }

    const button = event.target.closest('[data-fill-example]');
    if (!button) return;
    textarea.value = button.getAttribute('data-fill-example') || '';
    btnSubmit.disabled = textarea.value.trim().length === 0;
    textarea.focus();
  });

  resultsArea.addEventListener('keydown', (event) => {
    const card = event.target.closest('.bento-plan-card[data-select-service]');
    if (!card) return;
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      card.click();
    }
  });

  btnSubmit.addEventListener('click', async () => {
    const prompt = textarea.value.trim();
    if (!prompt) return;

    resetState({ textarea, btnSubmit, processingArea, resultsArea, divider });

    try {
      await showProcessingSteps(processingArea, [
        'Reading the request...',
        'Separating service, location, budget, and time...',
        'Checking whether this is single, vague, multi-service, or unrecognized...',
      ]);

      const data = await smartMatch({ prompt, location: currentLocation || undefined });

      await generateProcessingLog(
        processingArea,
        data.scenario === 'multi'
          ? 'Multiple services found.'
          : data.scenario === 'vague'
            ? 'More detail is needed before matching.'
            : data.scenario === 'unrecognized'
              ? 'No clear home service found.'
              : 'Ready to recommend technicians.',
        true
      );

      renderSmartMatch(data, resultsArea, prompt);
    } catch (err) {
      console.error('Smart Match Error:', err);
      renderError(resultsArea, err);
    } finally {
      processingArea.hidden = true;
      divider.hidden = true;
      textarea.disabled = false;
      btnSubmit.disabled = false;
      resultsArea.hidden = false;
      resultsArea.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});

function resetState({ textarea, btnSubmit, processingArea, resultsArea, divider }) {
  lastSmartMatchRender = null;
  processingArea.innerHTML = '';
  processingArea.hidden = false;
  divider.hidden = false;
  resultsArea.hidden = true;
  resultsArea.innerHTML = '';
  btnSubmit.disabled = true;
  textarea.disabled = true;
}

async function showProcessingSteps(processingArea, steps) {
  for (let i = 0; i < steps.length; i++) {
    await generateProcessingLog(processingArea, steps[i], false);
  }
}

function renderSmartMatch(data, resultsArea, prompt, selectedServiceOverride = null) {
  const scenario = data.scenario || 'vague';
  lastSmartMatchRender = { data, resultsArea, prompt };

  if (scenario === 'unrecognized') {
    resultsArea.innerHTML = renderStateCard({
      tone: 'warning',
      eyebrow: 'Servio diagnostic',
      title: 'Tell us about a home issue',
      message: data.follow_up_message || data.advisor_message || 'Describe the home issue so Servio can match the right service.',
      examples: defaultExamples(),
    });
    return;
  }

  if (scenario === 'vague') {
    resultsArea.innerHTML = renderStateCard({
      tone: 'info',
      eyebrow: 'Servio diagnostic',
      title: 'A few more details, please',
      message: data.follow_up_message || 'Add the missing details below to continue.',
      chips: data.missing_field_labels || [],
      examples: defaultExamples(),
    });
    return;
  }

  const steps = normalizeSteps(data);
  const extracted = data.extracted || {};
  const effectiveExtracted = {
    ...extracted,
    location: extracted.location || data.effectiveLocation || null,
  };
  const matches = normalizeMatches(data.matches);
  const defaultService = data.selected_service || data.recommended_service || steps[0]?.service;
  const service = selectedServiceOverride || defaultService;
  const selectedMatches = service ? filterMatchesForService(matches, service) : matches;
  const isMulti = scenario === 'multi';
  const confidence = Number(data.confidence || 0);

  resultsArea.innerHTML = `
    ${renderBentoHero(data, confidence, scenario, steps, effectiveExtracted)}
    ${renderBentoStageNav()}
    <section class="bento-stage is-active" data-bstage="1" aria-label="Diagnostic plan">
      ${data.safety_risk ? renderBentoSafetyBar(data) : ''}
      ${renderBentoPlanSection(data, steps, service, isMulti)}
      ${renderBentoInsightStrip(data, effectiveExtracted, selectedMatches)}
      ${renderBentoAdvisoryMissing(data, effectiveExtracted)}
      ${renderBentoStage1Cta(service, selectedMatches.length)}
    </section>
    <section class="bento-stage" data-bstage="2" aria-label="Choose technician">
      ${renderBentoTechHeader(service, effectiveExtracted, selectedMatches.length)}
      ${selectedMatches.length
        ? renderBentoTechHero(selectedMatches[0], service) + renderBentoTechAlternatives(selectedMatches.slice(1), service)
        : renderNoTechsState(effectiveExtracted, service)}
      ${renderBentoStageBack()}
    </section>
  `;
}

function switchBentoStage(resultsArea, target) {
  const stages = resultsArea.querySelectorAll('.bento-stage');
  const navItems = resultsArea.querySelectorAll('.bento-nav__item');
  stages.forEach((s) => s.classList.toggle('is-active', s.getAttribute('data-bstage') === target));
  navItems.forEach((n) => {
    const t = n.getAttribute('data-go');
    n.classList.toggle('is-active', t === target);
    n.classList.toggle('is-done', Number(t) < Number(target));
  });
  const active = resultsArea.querySelector(`.bento-stage[data-bstage="${target}"]`);
  active?.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function formatLocation(value) {
  return String(value ?? '')
    .split(',')
    .map((part) => part.trim().replace(/\b[a-z]/g, (char) => char.toUpperCase()))
    .filter(Boolean)
    .join(', ');
}

function defaultExamples() {
  return [
    { label: 'Plumbing example', prompt: 'My sink is leaking in Maadi, budget 300 EGP, today' },
    { label: 'Electrical example', prompt: 'The lights keep flickering in Nasr City, budget 250 EGP, tomorrow' },
    { label: 'A/C example', prompt: 'AC not cooling in Heliopolis, budget 500 EGP, this weekend' },
  ];
}

function renderStateCard({ tone, eyebrow, title, message, chips = [], examples = [] }) {
  return `
    <article class="bento-state bento-state--${escapeAttr(tone)}">
      ${eyebrow ? `<span class="bento-state__eyebrow">${escapeHtml(eyebrow)}</span>` : ''}
      <h2 class="bento-state__title">${escapeHtml(title)}</h2>
      <p class="bento-state__message">${escapeHtml(message)}</p>
      ${chips.length ? `
        <div class="bento-state__chips">
          ${chips.map((c) => `<span class="bento-state__chip">${escapeHtml(c)}</span>`).join('')}
        </div>` : ''}
      ${examples.length ? `
        <div class="bento-state__examples">
          <span class="bento-state__hint">Try one of these:</span>
          <div class="bento-state__example-row">
            ${examples.map((ex) => `<button type="button" class="bento-state__example" data-fill-example="${escapeAttr(ex.prompt)}">${escapeHtml(ex.label)}</button>`).join('')}
          </div>
        </div>` : ''}
    </article>
  `;
}

function renderBentoHero(data, confidence, scenario, steps, extracted) {
  const conf = Math.max(0, Math.min(100, Math.round(confidence)));
  const headline = scenario === 'multi'
    ? `${steps.length} services identified`
    : steps[0]?.service ? `${steps[0].service} service identified` : 'Service identified';
  const subline = scenario === 'multi'
    ? 'Two issues — we ordered them for safety. Pick your priority below.'
    : 'We matched your request to the right home service.';

  const chipBits = [];
  if (extracted.location) chipBits.push(`<span class="bento-hero__chip">📍 ${escapeHtml(formatLocation(extracted.location))}</span>`);
  if (extracted.budget) chipBits.push(`<span class="bento-hero__chip">💰 ${escapeHtml(String(extracted.budget))}</span>`);
  if (extracted.time_range || extracted.time) chipBits.push(`<span class="bento-hero__chip">🕐 ${escapeHtml(String(extracted.time_range || extracted.time))}</span>`);

  const circ = 2 * Math.PI * 28;
  const offset = circ - (circ * conf) / 100;

  return `
    <section class="bento-hero" aria-label="Diagnostic summary">
      <div class="bento-hero__ring" aria-hidden="true">
        <svg viewBox="0 0 64 64" width="64" height="64">
          <circle class="bento-hero__ring-track" cx="32" cy="32" r="28"></circle>
          <circle class="bento-hero__ring-fill" cx="32" cy="32" r="28"
            stroke-dasharray="${circ.toFixed(2)}" stroke-dashoffset="${offset.toFixed(2)}"></circle>
        </svg>
        <span class="bento-hero__ring-label">${conf}%</span>
      </div>
      <div class="bento-hero__body">
        <span class="bento-hero__eyebrow">Diagnostic · confidence</span>
        <h2 class="bento-hero__headline">${escapeHtml(headline)}</h2>
        <p class="bento-hero__subline">${escapeHtml(subline)}</p>
        ${chipBits.length ? `<div class="bento-hero__chips">${chipBits.join('')}</div>` : ''}
      </div>
      <div class="bento-hero__actions">
        <button type="button" class="bento-hero__pill" id="change-smart-location">Change location</button>
      </div>
    </section>
  `;
}

function renderBentoStageNav() {
  return `
    <nav class="bento-nav" aria-label="Diagnostic stages">
      <button type="button" class="bento-nav__item is-active" data-go="1">
        <span class="bento-nav__num">01</span>
        <span class="bento-nav__label">Your plan</span>
      </button>
      <button type="button" class="bento-nav__item" data-go="2">
        <span class="bento-nav__num">02</span>
        <span class="bento-nav__label">Choose technician</span>
      </button>
    </nav>
  `;
}

function renderBentoSafetyBar(data) {
  const warning = data.safety_warning || {};
  const briefMsg = warning.message || data.advisor_message || 'Safety risk detected. Cut the breaker for the affected area before any repair work.';
  const steps = Array.isArray(warning.steps) && warning.steps.length ? warning.steps : defaultSafetySteps();
  return `
    <section class="bento-safety-bar" role="alert">
      <div class="bento-safety-bar__rail" aria-hidden="true"></div>
      <div class="bento-safety-bar__icon" aria-hidden="true">${renderAlertIcon()}</div>
      <div class="bento-safety-bar__text">
        <strong class="bento-safety-bar__title">Safety first</strong>
        <span class="bento-safety-bar__msg">${escapeHtml(briefMsg)}</span>
      </div>
      <button type="button" class="bento-safety-bar__more" aria-expanded="false">How? ▾</button>
      <ol class="bento-safety-more">
        ${steps.map((s, i) => `
          <li class="bento-safety-more__step">
            <span class="bento-safety-more__num">${i + 1}</span>
            <span class="bento-safety-more__text">${escapeHtml(s)}</span>
          </li>`).join('')}
      </ol>
    </section>
  `;
}

function defaultSafetySteps() {
  return [
    'Find your electrical panel and switch off the breaker for the affected room.',
    'Keep the area dry and avoid touching wet electrical fixtures or wiring.',
    'Do not restore power until the licensed electrician confirms it is safe.',
  ];
}

function renderBentoPlanSection(data, steps, selectedService, isMulti) {
  const title = isMulti
    ? (data.safety_risk ? 'Two issues — ordered for safety' : 'Two issues — pick your priority')
    : 'One service, one technician';
  return `
    <section class="bento-section" aria-label="Service plan">
      <header class="bento-section__head">
        <span class="bento-section__numeral">01</span>
        <div>
          <p class="bento-section__kicker">Your plan</p>
          <h3 class="bento-section__title">${escapeHtml(title)}</h3>
        </div>
      </header>
      <div class="bento-plan-grid${isMulti ? ' bento-plan-grid--multi' : ''}">
        ${steps.map((step, i) => renderBentoPlanCard(step, selectedService, i, steps.length)).join('')}
      </div>
    </section>
  `;
}

function renderBentoPlanCard(step, selectedService, idx, total) {
  const meta = SERVICE_META[step.service] || { icon: 'toolbox', title: 'Home service' };
  const isSelected = selectedService === step.service;
  const isFeature = idx === 0;
  const urgency = (step.urgency || 'low').toLowerCase();
  const urgencyLabel = step.urgency_label || (urgency === 'urgent' ? 'Urgent' : urgency === 'same_day' ? 'Same day' : 'Flexible');

  return `
    <article class="bento-plan-card bento-plan-card--${isFeature ? 'feature' : 'light'} ${isSelected ? 'is-selected' : ''}"
      data-select-service="${escapeAttr(step.service || '')}"
      role="button" tabindex="0" aria-pressed="${isSelected ? 'true' : 'false'}">
      <header class="bento-plan-card__head">
        <span class="bento-plan-card__step">Step ${idx + 1}${total > 1 ? ` of ${total}` : ''}</span>
        <span class="bento-plan-card__urgency bento-plan-card__urgency--${escapeAttr(urgency)}">${escapeHtml(urgencyLabel)}</span>
      </header>
      <div class="bento-plan-card__icon" aria-hidden="true">${renderServiceIcon(meta.icon)}</div>
      <h4 class="bento-plan-card__service">${escapeHtml(step.service || 'Home service')}</h4>
      <p class="bento-plan-card__reason">${escapeHtml(step.reason || serviceReason(step.service, step.urgency))}</p>
      <div class="bento-plan-card__footer">
        <span class="bento-plan-card__pick">${isSelected ? '✓ Selected' : 'Tap to select'}</span>
      </div>
    </article>
  `;
}

function renderBentoInsightStrip(data, extracted, selectedMatches) {
  const earliest = selectedMatches[0]?.isAvailable === false ? 'Within 24 hours' : 'Today';
  const budgetFit = extracted.budget ? `Within your ${escapeHtml(String(extracted.budget))} budget` : 'Quote on site';
  const area = extracted.location
    ? `${selectedMatches.length} verified in ${escapeHtml(formatLocation(extracted.location))}`
    : `${selectedMatches.length} verified nearby`;

  return `
    <section class="bento-insight-strip" aria-label="Quick insights">
      <div class="bento-istrip__col">
        <span class="bento-istrip__label">Earliest arrival</span>
        <strong class="bento-istrip__value">${escapeHtml(earliest)}</strong>
      </div>
      <span class="bento-istrip__sep" aria-hidden="true"></span>
      <div class="bento-istrip__col">
        <span class="bento-istrip__label">Budget fit</span>
        <strong class="bento-istrip__value">${budgetFit}</strong>
      </div>
      <span class="bento-istrip__sep" aria-hidden="true"></span>
      <div class="bento-istrip__col">
        <span class="bento-istrip__label">In your area</span>
        <strong class="bento-istrip__value">${area}</strong>
      </div>
    </section>
  `;
}

function renderBentoAdvisoryMissing(data, extracted) {
  const advisory = data.advisory_missing_fields || [];
  if (!advisory.length) return '';
  const chips = [];
  if (advisory.includes('location') && !extracted.location) chips.push('📍 Add location for closer matches');
  if (advisory.includes('budget')) chips.push('💰 Budget: technician will quote on site');
  if (advisory.includes('time_range')) chips.push('🕐 Time: flexible — confirm with technician');
  if (!chips.length) return '';
  return `
    <aside class="bento-advisory" aria-label="Optional details">
      <span class="bento-advisory__eyebrow">Optional — helps find closer matches</span>
      <div class="bento-advisory__chips">
        ${chips.map((c) => `<span class="bento-advisory__chip">${escapeHtml(c)}</span>`).join('')}
      </div>
    </aside>
  `;
}

function renderBentoStage1Cta(service, count) {
  const label = count
    ? `See ${count} ${service} ${count === 1 ? 'technician' : 'technicians'} →`
    : `See ${service || 'available'} technicians →`;
  return `
    <div class="bento-stage__nav-end">
      <button type="button" class="bento-stage__cta" data-go="2">${escapeHtml(label)}</button>
    </div>
  `;
}

function renderBentoTechHeader(service, extracted, count) {
  const loc = extracted.location ? formatLocation(extracted.location) : '';
  const sub = service && loc ? `Top ${service} match · ${escapeHtml(loc)}` : service ? `Top ${service} match` : 'Top match';
  return `
    <header class="bento-tech-head">
      <span class="bento-tech-head__eyebrow">${sub}</span>
      <h3 class="bento-tech-head__title">${escapeHtml(count ? 'Your best technician' : 'No matches available')}</h3>
      ${count > 1 ? `<a class="bento-tech-head__alt-link" href="#bento-alts">See ${count - 1} alternative${count - 1 === 1 ? '' : 's'} ↓</a>` : ''}
    </header>
  `;
}

function renderBentoTechHero(worker, selectedService) {
  if (!worker) return '';
  const rating = Number(worker.averageRating || worker.rating || 0);
  const reviews = Number(worker.totalReviews || 0);
  const onTime = rating ? `${Math.min(99, Math.round(85 + rating))}%` : 'New';
  const reBook = rating ? `${Math.min(99, Math.round(60 + (rating * 6)))}%` : '—';
  const langs = Array.isArray(worker.languages) && worker.languages.length
    ? worker.languages.slice(0, 2).join(' · ')
    : 'EN · AR';
  const service = selectedService || serviceLabelFromWorker(worker);
  const profileHref = worker._id ? `./technician-profile.html?id=${encodeURIComponent(worker._id)}` : './technician-profile.html';
  const bookHref = worker._id
    ? `./booking.html?worker=${encodeURIComponent(worker._id)}&service=${encodeURIComponent(serviceCategoryForService(service) || service)}`
    : profileHref;

  return `
    <article class="bento-tech-hero">
      <div class="bento-tech-hero__photo">
        <img src="${escapeAttr(worker.profileImage || worker.avatar || avatarFor(worker.name))}" alt="${escapeAttr(worker.name || 'Technician')}" onerror="this.onerror=null;this.src='${escapeAttr(avatarFor(worker.name))}'" />
        ${worker.isAvailable === false ? '' : '<span class="bento-tech-hero__dot" aria-label="Online now"></span>'}
      </div>
      <div class="bento-tech-hero__body">
        <div class="bento-tech-hero__id">
          <h4 class="bento-tech-hero__name">${escapeHtml(worker.name || 'Technician')}</h4>
          ${worker.isVerified !== false ? '<span class="bento-tech-hero__badge">✓ Verified</span>' : ''}
        </div>
        <p class="bento-tech-hero__title">${escapeHtml(worker.title || `${service} specialist`)} · ${escapeHtml(formatLocation(worker.locationLabel || worker.area || 'Cairo'))}</p>
        <dl class="bento-tech-hero__stats">
          <div><dt>Rating</dt><dd>${rating.toFixed(1)} ★ ${reviews ? `(${reviews})` : ''}</dd></div>
          <div><dt>On-time</dt><dd>${onTime}</dd></div>
          <div><dt>Re-book</dt><dd>${reBook}</dd></div>
          <div><dt>Languages</dt><dd>${escapeHtml(langs)}</dd></div>
        </dl>
        <div class="bento-tech-hero__actions">
          <a class="btn btn--full bento-tech-hero__book" href="${bookHref}">Book ${escapeHtml(service)} · ${escapeHtml(rateLabel(worker))}</a>
          <a class="bento-tech-hero__profile" href="${profileHref}">View full profile</a>
        </div>
      </div>
    </article>
  `;
}

function renderBentoTechAlternatives(workers, selectedService) {
  if (!workers || !workers.length) return '';
  return `
    <section class="bento-alt" id="bento-alts" aria-label="Alternative technicians">
      <header class="bento-alt__head">
        <span class="bento-alt__eyebrow">Alternatives</span>
        <h4 class="bento-alt__title">${workers.length} other ${selectedService || ''} ${workers.length === 1 ? 'technician' : 'technicians'} nearby</h4>
      </header>
      <ul class="bento-alt__list">
        ${workers.map((w) => renderBentoAltRow(w, selectedService)).join('')}
      </ul>
    </section>
  `;
}

function renderBentoAltRow(worker, selectedService) {
  const rating = Number(worker.averageRating || worker.rating || 0);
  const service = selectedService || serviceLabelFromWorker(worker);
  const profileHref = worker._id ? `./technician-profile.html?id=${encodeURIComponent(worker._id)}` : './technician-profile.html';
  const bookHref = worker._id
    ? `./booking.html?worker=${encodeURIComponent(worker._id)}&service=${encodeURIComponent(serviceCategoryForService(service) || service)}`
    : profileHref;

  return `
    <li class="bento-alt__row">
      <img class="bento-alt__photo" src="${escapeAttr(worker.profileImage || worker.avatar || avatarFor(worker.name))}" alt="${escapeAttr(worker.name || 'Technician')}" onerror="this.onerror=null;this.src='${escapeAttr(avatarFor(worker.name))}'" />
      <div class="bento-alt__body">
        <div class="bento-alt__id">
          <strong>${escapeHtml(worker.name || 'Technician')}</strong>
          ${worker.isVerified !== false ? '<span class="bento-alt__badge">✓</span>' : ''}
        </div>
        <span class="bento-alt__meta">${escapeHtml(formatLocation(worker.locationLabel || worker.area || 'Cairo'))} · ${escapeHtml(rateLabel(worker))}</span>
      </div>
      <span class="bento-alt__rating">${rating.toFixed(1)} ★</span>
      <a class="bento-alt__book" href="${bookHref}">Book</a>
    </li>
  `;
}

function renderBentoStageBack() {
  return `
    <div class="bento-stage__nav-back">
      <button type="button" class="bento-stage__back" data-go="1">← Back to plan</button>
    </div>
  `;
}

function renderNoTechsState(extracted, selectedService) {
  const loc = extracted?.location ? formatLocation(extracted.location) : null;
  const serviceText = selectedService ? `${selectedService} ` : '';
  return `
    <article class="bento-state bento-state--warning">
      <h3 class="bento-state__title">No available technicians found</h3>
      <p class="bento-state__message">No verified ${escapeHtml(serviceText)}technicians are available${loc ? ` near <strong>${escapeHtml(loc)}</strong>` : ' in this area'} right now. Try a different location or browse all services.</p>
      <div class="bento-state__example-row">
        <button type="button" class="bento-state__example" id="change-smart-location">Change location</button>
        <a href="./services-marketplace.html" class="bento-state__example">Browse all services</a>
      </div>
    </article>
  `;
}

function serviceLabelFromWorker(worker) {
  const firstCategory = Array.isArray(worker.categories) ? worker.categories[0] : null;
  return formatServiceTag(firstCategory || worker.title || 'Home service');
}

function formatServiceTag(tag) {
  const labels = {
    plumbing: 'Plumbing',
    electrical: 'Electrical',
    hvac: 'A/C',
    carpentry: 'Carpentry',
    cleaning: 'Cleaning',
    painting: 'Painting',
    appliance: 'Appliance Repair',
    handyman: 'Handyman',
  };
  return labels[String(tag || '').toLowerCase()] || String(tag || 'Home service');
}

function normalizeSteps(data) {
  if (Array.isArray(data.steps) && data.steps.length) return data.steps;
  const service = data.recommended_service || data.selected_service;
  return service ? [{ step: 1, service, urgency: 'urgent', urgency_label: 'Book First' }] : [];
}

function serviceCategoryForService(service) {
  return SERVICE_META[service]?.category || null;
}

function filterMatchesForService(matches, service) {
  const category = serviceCategoryForService(service);
  if (!category) return matches;
  return matches.filter((worker) => {
    const categories = Array.isArray(worker.categories) ? worker.categories : [];
    return categories.map((item) => String(item).toLowerCase()).includes(category);
  });
}

function serviceReason(service, urgency) {
  if (service === 'Electrical') return 'Inspect the wet electrical hardware and secure the circuit.';
  if (service === 'Plumbing') return 'Stop the leak and prevent more water damage.';
  if (service === 'Painting') return 'Repair paint and finish after the wall dries.';
  if (urgency === 'urgent') return 'This should be handled before other follow-up work.';
  return SERVICE_META[service]?.title || 'Home service support is needed.';
}

function renderServiceIcon(name) {
  const path = SERVICE_ICONS[name] || SERVICE_ICONS.toolbox;
  return `<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${path}</svg>`;
}

function renderAlertIcon() {
  return '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"></path><path d="M12 9v4"></path><path d="M12 17h.01"></path></svg>';
}

function normalizeMatches(apiMatches) {
  if (Array.isArray(apiMatches) && apiMatches.length) return apiMatches;
  return [];
}

function renderError(resultsArea, err) {
  resultsArea.innerHTML = `
    <div class="ai-results__header">
      <h2 class="ai-results__title">Smart Match is unavailable</h2>
      <span class="ai-results__badge ai-results__badge--unrecognized">Check services</span>
    </div>
    <article class="smart-state smart-state--warning">
      <h3>Could not reach the AI service</h3>
      <p>${escapeHtml(err?.message || 'Start the backend API and the Python AI recommender, then try again.')}</p>
    </article>
  `;
}

function rateLabel(worker) {
  if (worker.flatRate) return worker.flatRate;
  const rate = Number(worker.hourlyRate || worker.price || 0);
  return rate ? `From ${rate} EGP/hr` : 'Quote after diagnosis';
}

function avatarFor(name = 'Technician') {
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=3c2415&color=fff&size=128`;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, '&#096;');
}

function generateProcessingLog(processingArea, text, isFinal) {
  return new Promise((resolve) => {
    let pill = processingArea.querySelector('.ai-processing__pill');
    if (!pill) {
      pill = document.createElement('div');
      pill.className = 'ai-processing__pill';
      processingArea.appendChild(pill);
    }
    if (isFinal) {
      pill.innerHTML = `<span class="ai-processing__check">✓</span><span class="ai-processing__pill-text">${text}</span>`;
      pill.classList.add('is-final');
    } else {
      pill.innerHTML = `<span class="ai-processing__pill-spinner"></span><span class="ai-processing__pill-text">${text}</span>`;
      pill.classList.remove('is-final');
    }
    setTimeout(resolve, isFinal ? 300 : 500);
  });
}

function setupHeroCanvas() {
  const canvas = document.getElementById('hero-ai-canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  const points = [];
  const gridSize = 45;
  let mousePos = { x: undefined, y: undefined };

  class Point {
    constructor(x, y) {
      this.x = x;
      this.y = y;
      this.originX = x;
      this.originY = y;
      this.z = 0;
    }

    update() {
      if (mousePos.x === undefined) {
        this.x += (this.originX - this.x) * 0.05;
        this.y += (this.originY - this.y) * 0.05;
        this.z += (0 - this.z) * 0.05;
        return;
      }

      const dx = this.x - mousePos.x;
      const dy = this.y - mousePos.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const maxDist = 200;

      if (dist < maxDist) {
        const angle = Math.atan2(dy, dx);
        const force = (maxDist - dist) / maxDist;
        this.x += Math.cos(angle) * force * 5;
        this.y += Math.sin(angle) * force * 5;
        this.z = force * 20;
      }

      this.x += (this.originX - this.x) * 0.05;
      this.y += (this.originY - this.y) * 0.05;
      this.z += (0 - this.z) * 0.05;
    }
  }

  const initCanvas = () => {
    points.length = 0;
    const cols = Math.ceil(canvas.width / gridSize);
    const rows = Math.ceil(canvas.height / gridSize);
    for (let i = 0; i <= cols; i++) {
      for (let j = 0; j <= rows; j++) {
        points.push(new Point(i * gridSize, j * gridSize));
      }
    }
  };

  const animateCanvas = () => {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const cols = Math.ceil(canvas.width / gridSize);
    const rows = Math.ceil(canvas.height / gridSize);

    points.forEach((p) => p.update());

    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);

    if (isDark) {
      gradient.addColorStop(0, 'rgba(219, 203, 180, 0.25)');
      gradient.addColorStop(1, 'rgba(100, 100, 100, 0.1)');
    } else {
      gradient.addColorStop(0, 'rgba(30, 27, 75, 0.25)');
      gradient.addColorStop(1, 'rgba(154, 140, 115, 0.45)');
    }
    ctx.strokeStyle = gradient;

    for (let i = 0; i < cols; i++) {
      for (let j = 0; j < rows; j++) {
        const p1 = points[i * (rows + 1) + j];
        const p2 = points[i * (rows + 1) + (j + 1)];
        const p3 = points[(i + 1) * (rows + 1) + j];

        if (p1 && p2) {
          ctx.beginPath();
          ctx.moveTo(p1.x, p1.y);
          ctx.lineTo(p2.x, p2.y);
          ctx.lineWidth = (isDark ? 1 : 1.2) + p1.z / 12;
          ctx.stroke();
        }

        if (p1 && p3) {
          ctx.beginPath();
          ctx.moveTo(p1.x, p1.y);
          ctx.lineTo(p3.x, p3.y);
          ctx.lineWidth = (isDark ? 1 : 1.2) + p1.z / 12;
          ctx.stroke();
        }
      }
    }
    requestAnimationFrame(animateCanvas);
  };

  const resizeCanvas = () => {
    const rect = canvas.parentElement.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    initCanvas();
  };

  canvas.parentElement.addEventListener('mousemove', (e) => {
    const rect = canvas.getBoundingClientRect();
    mousePos = { x: e.clientX - rect.left, y: e.clientY - rect.top };
  });

  canvas.parentElement.addEventListener('mouseleave', () => {
    mousePos = { x: undefined, y: undefined };
  });

  window.addEventListener('resize', resizeCanvas);
  resizeCanvas();
  animateCanvas();
}
