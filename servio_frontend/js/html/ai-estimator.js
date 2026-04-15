/**
 * ai-estimator.js
 * 4-step wizard: Room Type → Dimensions → Finishing Level → Results
 */

import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/motion@12.38.0/+esm';

const t = (key, vars) => window.t ? window.t(key, vars) : key;

// ── Rate tables (USD per sqm of floor area) ───────────────────────────────────
const RATES = {
  economy:  { labor: 12,  materials: 8,  logistics: 5,  variance: 0.08 },
  standard: { labor: 28,  materials: 18, logistics: 9,  variance: 0.10 },
  premium:  { labor: 55,  materials: 38, logistics: 17, variance: 0.12 },
};

// Room multipliers (applied on top of base rates)
const ROOM_MULTIPLIERS = {
  'living-room': 1.0,
  'bedroom':     0.92,
  'kitchen':     1.35,
  'bathroom':    1.55,
  'office':      0.95,
  'balcony':     1.20,
};

const ROOM_LABELS = {
  'living-room': t('est_room_living'),
  'bedroom':     t('est_room_bedroom'),
  'kitchen':     t('est_room_kitchen'),
  'bathroom':    t('est_room_bathroom'),
  'office':      t('est_room_office'),
  'balcony':     t('est_room_balcony'),
};

const LEVEL_LABELS = {
  economy:  t('est_finish_economy'),
  standard: t('est_finish_standard'),
  premium:  t('est_finish_premium'),
};

// ── State ─────────────────────────────────────────────────────────────────────
const state = {
  step:        1,
  roomType:    null,
  unit:        'm',      // 'm' | 'ft'
  length:      null,
  width:       null,
  height:      null,
  floorArea:   null,     // sqm
  wallArea:    null,     // sqm
  level:       null,
};

// ── DOM refs ──────────────────────────────────────────────────────────────────
const panels     = document.querySelectorAll('.wizard-panel');
const steps      = document.querySelectorAll('.wizard-step');
const connectors = document.querySelectorAll('.wizard-step__connector');

const step1Next  = document.getElementById('step1-next');
const step2Back  = document.getElementById('step2-back');
const step2Next  = document.getElementById('step2-next');
const step3Back  = document.getElementById('step3-back');
const step3Next  = document.getElementById('step3-next');
const restartBtn = document.getElementById('restart-btn');

const dimLength  = document.getElementById('dim-length');
const dimWidth   = document.getElementById('dim-width');
const dimHeight  = document.getElementById('dim-height');
const areaPreview      = document.getElementById('area-preview');
const floorAreaDisplay = document.getElementById('floor-area-display');
const wallAreaDisplay  = document.getElementById('wall-area-display');

const unitLabelL = document.getElementById('unit-label-l');
const unitLabelW = document.getElementById('unit-label-w');
const unitLabelH = document.getElementById('unit-label-h');

// ── Helpers ───────────────────────────────────────────────────────────────────
function ftToM(v) { return v * 0.3048; }

function getMetricDims() {
  const conv = state.unit === 'ft' ? ftToM : v => v;
  return {
    l: conv(parseFloat(dimLength.value) || 0),
    w: conv(parseFloat(dimWidth.value)  || 0),
    h: conv(parseFloat(dimHeight.value) || 0),
  };
}

function fmt(n) {
  return n.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

function fmtArea(sqm) {
  if (state.unit === 'ft') {
    return `${fmt(sqm / 0.0929)} ft²`;
  }
  return `${sqm.toFixed(1)} m²`;
}

// ── Step navigation ───────────────────────────────────────────────────────────
function goTo(newStep) {
  const oldStep = state.step;
  state.step = newStep;

  panels.forEach(p => {
    const idx = parseInt(p.dataset.panel, 10);
    if (idx === newStep) {
      p.hidden = false;
      animate(p, { opacity: [0, 1], y: [16, 0] }, { duration: 0.35, easing: 'ease-out' });
    } else {
      p.hidden = true;
    }
  });

  steps.forEach((s, i) => {
    const n = parseInt(s.dataset.step, 10);
    s.classList.toggle('wizard-step--active', n === newStep);
    s.classList.toggle('wizard-step--done',   n < newStep);
  });

  connectors.forEach((c, i) => {
    c.classList.toggle('wizard-step__connector--done', i < newStep - 1);
  });

  if (newStep === 4) startCalculation();
}

// ── Step 1: Room type ─────────────────────────────────────────────────────────
document.querySelectorAll('.room-type-card').forEach(card => {
  card.addEventListener('click', () => {
    document.querySelectorAll('.room-type-card').forEach(c => c.classList.remove('is-selected'));
    card.classList.add('is-selected');
    state.roomType = card.dataset.room;
    step1Next.disabled = false;
    animate(card, { scale: [0.97, 1] }, { duration: 0.2, easing: 'ease-out' });
  });
});

step1Next.addEventListener('click', () => {
  if (!state.roomType) return;
  goTo(2);
});

// ── Step 2: Unit toggle & dimensions ─────────────────────────────────────────
document.querySelectorAll('.unit-toggle__btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.unit-toggle__btn').forEach(b => b.classList.remove('unit-toggle__btn--active'));
    btn.classList.add('unit-toggle__btn--active');
    state.unit = btn.dataset.unit;
    const label = state.unit === 'ft' ? 'ft' : 'm';
    unitLabelL.textContent = label;
    unitLabelW.textContent = label;
    unitLabelH.textContent = label;
    updateAreaPreview();
  });
});

