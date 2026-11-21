import { getServices } from '../api/services.js';
import { getWorkers } from '../api/users.js';
import { getWorkerReviews } from '../api/reviews.js';
import { initScrollReveal } from '../components/scroll-reveal.js';
import { initShowcaseAtmosphere } from '../components/showcase-atmosphere.js';
import { slugifyServiceLabel } from '../data/services-data.js';

document.addEventListener('DOMContentLoaded', () => {
  // ── DOM refs ──────────────────────────────────────────────────────────────
  const searchInput      = document.getElementById('service-search');
  const searchClear      = document.getElementById('serviceSearchClear');
  const filterBtns       = document.querySelectorAll('.filter-chip[data-filter]');
  const controlsSecondary = document.querySelector('.controls-row--secondary');
  const controlsMeta      = document.querySelector('.controls-row--meta');
  // productCards and categoryGroups will be dynamically managed now
  const resultsContainer = document.querySelector('.marketplace-results');
  const featuredSection  = document.querySelector('.featured-section');
  const marketplaceSection = document.querySelector('.marketplace-section');
  const resultCount      = document.getElementById('service-result-count');
  const resultLabel      = document.getElementById('service-result-label');
  const viewToggles      = document.querySelectorAll('.view-toggle-btn');
  const emptyState       = document.getElementById('serviceEmptyState');
  const resetBtn         = document.getElementById('serviceResetBtn');
  const pagination       = document.getElementById('servicePagination');
  const paginationPrev   = document.getElementById('paginationPrev');
  const paginationNext   = document.getElementById('paginationNext');
  const paginationPages  = document.getElementById('paginationPages');

  // ── Atmosphere Background ──
  initShowcaseAtmosphere('.hero-marketplace', 450);

  // ── Drawer Refs ───────────────────────────────────────────────────────────
  const svcDrawerOverlay      = document.getElementById('svcDrawerOverlay');
  const svcDrawer             = document.getElementById('svcDrawer');
  const svcDrawerClose        = document.getElementById('svcDrawerClose');
  const svcDrawerScroller     = document.getElementById('svcDrawerScroller');
  const svcDrawerImg          = document.getElementById('svcDrawerImg');
  const svcDrawerCategory     = document.getElementById('svcDrawerCategory');
  const svcDrawerTitle        = document.getElementById('svcDrawerTitle');
  const svcDrawerStats        = document.getElementById('svcDrawerStats');
  const svcDrawerFeatures     = document.getElementById('svcDrawerFeatures');
  const svcDrawerPricing      = document.getElementById('svcDrawerPricing');
  const svcDrawerReview       = document.getElementById('svcDrawerReview');
  const svcDrawerReviewSection = document.getElementById('svcDrawerReviewSection');
  const svcDrawerReviewSub    = document.getElementById('svcDrawerReviewSub');
  const svcDrawerCta          = document.getElementById('svcDrawerCta');
  const svcDrawerCtaCount     = document.getElementById('svcDrawerCtaCount');

  // Guards stale async fills when the user opens services in quick succession.
  let drawerReqId = 0;
  let priceRevealObserver = null;

  // Custom Dropdown & Panel Refs
  const sortDropdown     = document.getElementById('sort-dropdown');
  const sortTrigger      = sortDropdown?.querySelector('.dropdown-trigger');
  const sortMenu         = sortDropdown?.querySelector('.dropdown-menu');
  const currentSortVal   = document.getElementById('current-sort-value');
  const moreFiltersBtn   = document.getElementById('more-filters-btn');
  const filterPanel      = document.getElementById('advanced-filter-panel');
  const closeFiltersBtn  = document.getElementById('close-filters-btn');
  const applyFiltersBtn  = document.getElementById('apply-all-filters');
  const resetFiltersBtn  = document.getElementById('reset-all-filters');
  const activeFiltersContainer = document.getElementById('active-filters-list');
  const filterCountBadge = document.getElementById('active-filter-count');

  // ── State ─────────────────────────────────────────────────────────────────
  let state = {
    query: '',
    filter: 'all',
    sort: 'featured',
    view: 'grid',
    page: 1,
    browseCategory: null, // null = category grid; string = drill-down into that category
    advanced: {
      category: [],
      scope: [],
      cert: [],
      price: { min: null, max: null }
    },
    apiServices: [] // Full list from API
  };
  const PAGE_SIZE = 6;

  // ── Category metadata ─────────────────────────────────────────────────────
  const CATEGORY_LABELS = {
    plumbing: 'Plumbing', electrical: 'Electrical', hvac: 'HVAC & Climate',
    cleaning: 'Cleaning', painting: 'Painting', carpentry: 'Carpentry',
    flooring: 'Flooring', appliance: 'Appliance Repair', handyman: 'Handyman',
    renovation: 'Renovation', drywall: 'Drywall & Plastering', roofing: 'Roofing',
    'pest-control': 'Pest Control', landscaping: 'Landscaping', installation: 'Installation',
  };

  const CATEGORY_ICONS = {
    plumbing:      `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"/><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"/></svg>`,
    electrical:    `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>`,
    hvac:          `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h20"/><path d="M12 2v20"/><path d="m20 16-4-4 4-4"/><path d="m4 8 4 4-4 4"/><path d="m16 4-4 4-4-4"/><path d="m8 20 4-4 4 4"/></svg>`,
    cleaning:      `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4.5 8-11.8A8 8 0 0 0 12 2a8 8 0 0 0-8 8.2c0 7.3 8 11.8 8 11.8z"/><circle cx="12" cy="10" r="3"/></svg>`,
    painting:      `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>`,
    carpentry:     `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"/></svg>`,
    flooring:      `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/></svg>`,
    appliance:     `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="15" x="2" y="4" rx="2"/><path d="M8 4v15M16 4v15M2 9h20M2 14h20"/></svg>`,
    handyman:      `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`,
    renovation:    `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>`,
    drywall:       `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="18" rx="2"/><path d="M2 9h20M2 15h20M8 3v6M16 3v6M8 15v6M16 15v6"/></svg>`,
    roofing:       `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7"/><path d="M3 9v13h18V9"/><path d="M9 22V12h6v10"/></svg>`,
    'pest-control':`<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 12h8M12 8v8"/><circle cx="12" cy="12" r="9"/><path d="M4.93 4.93l14.14 14.14"/></svg>`,
    landscaping:   `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22v-7l-2-2"/><path d="M17 8v.8A6 6 0 0 1 13.8 20v0H10v0A6.5 6.5 0 0 1 7 8h0a5 5 0 0 1 10 0z"/><path d="m14 14-2 2-2-2"/></svg>`,
    installation:  `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>`,
    other:         `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`,
  };

  const SERVICE_ICON_MAP = {
    refrigerator: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 2h14a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z"/><path d="M3 10h18"/><path d="M7 6h1"/><path d="M7 14h1"/></svg>`,
    washer: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="20" x="3" y="2" rx="2"/><circle cx="12" cy="13" r="5"/><path d="M12 10a3 3 0 0 1 3 3"/></svg>`,
    oven: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/><path d="M6 6h.01"/><path d="M10 6h.01"/><path d="M14 6h.01"/><circle cx="12" cy="14" r="3"/></svg>`,
    ac: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v20"/><path d="M2 12h20"/><path d="m4.93 4.93 14.14 14.14"/><path d="m4.93 19.07 14.14-14.14"/></svg>`,
    leak: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5s-3 3.5-3 5.5a7 7 0 0 0 7 7z"/></svg>`,
    toilet: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 12h10l1 7H6l1-7Z"/><path d="M7 12V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v7"/><path d="M12 5V3"/><path d="M5 19h14"/></svg>`,
    light: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1.3.5 2.6 1.5 3.5.8.8 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/></svg>`,
    bolt: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>`,
    sparkle: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/></svg>`,
    bug: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="8" height="14" x="8" y="6" rx="4"/><path d="m19 7-3 2"/><path d="m5 7 3 2"/><path d="m19 19-3-2"/><path d="m5 19 3-2"/><path d="M20 13h-4"/><path d="M4 13h4"/><path d="m12 20v2"/></svg>`,
    garden: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V5"/><path d="M5 12l7-7 7 7"/><path d="M5 19h14"/></svg>`,
    hammer: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"/></svg>`,
    roller: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="16" height="6" x="2" y="2" rx="2"/><path d="M18 12V5a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1Z"/><path d="M2 17h20"/><path d="M6 8v9"/><path d="M10 8v9"/><path d="M14 8v9"/></svg>`,
    sofa: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 9V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v3"/><rect width="16" height="6" x="4" y="9" rx="2"/><path d="M2 13h20"/><path d="M4 19v2"/><path d="M20 19v2"/></svg>`,
  };

  // ── Helpers ───────────────────────────────────────────────────────────────
  function toggleDropdown(dropdown, force) {
    const trigger = dropdown.querySelector('.dropdown-trigger');
    const menu = dropdown.querySelector('.dropdown-menu');
    const isExpanded = force !== undefined ? !force : trigger.getAttribute('aria-expanded') === 'true';
    
    trigger.setAttribute('aria-expanded', !isExpanded);
    menu.setAttribute('data-visible', !isExpanded);
    
    if (!isExpanded) {
      const closeHandler = (e) => {
        if (!dropdown.contains(e.target)) {
          trigger.setAttribute('aria-expanded', 'false');
          menu.setAttribute('data-visible', 'false');
          document.removeEventListener('click', closeHandler);
        }
      };
      setTimeout(() => document.addEventListener('click', closeHandler), 10);
    }
  }

  function animateCount(el, target) {
    if (!el) return;
    const start = parseInt(el.textContent) || 0;
    if (start === target) return;
    const duration = 400;
    const startTime = performance.now();
    function step(now) {
      const progress = Math.min((now - startTime) / duration, 1);
      const ease = 1 - Math.pow(1 - progress, 3); // Cubic ease out
      el.textContent = Math.round(start + (target - start) * ease);
      if (progress < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  function getPaginationItems(totalPages, currentPage) {
    const items = [];
    for (let page = 1; page <= totalPages; page++) {
      const isEdge = page === 1 || page === totalPages;
      const isNearCurrent = Math.abs(page - currentPage) <= 1;
      if (isEdge || isNearCurrent) {
        items.push(page);
      } else if (items[items.length - 1] !== 'ellipsis') {
        items.push('ellipsis');
      }
    }
    return items;
  }

  function getBestIcon(svc) {
    const title = (svc.title || '').toLowerCase();
    const desc = (svc.description || '').toLowerCase();
    const category = (svc.category || '').toLowerCase();
    
    const findKeyword = (text) => {
      if (text.includes('refrigerator') || text.includes('fridge')) return 'refrigerator';
      if (text.includes('wash') || text.includes('dryer') || text.includes('laundry')) return 'washer';
      if (text.includes('oven') || text.includes('stove') || text.includes('range')) return 'oven';
      if (text.includes('ac ') || text.includes('air cond') || text.includes('hvac')) return 'ac';
      if (text.includes('fan')) return 'ac';
      if (text.includes('leak') || text.includes('pipe') || text.includes('faucet') || text.includes('toilet') || text.includes('sink')) return 'leak';
      if (text.includes('light') || text.includes('wiring') || text.includes('outlet') || text.includes('circuit')) return 'light';
      if (text.includes('deep clean') || text.includes('maid') || text.includes('janitor') || text.includes('sparkle')) return 'sparkle';
      if (text.includes('pest') || text.includes('bug') || text.includes('insect') || text.includes('ant') || text.includes('termite')) return 'bug';
      if (text.includes('garden') || text.includes('mowing') || text.includes('landscap') || text.includes('grass')) return 'garden';
      if (text.includes('paint') || text.includes('roller')) return 'roller';
      if (text.includes('furniture') || text.includes('cabinet') || text.includes('sofa') || text.includes('table')) return 'sofa';
      if (text.includes('tv') || text.includes('mount') || text.includes('install')) return 'hammer';
      if (text.includes('door') || text.includes('lock')) return 'hammer';
      return null;
    };

    const keyword = findKeyword(title) || findKeyword(desc);
    if (keyword && SERVICE_ICON_MAP[keyword]) {
      return SERVICE_ICON_MAP[keyword];
    }
    
    return CATEGORY_ICONS[category] || CATEGORY_ICONS.other;
  }

  function scrollMarketplaceToTop() {
    marketplaceSection?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function renderPagination(totalItems) {
    if (!pagination || !paginationPrev || !paginationNext || !paginationPages) return;

    const totalPages = Math.max(1, Math.ceil(totalItems / PAGE_SIZE));
    const shouldShow = totalItems > PAGE_SIZE;
    pagination.hidden = !shouldShow;
    paginationPages.innerHTML = '';

    if (!shouldShow) return;

    paginationPrev.disabled = state.page === 1;
    paginationNext.disabled = state.page === totalPages;

    getPaginationItems(totalPages, state.page).forEach(item => {
      if (item === 'ellipsis') {
        const ellipsis = document.createElement('span');
        ellipsis.className = 'services-pagination__ellipsis';
        ellipsis.textContent = '...';
        paginationPages.appendChild(ellipsis);
        return;
      }

      const button = document.createElement('button');
      button.type = 'button';
      button.className = `services-pagination__page${item === state.page ? ' is-active' : ''}`;
      button.dataset.page = String(item);
      button.textContent = String(item);
      if (item === state.page) button.setAttribute('aria-current', 'page');
      paginationPages.appendChild(button);
    });
  }

  // ── API & Rendering ───────────────────────────────────────────────────────
  async function fetchServices() {
    try {
      // api client already unwraps 'data', so response = { services, pagination }
      const response = await getServices({ limit: 50 });
      state.apiServices = response.services || [];
      console.log('[marketplace] fetched services:', state.apiServices.length, state.apiServices);
      applyFilters();
    } catch (err) {
      console.error('Failed to fetch services:', err);
      state.apiServices = [];
      applyFilters();
    }
  }

  // ── Dynamic badge logic ───────────────────────────────────────────────────
  function resolveServiceBadges(svc) {
    const category = (svc.category || 'other').toLowerCase();
    const rating   = parseFloat(svc.averageRating) || 0;
    const reviews  = parseInt(svc.totalReviews)    || 0;
    const price    = parseFloat(svc.basePrice)      || 0;

    // Primary: professional category label (always shown)
    const categoryMeta = {
      plumbing:      { label: 'Emergency Ready', labelAr: 'جاهز للطوارئ',    cls: 'tag--danger',    i18n: 'badge_emergency_ready'  },
      electrical:    { label: 'Licensed Pro',    labelAr: 'محترف مرخّص',      cls: 'tag--secondary', i18n: 'badge_licensed_pro'     },
      hvac:          { label: 'Climate Expert',  labelAr: 'خبير مناخي',       cls: 'tag--secondary', i18n: 'badge_climate_expert'   },
      cleaning:      { label: 'Deep Clean Pro',  labelAr: 'تنظيف عميق',       cls: 'tag--success',   i18n: 'badge_deep_clean'       },
      painting:      { label: 'Master Finish',   labelAr: 'دهان محترف',       cls: 'tag--paint',     i18n: 'badge_master_finish'    },
      carpentry:     { label: 'Custom Craft',    labelAr: 'نجارة مخصصة',      cls: 'tag--wood',      i18n: 'badge_custom_craft'     },
      flooring:      { label: 'Floor Expert',    labelAr: 'خبير أرضيات',      cls: 'tag--outline',   i18n: 'badge_floor_expert'     },
      appliance:     { label: 'Appliance Pro',   labelAr: 'متخصص أجهزة',      cls: 'tag--secondary', i18n: 'badge_appliance_pro'    },
      handyman:      { label: 'All-Round Fix',   labelAr: 'إصلاح متكامل',     cls: 'tag--outline',   i18n: 'badge_all_round'        },
      renovation:    { label: 'Full Reno',       labelAr: 'تجديد شامل',       cls: 'tag--danger',    i18n: 'badge_full_reno'        },
      drywall:       { label: 'Wall Expert',     labelAr: 'خبير جدران',       cls: 'tag--outline',   i18n: 'badge_wall_expert'      },
      roofing:       { label: 'Roof Specialist', labelAr: 'متخصص أسطح',       cls: 'tag--secondary', i18n: 'badge_roof_specialist'  },
      'pest-control':{ label: 'Eco Safe',        labelAr: 'آمن بيئياً',        cls: 'tag--success',   i18n: 'badge_eco_safe'         },
      landscaping:   { label: 'Garden Pro',      labelAr: 'خبير حدائق',       cls: 'tag--success',   i18n: 'badge_garden_pro'       },
      installation:  { label: 'Precision Fit',   labelAr: 'تركيب دقيق',       cls: 'tag--outline',   i18n: 'badge_precision_fit'    },
      other:         { label: 'Specialist',      labelAr: 'متخصص',            cls: 'tag--outline',   i18n: 'badge_specialist'       },
    };
    const primary = categoryMeta[category] || categoryMeta.other;

    // Secondary: quality/price badge (dynamic, shown only when meaningful)
    let secondary = null;
    if (rating >= 4.8 && reviews > 0) {
      secondary = { label: 'Top Rated', labelAr: 'الأعلى تقييماً', cls: 'tag--gold',    i18n: 'badge_top_rated'       };
    } else if (reviews >= 10) {
      secondary = { label: 'Popular',   labelAr: 'الأكثر طلباً',  cls: 'tag--popular', i18n: 'badge_popular'         };
    } else if (svc.priceUnit === 'fixed') {
      secondary = { label: 'Fixed Price', labelAr: 'سعر ثابت',     cls: 'tag--outline', i18n: 'badge_fixed_price'     };
    } else if (price > 0 && price <= 80) {
      secondary = { label: 'Budget Friendly', labelAr: 'اقتصادي',  cls: 'tag--outline', i18n: 'badge_budget_friendly' };
    } else if (price > 300) {
      secondary = { label: 'Premium',  labelAr: 'بريميوم',         cls: 'tag--secondary',i18n: 'badge_premium'        };
    }

    return { primary, secondary };
  }

  function generateServiceCard(svc, index = 0) {
    const title    = svc.title || 'Untitled Service';
    const category = (svc.category || 'other').toLowerCase();
    const isAr     = (window.__lang || document.documentElement.lang) === 'ar';

    const displayTitle = title.charAt(0).toUpperCase() + title.slice(1);
    const nameKey      = 'svc_' + title.toLowerCase().replace(/ /g, '_');
    const descKey      = nameKey + '_desc';

    const icons = CATEGORY_ICONS;

    const iconClass = ['plumbing','hvac','electrical'].includes(category)
      ? 'product-card__icon--primary'
      : 'product-card__icon--secondary';

    const article = document.createElement('article');
    article.className = 'product-card';
    article.dataset.id       = svc._id;
    article.dataset.category = category;
    article.dataset.rating   = svc.averageRating || '0';
    article.dataset.price    = svc.basePrice || 0;
    article.style.cursor     = 'pointer';
    article.dataset.reveal   = '';
    article.dataset.revealDelay = index * 60;

    const finalIcon = getBestIcon(svc);

    const priceLabel = priceBlock(svc);

    // Honest rating: never invent a number when there are no real reviews —
    // and read from the SAME backend aggregate (svc.techStats) the drawer/
    // modal uses, so the card and modal never contradict each other for the
    // same service (techStats is computed once, server-side, over the
    // available verified technicians who offer this service).
    const ratingNum    = parseFloat(svc.techStats?.rating) || 0;
    const reviewCount  = parseInt(svc.techStats?.reviews) || 0;
    const ratingMarkup = reviewCount > 0 && ratingNum > 0
      ? `${ratingNum.toFixed(1)}<span class="product-card__rating-count">(${reviewCount})</span>`
      : `<span class="product-card__rating-count">No reviews yet</span>`;

    article.innerHTML = `
      <div class="product-card__icon ${iconClass}">${finalIcon}</div>
      <h4 class="product-card__title" data-i18n="${nameKey}">${displayTitle}</h4>
      <p class="product-card__desc" data-i18n="${descKey}">${svc.description || ''}</p>

      <div class="product-card__info">
        <span class="product-card__rating">
          <svg viewBox="0 0 24 24" fill="currentColor" width="13" height="13"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
          ${ratingMarkup}
        </span>
        <span class="product-card__response">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          ~30 min
        </span>
      </div>

      <div class="product-card__footer">
        <span class="product-card__price">${priceLabel}</span>
        <button class="product-card__action" type="button">View Details →</button>
      </div>
    `;

    article.addEventListener('click', () => openServiceDrawer(svc));

    return article;
  }

  // Escape hatch appended after the sub-service cards: a customer who doesn't see their
  // exact issue describes it in their own words on Smart Match instead of dead-ending.
  function generateDescribeCard(catKey, index = 0) {
    const isAr = (window.__lang || document.documentElement.lang) === 'ar';
    const title = isAr ? 'لم تجد مشكلتك؟' : "Can't find your issue?";
    const desc  = isAr
      ? 'صِف المشكلة بكلماتك وسنطابقك مع الخدمة والفني المناسب.'
      : 'Describe it in your own words — we’ll match the right service and technician.';
    const cta   = isAr ? 'صف مشكلتك ←' : 'Describe your problem →';

    const article = document.createElement('article');
    article.className = 'product-card product-card--describe';
    article.style.cursor = 'pointer';
    article.dataset.reveal = '';
    article.dataset.revealDelay = index * 60;
    article.innerHTML = `
      <div class="product-card__icon product-card__icon--secondary">✦</div>
      <h4 class="product-card__title">${title}</h4>
      <p class="product-card__desc">${desc}</p>
      <div class="product-card__footer">
        <span class="product-card__action">${cta}</span>
      </div>
    `;
    article.addEventListener('click', () => {
      window.location.href = `./smart-match.html?service=${encodeURIComponent(catKey)}`;
    });
    return article;
  }

  // ── Drawer Data & Logic ───────────────────────────────────────────────────
  const DRAWER_FEATURES = {
    plumbing:    ['Pipe Repair & Replacement', 'Drain Cleaning', 'Fixture Installation', 'Water Heater Service', 'Leak Detection', 'Full Inspections'],
    electrical:  ['Panel Upgrades', 'Outlet Installation', 'Wiring & Rewiring', 'Safety Inspections', 'Smart Home Setup', 'Emergency Repairs'],
    hvac:        ['AC Installation', 'System Maintenance', 'Filter Replacement', 'Duct Cleaning', 'Thermostat Setup', 'Full Diagnostics'],
    cleaning:    ['Full Home Deep Clean', 'Kitchen Degreasing', 'Bathroom Sanitizing', 'Post-Construction', 'Move In/Out Clean', 'Window Cleaning'],
    painting:    ['Interior Painting', 'Exterior Painting', 'Wall Preparation', 'Priming & Sealing', 'Color Consultation', 'Trim & Detail Work'],
    carpentry:   ['Custom Furniture', 'Door Fitting', 'Shelving & Storage', 'Flooring Install', 'Wood Repair', 'Kitchen Cabinetry'],
    flooring:    ['Hardwood Installation', 'Tile & Stone Work', 'Laminate Flooring', 'Subfloor Repair', 'Sanding & Refinishing', 'Grout & Sealing'],
    appliance:   ['Washer & Dryer Repair', 'Refrigerator Service', 'Oven & Stove Repair', 'Dishwasher Fix', 'Installation & Setup', 'Warranty Support'],
    roofing:     ['Roof Inspection', 'Leak Repair', 'Shingle Replacement', 'Gutter Cleaning', 'Waterproofing', 'Full Roof Replacement'],
    landscaping: ['Lawn Mowing & Edging', 'Tree Trimming', 'Garden Design', 'Irrigation Setup', 'Pest Control', 'Seasonal Cleanup'],
    default:     ['Professional Service', 'Licensed Technicians', 'Quality Guarantee', 'Transparent Pricing', 'Background Checked', 'Fully Insured'],
  };

  const DRAWER_HERO_IMGS = {
    plumbing:    'https://images.unsplash.com/photo-1585771724684-38269d6639fd?q=70&w=900&auto=format&fit=crop',
    electrical:  'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?q=70&w=900&auto=format&fit=crop',
    hvac:        'https://images.unsplash.com/photo-1497366216548-37526070297c?q=70&w=900&auto=format&fit=crop',
    cleaning:    'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=70&w=900&auto=format&fit=crop',
    painting:    'https://images.unsplash.com/photo-1562259949-e8e7689d7828?q=70&w=900&auto=format&fit=crop',
    carpentry:   'https://images.unsplash.com/photo-1504148455328-c376907d081c?q=70&w=900&auto=format&fit=crop',
    flooring:    'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?q=70&w=900&auto=format&fit=crop',
    roofing:     'https://images.unsplash.com/photo-1632759145355-8b8a6d018a34?q=70&w=900&auto=format&fit=crop',
    landscaping: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?q=70&w=900&auto=format&fit=crop',
    default:     'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?q=70&w=900&auto=format&fit=crop',
  };

  function openServiceDrawer(svc) {
    if (!svcDrawer) return;
    const category = (svc.category || 'other').toLowerCase();
    const title     = svc.title ? (svc.title.charAt(0).toUpperCase() + svc.title.slice(1)) : 'Service';
    // Single backend source: techStats is the SAME aggregate the marketplace
    // card reads (svc.techStats), so the card and this modal can never disagree.
    const techStats = svc.techStats || { pros: 0, rating: 0, reviews: 0, minStartsFrom: null };
    const rating    = parseFloat(techStats.rating) || 0;
    const reviews   = parseInt(techStats.reviews) || 0;
    const pros      = parseInt(techStats.pros) || 0;
    const priceBand = resolvePriceBand(svc);
    const price     = priceBand.startsFrom;

    svcDrawerImg.src          = DRAWER_HERO_IMGS[category] || DRAWER_HERO_IMGS.default;
    svcDrawerImg.alt          = title;
    svcDrawerCategory.textContent = (svc.category || 'Service').charAt(0).toUpperCase() + (svc.category || 'Service').slice(1) + ' Service';
    svcDrawerTitle.textContent    = title;

    // Stats are about the TECHNICIANS who deliver this service. techStats
    // comes from the service object itself (server-computed, same source the
    // marketplace card reads) so pros/rating/reviews are available instantly —
    // no need to wait on a worker fetch, and no risk of disagreeing with the card.
    renderStats({ pros, rating, reviews, fromPrice: price });

    const features = DRAWER_FEATURES[category] || DRAWER_FEATURES.default;
    svcDrawerFeatures.innerHTML = features.map(f => `
      <div class="svc-drawer__feature-row">
        <span class="svc-drawer__feature-check">
          <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>
        </span>
        ${f}
      </div>
    `).join('');

    // Pricing + individual review quote + CTA count are still derived from
    // REAL technicians (async) — the worker fetch is kept ONLY for those, not
    // for the headline pros/rating/reviews stat (that's techStats, above).
    // Snapshot a request id so a slow fetch can't overwrite a newer drawer open.
    const reqId = ++drawerReqId;
    renderPriceSkeleton();
    renderReviewSkeleton();
    setReviewSubtitle(null);
    if (svcDrawerCtaCount) { svcDrawerCtaCount.hidden = true; svcDrawerCtaCount.textContent = ''; }

    if (svcDrawerCta) {
      // Carry the specific service the user picked through to the listing (and on
      // to booking) as a subservice slug — without it the listing header and the
      // booking record fall back to the generic category ("General Plumbing").
      const subSlug = svc.title ? slugifyServiceLabel(svc.title) : '';
      const ctaParams = new URLSearchParams({ service: category });
      if (subSlug) ctaParams.set('subservice', subSlug);
      svcDrawerCta.href = `./technician-listing.html?${ctaParams.toString()}`;
    }

    // Fire-and-forget: the modal is already open; live data fills in when ready.
    loadDrawerDynamics({ svc, category, price, priceBand, techStats, reqId });

    if (svcDrawerScroller)    svcDrawerScroller.scrollTop = 0;

    svcDrawerOverlay?.classList.add('is-open');
    svcDrawer.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    document.body.classList.add('svc-modal-open');
    document.querySelector('[data-chat-fab]')?.style.setProperty('display', 'none');
    // back-to-top FAB sets its own inline !important styles, so a stylesheet
    // rule can't beat it — override inline directly while the modal is open.
    document.querySelector('.back-to-top')?.style.setProperty('display', 'none', 'important');

    // A11y: remember opener, move focus into the modal, trap Tab inside it.
    lastFocusedEl = document.activeElement;
    document.addEventListener('keydown', trapDrawerFocus, true);
    requestAnimationFrame(() => svcDrawerClose?.focus());
  }

  // ── Focus trap (modal is a true dialog now) ──────────────────────────────
  let lastFocusedEl = null;
  function trapDrawerFocus(e) {
    if (e.key !== 'Tab' || !svcDrawer?.classList.contains('is-open')) return;
    const focusables = svcDrawer.querySelectorAll(
      'a[href], button:not([disabled]), input, [tabindex]:not([tabindex="-1"])'
    );
    if (!focusables.length) return;
    const first = focusables[0];
    const last  = focusables[focusables.length - 1];
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  }

  function closeServiceDrawer() {
    disconnectPriceRevealObserver();
    svcDrawerOverlay?.classList.remove('is-open');
    svcDrawer?.classList.remove('is-open');
    document.body.style.overflow = '';
    document.body.classList.remove('svc-modal-open');
    document.querySelector('[data-chat-fab]')?.style.removeProperty('display');
    // Restore the back-to-top FAB; its own scroll handler re-manages visibility.
    document.querySelector('.back-to-top')?.style.removeProperty('display');
    document.removeEventListener('keydown', trapDrawerFocus, true);
    if (lastFocusedEl?.focus) lastFocusedEl.focus();
    lastFocusedEl = null;
  }

  // ── Drawer dynamic data (real pricing range + real review + tech count) ──
  function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"']/g, c => (
      { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));
  }

  function avatarFallback(name) {
    return 'https://ui-avatars.com/api/?name=' + encodeURIComponent(name || 'C')
      + '&background=9A8C73&color=fff&size=128';
  }

  // ── Price band helpers (band-based "starts from / typical range") ────────
  // A service's seed band (seedRange) describes the spread of technician
  // rates seeded for it; basePrice is the honest fallback when no band is
  // configured yet. Never render NaN/undefined/"0 EGP" from a missing band.
  function resolvePriceBand(svc) {
    const seedMin = parseFloat(svc?.seedRange?.min) || 0;
    const seedMax = parseFloat(svc?.seedRange?.max) || 0;
    const basePrice = parseFloat(svc?.basePrice) || 0;
    const startsFrom = seedMin > 0 ? seedMin : basePrice;
    const hasTypicalRange = seedMin > 0 && seedMax > 0;
    return { startsFrom, hasTypicalRange, min: seedMin, max: seedMax };
  }

  // Builds the two-line "Starts from / typical range" markup shared by the
  // marketplace card and the service drawer/detail views.
  function priceBlock(svc, { tag = 'span' } = {}) {
    const { startsFrom, hasTypicalRange, min, max } = resolvePriceBand(svc);
    if (!(startsFrom > 0)) {
      return `<${tag} class="price-block"><strong class="price-block__from">On Request</strong></${tag}>`;
    }
    const typicalLine = hasTypicalRange
      ? `<small class="price-block__typical">typical ${min}–${max} EGP</small>`
      : '';
    return `<${tag} class="price-block">` +
      `<strong class="price-block__from">Starts from ${startsFrom} EGP</strong>` +
      typicalLine +
      `</${tag}>`;
  }

  function starString(rating) {
    const r = Math.round(parseFloat(rating) || 0);
    return '★★★★★'.slice(0, r) + '☆☆☆☆☆'.slice(0, 5 - r);
  }

  // ── Stat strip (subject = the technicians who deliver this service) ───────
  const STAT_ICONS = {
    pros: `<svg class="svc-stat-ic svc-stat-ic--line" viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>`,
    star: `<svg class="svc-stat-ic svc-stat-ic--star" viewBox="0 0 24 24"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>`,
    price: `<svg class="svc-stat-ic svc-stat-ic--line" viewBox="0 0 24 24"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>`,
  };
  const STAT_SKEL = '<span class="svc-skel" style="display:inline-block;width:30px;height:15px"></span>';

  function renderStats({ pending = false, pros = 0, rating = 0, reviews = 0, fromPrice = 0 }) {
    if (!svcDrawerStats) return;
    const priceVal = fromPrice > 0
      ? `${fromPrice} <small>EGP</small>`
      : 'On Request';
    const cells = [
      {
        icon:  STAT_ICONS.pros,
        value: pending ? STAT_SKEL : pros,
        label: 'Verified Pros',
      },
      {
        icon:  STAT_ICONS.star,
        value: pending ? STAT_SKEL : (rating > 0 ? rating.toFixed(1) : '-'),
        label: pending ? 'Rating' : (reviews > 0 ? `${reviews} review${reviews !== 1 ? 's' : ''}` : 'No reviews yet'),
      },
      {
        icon:  STAT_ICONS.price,
        value: priceVal,
        label: 'Starting From',
      },
    ];
    svcDrawerStats.innerHTML = cells.map(c => `
      <div class="svc-drawer__stat">
        <div class="svc-drawer__stat-icon">${c.icon}</div>
        <div class="svc-drawer__stat-value">${c.value}</div>
        <div class="svc-drawer__stat-label">${c.label}</div>
      </div>
    `).join('');
  }

  function renderPriceSkeleton() {
    if (!svcDrawerPricing) return;
    disconnectPriceRevealObserver();
    svcDrawerPricing.innerHTML = `
      <div class="svc-price-range is-loading">
        <div class="svc-skel" style="width:38%;height:10px"></div>
        <div class="svc-skel" style="width:58%;height:24px;margin-top:12px"></div>
        <div class="svc-skel" style="width:100%;height:6px;margin-top:14px"></div>
        <div class="svc-skel" style="width:72%;height:11px;margin-top:12px"></div>
      </div>`;
  }

  function renderReviewSkeleton() {
    if (!svcDrawerReview) return;
    svcDrawerReview.className = 'svc-drawer__review is-loading';
    svcDrawerReview.innerHTML = `
      <div class="svc-skel" style="width:30%;height:12px"></div>
      <div class="svc-skel" style="width:100%;height:12px"></div>
      <div class="svc-skel" style="width:85%;height:12px"></div>
      <div class="svc-skel" style="width:45%;height:12px"></div>`;
  }

  // Honest range from the actual technicians' own hourly rates.
  function computePriceRange(workers) {
    const rates = (workers || [])
      .map(w => parseFloat(w.hourlyRate))
      .filter(n => Number.isFinite(n) && n > 0);
    if (!rates.length) return null;
    return { min: Math.min(...rates), max: Math.max(...rates), count: workers.length };
  }

  function disconnectPriceRevealObserver() {
    if (!priceRevealObserver) return;
    priceRevealObserver.disconnect();
    priceRevealObserver = null;
  }

  function preparePriceReveal() {
    const card = svcDrawerPricing?.querySelector('[data-price-reveal]');
    if (!card) return;

    card.classList.remove('is-revealed');
    disconnectPriceRevealObserver();

    if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) {
      card.classList.add('is-revealed');
      return;
    }

    const reveal = () => card.classList.add('is-revealed');
    if (!('IntersectionObserver' in window) || !svcDrawerScroller) {
      requestAnimationFrame(reveal);
      return;
    }

    priceRevealObserver = new IntersectionObserver(entries => {
      if (!entries.some(entry => entry.isIntersecting)) return;
      reveal();
      disconnectPriceRevealObserver();
    }, {
      root: svcDrawerScroller,
      threshold: 0.42,
      rootMargin: '0px 0px -12% 0px',
    });

    requestAnimationFrame(() => priceRevealObserver?.observe(card));
  }

  function renderPricingRange(range) {
    if (!svcDrawerPricing) return;
    const sameValue = range.min === range.max;
    const headline = sameValue
      ? `${range.min} <small>EGP</small>`
      : `${range.min} <span>–</span> ${range.max} <small>EGP</small>`;
    svcDrawerPricing.innerHTML = `
      <div class="svc-price-range">
        <div class="svc-price-range__label">${sameValue ? 'Starting from' : 'Typical range'}</div>
        <div class="svc-price-range__value">${headline}</div>
        <div class="svc-price-range__bar"><span class="svc-price-range__fill"></span></div>
        <div class="svc-price-range__meta">
          <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
          based on <strong>${range.count}</strong> verified technician${range.count !== 1 ? 's' : ''}
        </div>
        <div class="svc-price-range__note">Final price is set by the technician you choose.</div>
      </div>`;
  }

  // Fallback when no technician rates exist yet: honest "starting from" base price,
  // plus the service's seeded "typical" band when one is configured.
  function renderPricingBase(price, typicalRange = null) {
    if (!svcDrawerPricing) return;
    const value = price > 0
      ? `${price} <small>EGP</small>`
      : `On Request`;
    const typicalLine = typicalRange
      ? `<div class="svc-price-range__typical">typical ${typicalRange.min}–${typicalRange.max} EGP</div>`
      : '';
    svcDrawerPricing.innerHTML = `
      <div class="svc-price-range">
        <div class="svc-price-range__label">Starting from</div>
        <div class="svc-price-range__value">${value}</div>
        ${typicalLine}
        <div class="svc-price-range__note">Each technician quotes their own rate — compare them on the next step.</div>
      </div>`;
  }

  function renderPricingRangeAnimated(range) {
    if (!svcDrawerPricing) return;
    const sameValue = range.min === range.max;
    const headline = sameValue
      ? `
        <span class="svc-price-range__endpoint svc-price-range__endpoint--start">
          <span class="svc-price-range__amount">${range.min}</span>
          <small class="svc-price-range__unit">EGP</small>
        </span>
      `
      : `
        <span class="svc-price-range__endpoint svc-price-range__endpoint--start">
          <span class="svc-price-range__amount">${range.min}</span>
          <small class="svc-price-range__unit">EGP</small>
        </span>
        <span class="svc-price-range__endpoint svc-price-range__endpoint--end">
          <span class="svc-price-range__amount">${range.max}</span>
          <small class="svc-price-range__unit">EGP</small>
        </span>
      `;

    svcDrawerPricing.innerHTML = `
      <div class="svc-price-range ${sameValue ? 'svc-price-range--single' : 'svc-price-range--range'}" data-price-reveal>
        <div class="svc-price-range__label">${sameValue ? 'Hourly rate' : 'Typical range'}</div>
        <div class="svc-price-range__value">${headline}</div>
        <div class="svc-price-range__bar" aria-hidden="true">
          <span class="svc-price-range__fill"></span>
          <span class="svc-price-range__marker svc-price-range__marker--start"></span>
          <span class="svc-price-range__marker svc-price-range__marker--end"></span>
        </div>
        <div class="svc-price-range__meta">
          <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
          based on <strong>${range.count}</strong> verified technician${range.count !== 1 ? 's' : ''}
        </div>
        <div class="svc-price-range__note">Final price is set by the technician you choose.</div>
      </div>`;
    preparePriceReveal();
  }

  function renderPricingBaseAnimated(price, typicalRange = null) {
    if (!svcDrawerPricing) return;
    const value = price > 0
      ? `${price} <small>EGP</small>`
      : `On Request`;
    const typicalLine = typicalRange
      ? `<div class="svc-price-range__typical">typical ${typicalRange.min}–${typicalRange.max} EGP</div>`
      : '';

    svcDrawerPricing.innerHTML = `
      <div class="svc-price-range svc-price-range--single" data-price-reveal>
        <div class="svc-price-range__label">Starting from</div>
        <div class="svc-price-range__value">
          <span class="svc-price-range__amount svc-price-range__amount--start">${value}</span>
        </div>
        ${typicalLine}
        <div class="svc-price-range__bar" aria-hidden="true">
          <span class="svc-price-range__fill"></span>
          <span class="svc-price-range__marker svc-price-range__marker--start"></span>
          <span class="svc-price-range__marker svc-price-range__marker--end"></span>
        </div>
        <div class="svc-price-range__note">Each technician quotes their own rate - compare them on the next step.</div>
      </div>`;
    preparePriceReveal();
  }

  function renderReviewReal(review) {
    if (!svcDrawerReview) return;
    const rawName = review.user?.name || 'Verified customer';
    const name    = escapeHtml(rawName);
    const avatar  = review.user?.profileImage || avatarFallback(rawName);
    svcDrawerReview.className = 'svc-drawer__review';
    svcDrawerReview.innerHTML = `
      <div class="svc-drawer__review-quote">"</div>
      <div class="svc-drawer__review-stars">${starString(review.rating)}</div>
      <div class="svc-drawer__review-text">${escapeHtml(review.comment)}</div>
      <div class="svc-drawer__review-author">
        <div>
          <div class="svc-drawer__review-name">${name}</div>
          <div class="svc-drawer__review-tag">Verified Customer</div>
        </div>
      </div>`;

    // Build the avatar <img> as a DOM node (no inline onerror string) and
    // prepend it before the name/tag block. alt is set via .alt (not HTML),
    // so a hostile name like `"><img onerror=alert(1)>` renders as inert text.
    const authorRow = svcDrawerReview.querySelector('.svc-drawer__review-author');
    if (authorRow) {
      const img = document.createElement('img');
      img.className = 'svc-drawer__review-avatar';
      img.src = avatar;
      img.alt = rawName;
      img.addEventListener('error', () => { img.src = avatarFallback(rawName); });
      authorRow.insertBefore(img, authorRow.firstChild);
    }
  }

  function setReviewSubtitle(text) {
    if (!svcDrawerReviewSub) return;
    if (text) { svcDrawerReviewSub.textContent = text; svcDrawerReviewSub.hidden = false; }
    else { svcDrawerReviewSub.hidden = true; }
  }

  // Aggregate fallback: always accurate, no individual quote required.
  // Numbers come from techStats (the SAME backend aggregate as the card and
  // the stat strip) so the review-aggregate text never disagrees with either.
  function renderReviewAggregate(techStats) {
    if (!svcDrawerReview) return;
    const pros = parseInt(techStats?.pros) || 0;
    const avg = parseFloat(techStats?.rating) || 0;
    const totalReviews = parseInt(techStats?.reviews) || 0;
    if (!totalReviews || avg <= 0) {
      // Nothing real to show — hide the section entirely rather than fake it.
      setReviewSubtitle(null);
      if (svcDrawerReviewSection) svcDrawerReviewSection.hidden = true;
      return;
    }
    setReviewSubtitle(null); // aggregate text already names its subject
    svcDrawerReview.className = 'svc-drawer__review';
    svcDrawerReview.innerHTML = `
      <div class="svc-review-aggregate">
        <div class="svc-review-aggregate__score">
          <svg viewBox="0 0 24 24" width="22" height="22"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
          ${avg.toFixed(1)}
        </div>
        <div class="svc-review-aggregate__text">
          <strong>${avg.toFixed(1)} average</strong> from ${totalReviews} review${totalReviews !== 1 ? 's' : ''}${pros ? ` across ${pros} technician${pros !== 1 ? 's' : ''}` : ''}.
        </div>
      </div>`;
  }

  function updateCtaCount(count) {
    if (!svcDrawerCtaCount) return;
    if (count > 0) {
      svcDrawerCtaCount.textContent = `${count} available now`;
      svcDrawerCtaCount.hidden = false;
    } else {
      svcDrawerCtaCount.hidden = true;
    }
  }

  async function loadDrawerDynamics({ svc, category, price, priceBand, techStats, reqId }) {
    // The worker fetch is now ONLY needed for the "Browse Technicians (N
    // available)" CTA count and to find a real review quote to feature —
    // the headline pros/rating/reviews stat is techStats (rendered
    // synchronously in openServiceDrawer, already matching the card).
    let workers = [];
    try {
      const res = await getWorkers({ category, limit: 50 });
      workers = res?.workers || res?.data?.workers || [];
    } catch (err) {
      console.error('[marketplace] failed to load technicians for drawer:', err);
    }
    if (reqId !== drawerReqId) return; // a newer drawer opened — discard

    if (svcDrawerReviewSection) svcDrawerReviewSection.hidden = false;
    const categoryLabel = CATEGORY_LABELS[category] || (category.charAt(0).toUpperCase() + category.slice(1));

    // Pricing headline must match the marketplace card exactly: both render
    // the same band ("starts from" + typical range), never the technicians'
    // own hourly rates — that legacy range caused card/modal to disagree.
    const typicalRange = priceBand?.hasTypicalRange ? { min: priceBand.min, max: priceBand.max } : null;
    renderPricingBaseAnimated(price, typicalRange);

    // CTA live count (still real-time from the worker fetch).
    updateCtaCount(workers.length);

    // Review: real review from the top-rated technician, else the techStats
    // aggregate (NOT a client-side recompute — same numbers as the card/strip).
    const top = [...workers]
      .filter(w => (parseInt(w.totalReviews) || 0) > 0)
      .sort((a, b) => (parseFloat(b.averageRating) || 0) - (parseFloat(a.averageRating) || 0))[0];

    if (!top) { renderReviewAggregate(techStats); return; }

    try {
      const list = await getWorkerReviews(top._id);
      if (reqId !== drawerReqId) return;
      const real = (Array.isArray(list) ? list : []).find(r => (r.comment || '').trim().length > 0);
      if (real) {
        setReviewSubtitle(`Recent review for ${top.name || 'a top-rated technician'} — a top-rated ${categoryLabel} pro on Servio.`);
        renderReviewReal(real);
      } else {
        renderReviewAggregate(techStats);
      }
    } catch (err) {
      console.error('[marketplace] failed to load review for drawer:', err);
      if (reqId === drawerReqId) renderReviewAggregate(techStats);
    }
  }

  svcDrawerClose?.addEventListener('click', closeServiceDrawer);
  svcDrawerOverlay?.addEventListener('click', closeServiceDrawer);
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeServiceDrawer(); });

  function sortServices(services) {
    const list = [...services];
    if (state.sort === 'featured') return list;
    
    return list.sort((a, b) => {
      switch(state.sort) {
        case 'price_low': return (a.basePrice || 0) - (b.basePrice || 0);
        case 'price_high': return (b.basePrice || 0) - (a.basePrice || 0);
        default: return (a.title || '').localeCompare(b.title || '');
      }
    });
  }

  // ── Filter Tokens Logic ───────────────────────────────────────────────────
  function updateFilterTokens() {
    if (!activeFiltersContainer) return;
    activeFiltersContainer.innerHTML = '';
    let count = 0;

    const addToken = (label, type, value) => {
      count++;
      const token = document.createElement('div');
      token.className = 'filter-token';
      token.innerHTML = `
        <span>${label}</span>
        <button class="filter-token__remove" data-type="${type}" data-value="${value}">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="3"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
      `;
      activeFiltersContainer.appendChild(token);
    };

    (state.advanced.category || []).forEach(v => addToken(`Category: ${v}`, 'category', v));
    (state.advanced.scope || []).forEach(v => addToken(`Scope: ${v}`, 'scope', v));
    (state.advanced.cert || []).forEach(v => addToken(v.charAt(0).toUpperCase() + v.slice(1), 'cert', v));
    if (state.advanced.price.min !== null || state.advanced.price.max !== null) {
      let priceLabel = 'Price: ';
      if (state.advanced.price.min && state.advanced.price.max) priceLabel += `${state.advanced.price.min} - ${state.advanced.price.max} EGP`;
      else if (state.advanced.price.min) priceLabel += `>${state.advanced.price.min} EGP`;
      else priceLabel += `<${state.advanced.price.max} EGP`;
      addToken(priceLabel, 'price', 'range');
    }

    if (filterCountBadge) {
      filterCountBadge.textContent = count;
      filterCountBadge.hidden = count === 0;
    }

    // Collapse the meta row entirely when there are no active filter tokens —
    // otherwise it renders as an empty divider strip.
    if (controlsMeta) controlsMeta.style.display = count > 0 ? '' : 'none';

    activeFiltersContainer.querySelectorAll('.filter-token__remove').forEach(btn => {
      btn.addEventListener('click', () => {
        removeSpecificFilter(btn.dataset.type, btn.dataset.value);
      });
    });
  }

  function removeSpecificFilter(type, value) {
    if (type === 'category') state.advanced.category = (state.advanced.category || []).filter(v => v !== value);
    if (type === 'scope') state.advanced.scope = (state.advanced.scope || []).filter(v => v !== value);
    if (type === 'cert') state.advanced.cert = (state.advanced.cert || []).filter(v => v !== value);
    if (type === 'price') { state.advanced.price.min = null; state.advanced.price.max = null; }

    syncFilterPanelToState();
    state.page = 1;
    applyFilters();
  }

  function syncFilterPanelToState() {
    if (!filterPanel) return;
    filterPanel.querySelectorAll('input[type="checkbox"]').forEach(cb => {
      const name = cb.name;
      const val = cb.value;
      if (name === 'category') cb.checked = (state.advanced.category || []).includes(val);
      if (name === 'scope') cb.checked = (state.advanced.scope || []).includes(val);
      if (name === 'cert') cb.checked = (state.advanced.cert || []).includes(val);
    });
    const minInput = document.getElementById('price-min');
    const maxInput = document.getElementById('price-max');
    if (minInput) minInput.value = state.advanced.price.min || '';
    if (maxInput) maxInput.value = state.advanced.price.max || '';
  }

  // ── Category-first browsing ───────────────────────────────────────────────
  const CATEGORY_DESCRIPTIONS = {
    plumbing:      'Pipes, drains, fixtures, and water heater services.',
    electrical:    'Wiring, panels, outlets, and safe electrical work.',
    hvac:          'AC installation, maintenance, and climate control.',
    cleaning:      'Deep cleaning, sanitizing, and move-in/out cleans.',
    painting:      'Interior and exterior painting with pro finishes.',
    carpentry:     'Custom woodwork, furniture, and door fitting.',
    flooring:      'Tile, hardwood, laminate, and floor restoration.',
    appliance:     'Repair and install washers, dryers, ovens, and more.',
    handyman:      'All-in-one fixes for everyday home maintenance.',
    renovation:    'Full room and property renovation projects.',
    drywall:       'Wall patching, plastering, and drywall installation.',
    roofing:       'Leak repair, shingle work, and full roof services.',
    'pest-control':'Safe elimination of insects, rodents, and pests.',
    landscaping:   'Lawn care, gardening, and outdoor space design.',
    installation:  'TV mounts, shelves, fixtures, and equipment setup.',
  };

  const CATEGORY_RESPONSE_TIMES = {
    plumbing: '~45 min', electrical: '~30 min', hvac: '~60 min',
    cleaning: '~20 min', painting: '~50 min', carpentry: '~70 min',
    flooring: '~90 min', appliance: '~40 min', roofing: '~120 min',
    landscaping: '~60 min', handyman: '~25 min', renovation: '~120 min',
    drywall: '~80 min', installation: '~35 min',
  };

  function generateCategoryCard(catKey, services, index = 0) {
    const label      = CATEGORY_LABELS[catKey] || catKey.charAt(0).toUpperCase() + catKey.slice(1);
    const count      = services.length;
    const prices     = services.map(s => s.basePrice).filter(Boolean);
    const minPrice   = prices.length ? Math.min(...prices) : 0;
    const priceStr   = minPrice > 0 ? `from <strong>${minPrice} EGP</strong>` : '<strong>On Request</strong>';
    const desc       = CATEGORY_DESCRIPTIONS[catKey] || 'Professional home services.';
    const responseTime = CATEGORY_RESPONSE_TIMES[catKey] || '~45 min';

    const iconClass = ['plumbing','hvac','electrical'].includes(catKey)
      ? 'product-card__icon--primary'
      : 'product-card__icon--secondary';

    const article = document.createElement('article');
    article.className = 'product-card smp-category-card';
    article.dataset.category = catKey;
    article.style.cursor = 'pointer';
    article.dataset.reveal = '';
    article.dataset.revealDelay = index * 60;

    article.innerHTML = `
      <div class="product-card__header">
        <div class="product-card__icon ${iconClass}">${CATEGORY_ICONS[catKey] || CATEGORY_ICONS.other}</div>
        <span class="product-card__tag tag--outline">${catKey.toUpperCase()}</span>
      </div>
      <h4 class="product-card__title">${label}</h4>
      <p class="product-card__desc">${desc}</p>
      
      <div class="product-card__metrics">
        <span class="metric-bubble">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="13" height="13" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="2" width="6" height="4" rx="1"/><path d="M7 6H5a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-2"/><path d="M9 12h6M9 16h4"/></svg>
          ${count} Services
        </span>
        <span class="metric-bubble">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          ${responseTime}
        </span>
      </div>

      <div class="product-card__footer">
        <span class="product-card__price">${priceStr}</span>
        <button class="product-card__action" type="button">Explore →</button>
      </div>
    `;

    article.addEventListener('click', () => {
      state.browseCategory = catKey;
      const url = new URL(window.location);
      url.searchParams.set('category', catKey);
      window.history.pushState({ category: catKey }, '', url);
      applyFilters();
      scrollMarketplaceToTop();
    });

    return article;
  }

  function renderCategoryGrid() {
    if (!resultsContainer) return;
    resultsContainer.innerHTML = '';
    resultsContainer.style.visibility = '';

    const catMap = {};
    (state.apiServices || []).forEach(svc => {
      const cat = (svc.category || 'other').toLowerCase();
      if (!catMap[cat]) catMap[cat] = [];
      catMap[cat].push(svc);
    });
    
    const totalCatCount = Object.keys(catMap).length;

    if (pagination) pagination.hidden = true;

    // Defined groups and ordering
    const categoryGroups = [
      {
        id: 'maintenance',
        title: 'Home Maintenance & Repair',
        i18n: 'smp_heading_maintenance',
        categories: ['plumbing', 'electrical', 'hvac', 'carpentry', 'appliance', 'handyman']
      },
      {
        id: 'improvement',
        title: '✨ Home Improvement & Finishing',
        i18n: 'smp_heading_improvement',
        categories: ['renovation', 'painting', 'flooring', 'drywall', 'roofing']
      },
      {
        id: 'specialty',
        title: '🌟 Specialized & Exterior Services',
        i18n: 'smp_heading_specialty',
        categories: ['pest-control', 'cleaning', 'landscaping', 'installation']
      }
    ];

    categoryGroups.forEach(group => {
      const activeCategories = group.categories.filter(cat => catMap[cat]);
      
      if (activeCategories.length > 0) {
        const groupDiv = document.createElement('div');
        groupDiv.className = 'category-group';
        groupDiv.dataset.group = group.id;

        const heading = document.createElement('h3');
        heading.className = 'category-heading';
        if (group.i18n) heading.dataset.i18n = group.i18n;
        heading.dataset.reveal = '';
        heading.textContent = group.title;

        const grid = document.createElement('div');
        grid.className = 'product-grid';

        activeCategories.forEach((catKey, index) => {
          grid.appendChild(generateCategoryCard(catKey, catMap[catKey], index));
          delete catMap[catKey]; // Remove so we know what's left
        });

        groupDiv.appendChild(heading);
        groupDiv.appendChild(grid);
        resultsContainer.appendChild(groupDiv);
      }
    });

    // Handle any leftover categories
    const leftoverKeys = Object.keys(catMap);
    if (leftoverKeys.length > 0) {
      const groupDiv = document.createElement('div');
      groupDiv.className = 'category-group';
      groupDiv.dataset.group = 'specialty';

      const heading = document.createElement('h3');
      heading.className = 'category-heading';
      heading.dataset.reveal = '';
      heading.textContent = 'Other Services';

      const grid = document.createElement('div');
      grid.className = 'product-grid';

      leftoverKeys.sort().forEach((catKey, index) => {
        grid.appendChild(generateCategoryCard(catKey, catMap[catKey], index));
      });

      groupDiv.appendChild(heading);
      groupDiv.appendChild(grid);
      resultsContainer.appendChild(groupDiv);
    }

    if (resultCount) animateCount(resultCount, totalCatCount);
    if (resultLabel) resultLabel.textContent = `categor${totalCatCount !== 1 ? 'ies' : 'y'} available`;

    updateFilterTokens();

    setTimeout(() => {
      if (typeof window.initScrollReveal === 'function') {
        window.initScrollReveal();
      } else {
        document.querySelectorAll('[data-reveal]').forEach(el => el.classList.add('is-visible'));
      }
    }, 50);
  }

  function renderCategoryServices(catKey) {
    if (!resultsContainer) return;
    resultsContainer.innerHTML = '';
    resultsContainer.style.visibility = '';

    const label = CATEGORY_LABELS[catKey] || catKey.charAt(0).toUpperCase() + catKey.slice(1);

    const header = document.createElement('div');
    header.className = 'cat-browse-header';
    header.innerHTML = `
      <button type="button" class="cat-back-btn" id="catBackBtn">
        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
        <span data-i18n="smp_all_categories">All Categories</span>
      </button>
      <svg class="cat-browse-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
      <span class="cat-browse-current">
        <span class="cat-browse-icon">${CATEGORY_ICONS[catKey] || CATEGORY_ICONS.other}</span>
        <h3 class="cat-browse-title">${label}</h3>
      </span>
    `;
    resultsContainer.appendChild(header);

    document.getElementById('catBackBtn').addEventListener('click', () => {
      state.browseCategory = null;
      const url = new URL(window.location);
      url.searchParams.delete('category');
      window.history.pushState({ category: null }, '', url);
      applyFilters();
      scrollMarketplaceToTop();
    });

    // Search + advanced filters stay SCOPED to this category instead of
    // bouncing the user back to the full catalogue.
    const services = (state.apiServices || []).filter(svc => {
      if ((svc.category || '').toLowerCase() !== catKey) return false;

      const title = (svc.title || '').toLowerCase();
      const desc  = (svc.description || svc.desc || '').toLowerCase();
      if (state.query && !title.includes(state.query) && !desc.includes(state.query)) return false;

      const adv = state.advanced;
      if (adv.scope && adv.scope.length > 0 && svc.scope && !adv.scope.includes(svc.scope)) return false;
      if (adv.cert && adv.cert.length > 0 && svc.cert && !adv.cert.includes(svc.cert)) return false;
      if (adv.price.min !== null && svc.basePrice < adv.price.min) return false;
      if (adv.price.max !== null && svc.basePrice > adv.price.max) return false;
      return true;
    });

    if (pagination) pagination.hidden = true;

    const total = services.length;
    if (total === 0) {
      resultsContainer.appendChild(emptyState);
      emptyState.classList.add('is-visible');
    } else {
      emptyState.classList.remove('is-visible');
      const grid = document.createElement('div');
      grid.className = 'product-grid';
      if (state.view === 'list') grid.classList.add('is-list-view');
      services.forEach((svc, index) => grid.appendChild(generateServiceCard(svc, index)));
      grid.appendChild(generateDescribeCard(catKey, services.length));
      resultsContainer.appendChild(grid);
    }

    if (resultCount) animateCount(resultCount, total);
    if (resultLabel) resultLabel.textContent = `service${total !== 1 ? 's' : ''} in ${label}`;

    updateFilterTokens();

    setTimeout(() => {
      if (typeof window.initScrollReveal === 'function') {
        window.initScrollReveal();
      } else {
        document.querySelectorAll('[data-reveal]').forEach(el => el.classList.add('is-visible'));
      }
      if (typeof window.translatePage === 'function') window.translatePage();
    }, 50);
  }

  // ── Main Filter Application ────────────────────────────────────────────────
  function applyFilters() {
    const hasAdvancedFilters = (state.advanced.category && state.advanced.category.length > 0)
      || (state.advanced.scope && state.advanced.scope.length > 0)
      || (state.advanced.cert && state.advanced.cert.length > 0)
      || state.advanced.price.min !== null
      || state.advanced.price.max !== null;
    const isFiltering = state.query !== '' || state.filter !== 'all' || hasAdvancedFilters;

    // Only a MACRO category pill (Maintenance/Improvement/Specialty) switches
    // context out of a drill-down. Search + advanced filters stay scoped to the
    // category the user is browsing.
    if (state.filter !== 'all') state.browseCategory = null;

    // Collapse the whole secondary controls row while drilled into one category —
    // the macro pills belong to top-level browsing, and a lone toggle bar just
    // leaves a barren empty band.
    if (controlsSecondary) controlsSecondary.style.display = state.browseCategory ? 'none' : '';

    if (featuredSection) featuredSection.style.display = (isFiltering || state.browseCategory) ? 'none' : '';

    // Inside a category: render it (scoped by search/advanced filters).
    if (state.browseCategory) {
      renderCategoryServices(state.browseCategory);
      return;
    }

    // No category context and nothing filtering → show the category grid.
    if (!isFiltering) {
      renderCategoryGrid();
      return;
    }

    const filtered = (state.apiServices || []).filter(svc => {
      const title = (svc.title || '').toLowerCase();
      const desc = (svc.description || svc.desc || '').toLowerCase();
      const category = (svc.category || '').toLowerCase();

      const matchesSearch = !state.query || title.includes(state.query) || desc.includes(state.query);
      
      // Map frontend filter chips to backend categories
      let matchesFilter = state.filter === 'all';
      if (!matchesFilter) {
        if (state.filter === 'maintenance') {
          matchesFilter = ['plumbing', 'electrical', 'cleaning', 'hvac'].includes(category);
        } else if (state.filter === 'improvement') {
          matchesFilter = ['painting', 'flooring', 'carpentry'].includes(category);
        } else if (state.filter === 'specialty') {
          matchesFilter = ['other'].includes(category);
        } else {
          matchesFilter = category === state.filter;
        }
      }

      let matchesAdvanced = true;
      if (state.advanced.category && state.advanced.category.length > 0 && !state.advanced.category.includes(category)) matchesAdvanced = false;
      if (matchesAdvanced && state.advanced.scope && state.advanced.scope.length > 0 && svc.scope && !state.advanced.scope.includes(svc.scope)) matchesAdvanced = false;
      if (matchesAdvanced && state.advanced.cert && state.advanced.cert.length > 0 && svc.cert && !state.advanced.cert.includes(svc.cert)) matchesAdvanced = false;
      if (matchesAdvanced && state.advanced.price.min !== null && svc.basePrice < state.advanced.price.min) matchesAdvanced = false;
      if (matchesAdvanced && state.advanced.price.max !== null && svc.basePrice > state.advanced.price.max) matchesAdvanced = false;

      return matchesSearch && matchesFilter && matchesAdvanced;
    });

    const ordered = sortServices(filtered);
    const total = ordered.length;
    const totalPages = Math.ceil(total / PAGE_SIZE);
    state.page = totalPages > 0 ? Math.min(state.page, totalPages) : 1;

    const pageStart = (state.page - 1) * PAGE_SIZE;
    const pageItems = ordered.slice(pageStart, pageStart + PAGE_SIZE);

    // Clear and render groups
    if (resultsContainer) {
      resultsContainer.innerHTML = '';
      resultsContainer.style.visibility = '';
      
      if (pageItems.length === 0) {
        resultsContainer.appendChild(emptyState);
        emptyState.classList.add('is-visible');
      } else {
        emptyState.classList.remove('is-visible');
        
        // Group by category for visual grouping
        const groups = {};
        const masterGroupMap = {
          plumbing: 'maintenance',
          electrical: 'maintenance',
          hvac: 'maintenance',
          cleaning: 'maintenance',
          painting: 'improvement',
          flooring: 'improvement',
          carpentry: 'improvement',
          specialty: 'specialty',
          other: 'specialty'
        };

        pageItems.forEach(svc => {
          const master = masterGroupMap[svc.category.toLowerCase()] || 'specialty';
          if (!groups[master]) groups[master] = { label: master, services: [] };
          groups[master].services.push(svc);
        });

        Object.keys(groups).forEach(master => {
          const groupDiv = document.createElement('div');
          groupDiv.className = 'category-group';
          groupDiv.dataset.group = master;
          
          const heading = document.createElement('h3');
          heading.className = 'category-heading';
          heading.dataset.i18n = `smp_heading_${master}`;
          
          // Better labeling
          const labels = {
            maintenance: 'Home Maintenance & Repair',
            improvement: 'Home Improvement & Restoration',
            specialty: 'Specialized Property Services'
          };
          heading.textContent = labels[master] || master.toUpperCase();
          
          const grid = document.createElement('div');
          grid.className = 'product-grid';
          if (state.view === 'list') grid.classList.add('is-list-view');
          
          groups[master].services.forEach((svc, index) => {
            grid.appendChild(generateServiceCard(svc, index));
          });
          
          groupDiv.appendChild(heading);
          groupDiv.appendChild(grid);
          resultsContainer.appendChild(groupDiv);
        });
      }
    }

    if (resultCount) animateCount(resultCount, total);
    if (resultLabel) {
      resultLabel.textContent = isFiltering ? `service${total === 1 ? '' : 's'} found` : `service${total === 1 ? '' : 's'} available`;
    }

    renderPagination(total);
    updateFilterTokens();
    
    // Re-trigger animations and translations for new cards with a slight delay
    setTimeout(() => {
      if (typeof window.initScrollReveal === 'function') {
        window.initScrollReveal();
      } else {
        document.querySelectorAll('[data-reveal]').forEach(el => el.classList.add('is-visible'));
      }
    }, 50);
    
    if (typeof window.translatePage === 'function') window.translatePage();
  }


  // ── Event Handlers ────────────────────────────────────────────────────────
  
  // Custom Sort Dropdown
  if (sortTrigger) {
    sortTrigger.addEventListener('click', () => toggleDropdown(sortDropdown));
  }

  sortDropdown?.querySelectorAll('.dropdown-item').forEach(item => {
    item.addEventListener('click', () => {
      const val = item.dataset.value;
      state.sort = val;
      if (currentSortVal) currentSortVal.textContent = item.textContent;
      
      sortDropdown.querySelectorAll('.dropdown-item').forEach(i => i.setAttribute('aria-selected', 'false'));
      item.setAttribute('aria-selected', 'true');
      
      toggleDropdown(sortDropdown, false);
      state.page = 1;
      applyFilters();
    });
  });

  // Advanced Filter Panel
  if (moreFiltersBtn) {
    moreFiltersBtn.addEventListener('click', () => {
      const isVisible = filterPanel.getAttribute('data-visible') === 'true';
      filterPanel.setAttribute('data-visible', !isVisible);
      moreFiltersBtn.classList.toggle('is-active', !isVisible);
    });
  }

  if (closeFiltersBtn) {
    closeFiltersBtn.addEventListener('click', () => {
      filterPanel.setAttribute('data-visible', 'false');
      moreFiltersBtn.classList.remove('is-active');
    });
  }

  // Radio-like buttons for Rating
  filterPanel?.querySelectorAll('.filter-radio-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const name = btn.dataset.name;
      const val = btn.dataset.value;
      if (state.advanced[name] === val) {
        state.advanced[name] = null; // Toggle off
      } else {
        state.advanced[name] = val;
      }
      syncFilterPanelToState();
    });
  });

  if (applyFiltersBtn) {
    applyFiltersBtn.addEventListener('click', () => {
      // Capture checkbox states
      state.advanced.category = Array.from(filterPanel.querySelectorAll('input[name="category"]:checked')).map(cb => cb.value);
      state.advanced.scope = Array.from(filterPanel.querySelectorAll('input[name="scope"]:checked')).map(cb => cb.value);
      state.advanced.cert = Array.from(filterPanel.querySelectorAll('input[name="cert"]:checked')).map(cb => cb.value);
      
      // Capture price range
      const minVal = document.getElementById('price-min')?.value;
      const maxVal = document.getElementById('price-max')?.value;
      state.advanced.price.min = minVal ? parseFloat(minVal) : null;
      state.advanced.price.max = maxVal ? parseFloat(maxVal) : null;

      filterPanel.setAttribute('data-visible', 'false');
      moreFiltersBtn.classList.remove('is-active');
      state.page = 1;
      applyFilters();
    });
  }

  if (resetFiltersBtn) {
    resetFiltersBtn.addEventListener('click', () => {
      state.advanced = { category: [], scope: [], cert: [], price: { min: null, max: null } };
      syncFilterPanelToState();
      state.page = 1;
      applyFilters();
    });
  }

  // Search
  if (searchInput) {
    searchInput.addEventListener('input', e => {
      state.query = e.target.value.toLowerCase().trim();
      if (searchClear) searchClear.hidden = !state.query;
      state.page = 1;
      applyFilters();
    });
  }

  if (searchClear) {
    searchClear.addEventListener('click', () => {
      if (searchInput) { searchInput.value = ''; searchInput.focus(); }
      state.query = '';
      searchClear.hidden = true;
      state.page = 1;
      applyFilters();
    });
  }

  // Category Filter Chips
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('filter-chip--active'));
      btn.classList.add('filter-chip--active');
      state.filter = btn.getAttribute('data-filter');
      state.page = 1;
      applyFilters();
    });
  });

  // View Toggles
  viewToggles.forEach(btn => {
    btn.addEventListener('click', () => {
      viewToggles.forEach(b => b.classList.remove('view-toggle-btn--active'));
      btn.classList.add('view-toggle-btn--active');
      state.view = btn.dataset.view;
      document.querySelectorAll('.product-grid').forEach(grid => {
        grid.classList.toggle('is-list-view', state.view === 'list');
      });
    });
  });

  // Reset Everything
  if (resetBtn) {
    resetBtn.addEventListener('click', () => {
      if (searchInput) searchInput.value = '';
      state.query = '';
      state.filter = 'all';
      state.sort = 'featured';
      state.page = 1;
      state.advanced = { category: [], scope: [], cert: [], price: { min: null, max: null } };
      
      filterBtns.forEach(b => b.classList.remove('filter-chip--active'));
      document.querySelector('.filter-chip[data-filter="all"]')?.classList.add('filter-chip--active');
      if (currentSortVal) currentSortVal.textContent = 'Featured';
      
      syncFilterPanelToState();
      applyFilters();
    });
  }

  paginationPages?.addEventListener('click', event => {
    const target = event.target.closest('[data-page]');
    if (!target) return;
    const nextPage = Number(target.dataset.page);
    if (!nextPage || nextPage === state.page) return;
    state.page = nextPage;
    applyFilters();
    scrollMarketplaceToTop();
  });

  paginationPrev?.addEventListener('click', () => {
    if (paginationPrev.disabled || state.page <= 1) return;
    state.page -= 1;
    applyFilters();
    scrollMarketplaceToTop();
  });

  paginationNext?.addEventListener('click', () => {
    if (paginationNext.disabled) return;
    state.page += 1;
    applyFilters();
    scrollMarketplaceToTop();
  });

  // Pre-fill from URL
  const urlParams = new URLSearchParams(window.location.search);
  const urlQuery = urlParams.get('q');
  if (urlQuery && searchInput) {
    searchInput.value = urlQuery;
    state.query = urlQuery.toLowerCase().trim();
    if (searchClear) searchClear.hidden = false;
  }
  
  const urlCategory = urlParams.get('category');
  if (urlCategory) {
    state.browseCategory = urlCategory.toLowerCase();
  }

  // Handle Browser Back/Forward
  window.addEventListener('popstate', (e) => {
    const params = new URLSearchParams(window.location.search);
    const cat = params.get('category');
    state.browseCategory = cat;
    applyFilters();
  });

  // Init
  fetchServices();
});