function updateAreaPreview() {
  const { l, w, h } = getMetricDims();
  if (l > 0 && w > 0 && h > 0) {
    state.floorArea = +(l * w).toFixed(2);
    state.wallArea  = +(2 * (l + w) * h).toFixed(2);
    floorAreaDisplay.textContent = fmtArea(state.floorArea);
    wallAreaDisplay.textContent  = fmtArea(state.wallArea);
    areaPreview.hidden = false;
  } else {
    areaPreview.hidden = true;
  }
  const allFilled = parseFloat(dimLength.value) > 0 &&
                    parseFloat(dimWidth.value)  > 0 &&
                    parseFloat(dimHeight.value) > 0;
  step2Next.disabled = !allFilled;
}

[dimLength, dimWidth, dimHeight].forEach(inp => {
  inp.addEventListener('input', updateAreaPreview);
});

step2Back.addEventListener('click', () => goTo(1));
step2Next.addEventListener('click', () => {
  const { l, w, h } = getMetricDims();
  state.length    = l;
  state.width     = w;
  state.height    = h;
  state.floorArea = +(l * w).toFixed(2);
  state.wallArea  = +(2 * (l + w) * h).toFixed(2);
  goTo(3);
});

// ── Step 3: Finishing level ───────────────────────────────────────────────────
document.querySelectorAll('.finishing-card').forEach(card => {
  card.addEventListener('click', () => {
    document.querySelectorAll('.finishing-card').forEach(c => c.classList.remove('is-selected'));
    card.classList.add('is-selected');
    state.level = card.dataset.level;
    step3Next.disabled = false;
    animate(card, { scale: [0.97, 1] }, { duration: 0.2, easing: 'ease-out' });
  });
});

step3Back.addEventListener('click', () => goTo(2));
step3Next.addEventListener('click', () => {
  if (!state.level) return;
  goTo(4);
});

// ── Step 4: Calculation & results ─────────────────────────────────────────────
const LOG_MESSAGES = [
  'est_calc_geometry',
  'est_calc_coverage',
  'est_calc_multipliers',
  'est_calc_vendor',
  'est_calc_quantities',
  'est_calc_breakdown',
];

function startCalculation() {
  const calcEl    = document.getElementById('estimator-calculating');
  const resultsEl = document.getElementById('estimator-results');
  const statusEl  = document.getElementById('calc-status');
  const logEl     = document.getElementById('calc-log');

  calcEl.hidden    = false;
  resultsEl.hidden = true;
  logEl.innerHTML  = '';

  let i = 0;
  const interval = setInterval(() => {
    if (i < LOG_MESSAGES.length) {
      statusEl.textContent = t(LOG_MESSAGES[i]);
      const item = document.createElement('div');
      item.className = 'calc-log__item';
      item.style.animationDelay = '0ms';
      item.textContent = '✓ ' + t(LOG_MESSAGES[i]);
      logEl.appendChild(item);
      i++;
    } else {
      clearInterval(interval);
      setTimeout(() => {
        calcEl.hidden    = true;
        resultsEl.hidden = false;
        renderResults();
      }, 400);
    }
  }, 420);
}

function calcCosts() {
  const rate   = RATES[state.level];
  const mult   = ROOM_MULTIPLIERS[state.roomType] || 1;
  const area   = state.floorArea;

  const labor      = area * rate.labor      * mult;
  const materials  = area * rate.materials  * mult;
  const logistics  = area * rate.logistics  * mult;
  const total      = labor + materials + logistics;
  const variance   = total * rate.variance;

  return {
    labor,
    materials,
    logistics,
    total,
    low:  Math.round(total - variance),
    high: Math.round(total + variance),
  };
}

function renderResults() {
  const costs = calcCosts();
  const area  = state.floorArea;

  // Total range
  document.getElementById('results-total-range').textContent =
    `${fmt(costs.low)} EGP – ${fmt(costs.high)} EGP`;

  // Market badge
  const savings = Math.round(Math.random() * 8 + 3);
  document.getElementById('results-market-text').textContent =
    t('est_savings_market', { n: savings });

  // Meta pills
  document.getElementById('results-room-label').textContent =
    ROOM_LABELS[state.roomType];
  document.getElementById('results-level-label').textContent =
    LEVEL_LABELS[state.level];
  document.getElementById('results-area-label').textContent =
    fmtArea(area) + ' floor';

  // Breakdown bars
  renderBreakdown(costs);

  // Materials
  renderMaterials(area);

  // Vendors
  renderVendors(costs.materials);

  // Animate in
  const resultsEl = document.getElementById('estimator-results');
  animate(resultsEl, { opacity: [0, 1], y: [20, 0] }, { duration: 0.5, easing: 'ease-out' });

  // Animate bars with delay
  setTimeout(() => {
    document.querySelectorAll('.breakdown-bar__fill').forEach(fill => {
      const target = fill.dataset.target;
      fill.style.width = target + '%';
    });
  }, 300);
}

function renderBreakdown(costs) {
  const total = costs.labor + costs.materials + costs.logistics;
  const items = [
    { key: 'labor',     label: t('est_labor'),     amount: costs.labor,     cls: 'labor' },
    { key: 'materials', label: t('est_materials'), amount: costs.materials, cls: 'materials' },
    { key: 'logistics', label: t('est_logistics'), amount: costs.logistics, cls: 'logistics' },
  ];

  const container = document.getElementById('breakdown-bars');
  container.innerHTML = items.map(({ label, amount, cls }) => {
    const pct = Math.round((amount / total) * 100);
    return `
      <div class="breakdown-bar">
        <span class="breakdown-bar__label">${label}</span>
        <div class="breakdown-bar__track">
          <div class="breakdown-bar__fill breakdown-bar__fill--${cls}" data-target="${pct}" style="width:0"></div>
        </div>
        <div>
          <div class="breakdown-bar__amount">${fmt(Math.round(amount))} EGP</div>
          <div class="breakdown-bar__pct">${pct}%</div>
        </div>
      </div>
    `;
  }).join('');
}

function renderMaterials(areaSqm) {
  const room  = state.roomType;
  const level = state.level;

  const tileWaste  = 1.1;
  const groutPerSqm = 0.5; // kg

  const floorTiles = (areaSqm * tileWaste).toFixed(1);
  const wallTilesRaw = (room === 'kitchen' || room === 'bathroom')
    ? state.wallArea * tileWaste
    : 0;
  const wallTiles  = wallTilesRaw.toFixed(1);
  const paintLiters = (state.wallArea / 10 * 2).toFixed(1); // 2 coats
  const grout      = (areaSqm * groutPerSqm).toFixed(1);
  const primer     = (state.wallArea / 12).toFixed(1);

  const materialGrade = { economy: 'Standard', standard: 'Mid-Grade', premium: 'High-End' }[level];

  const rows = [
    { material: t('est_mat_floor_tiles', { grade: materialGrade }), qty: `${floorTiles} m²`, note: '+10% waste allowance' },
    ...(parseFloat(wallTiles) > 0 ? [
      { material: t('est_mat_wall_tiles', { grade: materialGrade }), qty: `${wallTiles} m²`, note: 'Kitchen/Bath walls' }
    ] : []),
    { material: t('est_mat_paint'),    qty: `${paintLiters} L`,  note: '2 coats + primer coat' },
    { material: t('est_mat_primer'),   qty: `${primer} L`,        note: 'Pre-paint treatment' },
    { material: t('est_mat_grout'),    qty: `${grout} kg`,        note: 'Joints & gaps' },
    { material: t('est_mat_adhesive'), qty: `${(areaSqm * 5).toFixed(0)} kg`, note: 'Floor & wall fixing' },
  ];

  const container = document.getElementById('materials-table');
  container.innerHTML = `
    <div class="materials-row materials-row--header">
      <span>${t('est_materials')}</span>
      <span>${t('est_qty')}</span>
      <span>${t('est_notes')}</span>
    </div>
    ${rows.map(r => `
      <div class="materials-row">
        <span class="materials-row__material">${r.material}</span>
        <span class="materials-row__qty">${r.qty}</span>
        <span class="materials-row__note">${r.note}</span>
      </div>
    `).join('')}
  `;
}

function renderVendors(materialsCost) {
  const vendors = [
    {
      name:     'EliteFinish Supply',
      rating:   4.8,
      stock:    'in',
      stockLabel: 'In Stock',
      discount: 5,
      best:     false,
    },
    {
      name:     'ProBuild Materials',
      rating:   4.6,
      stock:    'low',
      stockLabel: 'Limited Stock',
      discount: 2,
      best:     false,
    },
    {
      name:     'CraftHub Wholesale',
      rating:   4.7,
      stock:    'in',
      stockLabel: 'In Stock',
      discount: 8,
      best:     true,
    },
  ];

  // Best deal badge
  vendors.sort((a, b) => b.discount - a.discount);
  vendors[0].best = true;

  const container = document.getElementById('vendor-cards');
  container.innerHTML = vendors.map(v => {
    const price = Math.round(materialsCost * (1 - v.discount / 100));
    return `
      <div class="vendor-card ${v.best ? 'vendor-card--best' : ''}">
        <div class="vendor-card__header">
          <span class="vendor-card__name">${v.name}</span>
          ${v.best ? `<span class="vendor-card__badge">${t('est_best_deal')}</span>` : ''}
        </div>
        <div class="vendor-card__rating">
          ★ ${v.rating.toFixed(1)}
        </div>
        <div class="vendor-card__stock vendor-card__stock--${v.stock}">● ${t(v.stock === 'in' ? 'est_in_stock' : 'est_low_stock')}</div>
        <div class="vendor-card__price">${fmt(price)} EGP</div>
        <div class="vendor-card__discount">${t('est_save_pct', { n: v.discount })}</div>
        <a class="btn btn--sm vendor-card__btn" href="./booking.html">${t('est_book_service')}</a>
      </div>
    `;
  }).join('');

  // Stagger vendor cards in
  const cards = container.querySelectorAll('.vendor-card');
  animate(cards, { opacity: [0, 1], y: [12, 0] },
    { delay: stagger(0.08, { start: 0.2 }), duration: 0.35, easing: 'ease-out' });
}

// ── Restart ───────────────────────────────────────────────────────────────────
restartBtn.addEventListener('click', () => {
  // Reset state
  state.roomType  = null;
  state.unit      = 'm';
  state.length    = null;
  state.width     = null;
  state.height    = null;
  state.floorArea = null;
  state.wallArea  = null;
  state.level     = null;

  // Reset UI
  document.querySelectorAll('.room-type-card').forEach(c => c.classList.remove('is-selected'));
  document.querySelectorAll('.finishing-card').forEach(c => c.classList.remove('is-selected'));
  document.querySelectorAll('.unit-toggle__btn').forEach((b, i) => {
    b.classList.toggle('unit-toggle__btn--active', i === 0);
  });
  [dimLength, dimWidth, dimHeight].forEach(i => i.value = '');
  [unitLabelL, unitLabelW, unitLabelH].forEach(l => l.textContent = 'm');
  areaPreview.hidden = true;
  step1Next.disabled = true;
  step2Next.disabled = true;
  step3Next.disabled = true;

  goTo(1);

  // Scroll to wizard
  document.getElementById('wizard-card').scrollIntoView({ behavior: 'smooth', block: 'start' });
});

// ── Hero canvas — particle network ────────────────────────────────────────────
(function initHeroCanvas() {
  const canvas = document.getElementById('estimator-hero-canvas');
  if (!canvas) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  const ctx    = canvas.getContext('2d');
  const COUNT  = 72;
  const LINK_DIST = 130;
  const MOUSE_RADIUS = 160;

  let W, H, mouse = { x: -999, y: -999 }, rafId;

  /* ── Particle class ── */
  class Particle {
    constructor() { this.reset(true); }

    reset(init = false) {
      this.x  = Math.random() * W;
      this.y  = init ? Math.random() * H : -8;
      this.vx = (Math.random() - 0.5) * 0.45;
      this.vy = (Math.random() - 0.5) * 0.45;
      // two tiers: dim background nodes + bright accent nodes
      this.bright  = Math.random() < 0.22;
      this.r       = this.bright ? Math.random() * 2 + 2 : Math.random() * 1.2 + 0.8;
      this.baseAlpha = this.bright ? Math.random() * 0.35 + 0.45 : Math.random() * 0.2 + 0.12;
      this.alpha   = this.baseAlpha;
      this.pulse   = Math.random() * Math.PI * 2;
      this.pulseSpeed = Math.random() * 0.02 + 0.008;
    }

    update() {
      // pulse brightness
      this.pulse += this.pulseSpeed;
      this.alpha = this.baseAlpha + Math.sin(this.pulse) * (this.bright ? 0.18 : 0.06);

      // mouse repulsion
      const dx = this.x - mouse.x;
      const dy = this.y - mouse.y;
      const d  = Math.sqrt(dx * dx + dy * dy);
      if (d < MOUSE_RADIUS) {
        const force = (MOUSE_RADIUS - d) / MOUSE_RADIUS;
        this.x += (dx / d) * force * 2.2;
        this.y += (dy / d) * force * 2.2;
      }

      this.x += this.vx;
      this.y += this.vy;

      // soft wrap
      if (this.x < -10) this.x = W + 10;
      if (this.x > W + 10) this.x = -10;
      if (this.y < -10) this.y = H + 10;
      if (this.y > H + 10) this.y = -10;
    }

    draw() {
      // bright nodes get a glow halo
      if (this.bright) {
        const grad = ctx.createRadialGradient(this.x, this.y, 0, this.x, this.y, this.r * 4);
        grad.addColorStop(0, `rgba(154,140,115,${this.alpha * 0.9})`);
        grad.addColorStop(1, 'rgba(154,140,115,0)');
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.r * 4, 0, Math.PI * 2);
        ctx.fillStyle = grad;
        ctx.fill();
      }
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2);
      ctx.fillStyle = this.bright
        ? `rgba(191,176,154,${this.alpha})`
        : `rgba(154,140,115,${this.alpha})`;
      ctx.fill();
    }
  }

  /* ── Pool ── */
  let particles = [];

  function resize() {
    const rect = canvas.parentElement.getBoundingClientRect();
    W = canvas.width  = rect.width;
    H = canvas.height = rect.height;
    particles = Array.from({ length: COUNT }, () => new Particle());
  }

  /* ── Draw connections ── */
  function drawLinks() {
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const a  = particles[i];
        const b  = particles[j];
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const d  = Math.sqrt(dx * dx + dy * dy);
        if (d < LINK_DIST) {
          const t = 1 - d / LINK_DIST;
          const alpha = t * 0.22 * ((a.alpha + b.alpha) / 2 / 0.35);
          ctx.beginPath();
          ctx.moveTo(a.x, a.y);
          ctx.lineTo(b.x, b.y);
          ctx.strokeStyle = `rgba(154,140,115,${alpha})`;
          ctx.lineWidth   = t * 1.2;
          ctx.stroke();
        }
      }
    }
  }

  /* ── Mouse-proximity highlight lines ── */
  function drawMouseLinks() {
    particles.forEach(p => {
      const dx = p.x - mouse.x;
      const dy = p.y - mouse.y;
      const d  = Math.sqrt(dx * dx + dy * dy);
      if (d < MOUSE_RADIUS * 1.3) {
        const t = 1 - d / (MOUSE_RADIUS * 1.3);
        ctx.beginPath();
        ctx.moveTo(p.x, p.y);
        ctx.lineTo(mouse.x, mouse.y);
        ctx.strokeStyle = `rgba(191,176,154,${t * 0.18})`;
        ctx.lineWidth   = t * 1.5;
        ctx.stroke();
      }
    });
  }

  /* ── Loop ── */
  function loop() {
    ctx.clearRect(0, 0, W, H);
    drawLinks();
    drawMouseLinks();
    particles.forEach(p => { p.update(); p.draw(); });
    rafId = requestAnimationFrame(loop);
  }

  /* ── Events ── */
  const hero = canvas.parentElement;
  hero.addEventListener('mousemove', e => {
    const r = canvas.getBoundingClientRect();
    mouse = { x: e.clientX - r.left, y: e.clientY - r.top };
  });
  hero.addEventListener('mouseleave', () => { mouse = { x: -999, y: -999 }; });

  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => { cancelAnimationFrame(rafId); resize(); loop(); }, 120);
  });

  resize();
  loop();
}());

// ── Entry animation ───────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReduced) return;

  const heroContent = document.querySelector('.estimator-hero__content');
  if (heroContent) {
    const els = heroContent.querySelectorAll('[data-reveal]');
    animate(els, { opacity: [0, 1], y: [24, 0] },
      { delay: stagger(0.1, { start: 0.1 }), duration: 0.5, easing: 'ease-out' });
  }

  const wizardCard = document.querySelector('.wizard-card');
  if (wizardCard) {
    animate(wizardCard, { opacity: [0, 1], y: [20, 0] }, { delay: 0.3, duration: 0.5, easing: 'ease-out' });
  }
});

// .
