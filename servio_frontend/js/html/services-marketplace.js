import { getServices } from '../api/services.js';
import { initScrollReveal } from '../components/scroll-reveal.js';

document.addEventListener('DOMContentLoaded', () => {
  // ── DOM refs ──────────────────────────────────────────────────────────────
  const searchInput      = document.getElementById('service-search');
  const searchClear      = document.getElementById('serviceSearchClear');
  const filterBtns       = document.querySelectorAll('.filter-chip[data-filter]');
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

  // ── Drawer Refs ───────────────────────────────────────────────────────────
  const svcDrawerOverlay      = document.getElementById('svcDrawerOverlay');
  const svcDrawer             = document.getElementById('svcDrawer');
  const svcDrawerClose        = document.getElementById('svcDrawerClose');
  const svcDrawerTopbar       = document.getElementById('svcDrawerTopbar');
  const svcDrawerTopbarTitle  = document.getElementById('svcDrawerTopbarTitle');
  const svcDrawerTopbarEyebrow = document.getElementById('svcDrawerTopbarEyebrow');
  const svcDrawerTopbarIcon   = document.getElementById('svcDrawerTopbarIcon');
  const svcDrawerScroller     = document.getElementById('svcDrawerScroller');
  const svcDrawerImg          = document.getElementById('svcDrawerImg');
  const svcDrawerCategory     = document.getElementById('svcDrawerCategory');
  const svcDrawerTitle        = document.getElementById('svcDrawerTitle');
  const svcDrawerStats        = document.getElementById('svcDrawerStats');
  const svcDrawerFeatures     = document.getElementById('svcDrawerFeatures');
  const svcDrawerPricing      = document.getElementById('svcDrawerPricing');
  const svcDrawerReviewText   = document.getElementById('svcDrawerReviewText');
  const svcDrawerReviewerName = document.getElementById('svcDrawerReviewerName');
  const svcDrawerAvatar       = document.getElementById('svcDrawerAvatar');
  const svcDrawerCta          = document.getElementById('svcDrawerCta');

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
    advanced: {
      category: [],
      scope: [],
      cert: [],
      price: { min: null, max: null }
    },
    apiServices: [] // Full list from API
  };
  const PAGE_SIZE = 6;

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
    const isNew    = svc.createdAt
      ? (Date.now() - new Date(svc.createdAt).getTime()) < 30 * 24 * 60 * 60 * 1000
      : false;

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
    } else if (isNew) {
      secondary = { label: 'New',       labelAr: 'جديد',           cls: 'tag--new',     i18n: 'badge_new'             };
    } else if (svc.priceUnit === 'fixed') {
      secondary = { label: 'Fixed Price', labelAr: 'سعر ثابت',     cls: 'tag--outline', i18n: 'badge_fixed_price'     };
    } else if (price > 0 && price <= 80) {
      secondary = { label: 'Budget Friendly', labelAr: 'اقتصادي',  cls: 'tag--outline', i18n: 'badge_budget_friendly' };
    } else if (price > 300) {
      secondary = { label: 'Premium',  labelAr: 'بريميوم',         cls: 'tag--secondary',i18n: 'badge_premium'        };
    }

    return { primary, secondary };
  }

  function generateServiceCard(svc) {
    const title    = svc.title || 'Untitled Service';
    const category = (svc.category || 'other').toLowerCase();
    const isAr     = (window.__lang || document.documentElement.lang) === 'ar';

    const displayTitle = title.charAt(0).toUpperCase() + title.slice(1);
    const nameKey      = 'svc_' + title.toLowerCase().replace(/ /g, '_');
    const descKey      = nameKey + '_desc';

    const icons = {
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

    const iconClass = ['plumbing','hvac','electrical'].includes(category)
      ? 'product-card__icon--primary'
      : 'product-card__icon--secondary';

    const price     = svc.basePrice || 0;
    const priceUnit = { per_hour: '/hr', per_sqm: '/m²', fixed: '' }[svc.priceUnit] || '';

    const rating  = parseFloat(svc.averageRating) || 0;
    const reviews = parseInt(svc.totalReviews)    || 0;

    const article = document.createElement('article');
    article.className = 'product-card';
    article.dataset.id       = svc._id;
    article.dataset.category = category;
    article.dataset.rating   = svc.averageRating || '0';
    article.dataset.price    = svc.basePrice || 0;
    article.style.cursor     = 'pointer';
    article.dataset.reveal   = '';

    const responseTime = {
      plumbing: '~45 min', electrical: '~30 min', hvac: '~60 min',
      cleaning: '~20 min', painting: '~50 min', carpentry: '~70 min',
      flooring: '~90 min', appliance: '~40 min', roofing: '~120 min',
      landscaping: '~60 min', handyman: '~25 min', renovation: '~120 min',
      drywall: '~80 min', installation: '~35 min',
    }[category] || '~45 min';

    const ratingHtml = rating > 0
      ? `<span class="product-card__rating" aria-label="Rating ${rating.toFixed(1)}">
           <svg viewBox="0 0 24 24" fill="currentColor" width="13" height="13"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
           ${rating.toFixed(1)}<span class="product-card__rating-count">${reviews > 0 ? ` (${reviews})` : ''}</span>
         </span>`
      : '';

    const priceLabel = price > 0
      ? `from <strong>${price} EGP${priceUnit}</strong>`
      : '<strong>On Request</strong>';

    article.innerHTML = `
      <div class="product-card__icon ${iconClass}">${icons[category] || icons.other}</div>
      <h4 class="product-card__title" data-i18n="${nameKey}">${displayTitle}</h4>
      <p class="product-card__desc" data-i18n="${descKey}">${svc.description || ''}</p>
      <div class="product-card__info">
        ${ratingHtml}
        <span class="product-card__response">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="13" height="13"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          ${responseTime}
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

  const DRAWER_REVIEWS = {
    plumbing:   { text: 'Fixed our burst pipe within an hour. Incredibly professional and transparent pricing — no surprises.', reviewer: 'Sara M.', avatarId: 12 },
    electrical: { text: 'Had our entire kitchen rewired safely and on time. Explained every step clearly — highly recommend.', reviewer: 'Karim A.', avatarId: 33 },
    hvac:       { text: 'Diagnosed and fixed our AC in under 2 hours during the hottest week of summer. Lifesavers!', reviewer: 'Nour H.', avatarId: 47 },
    cleaning:   { text: 'Transformed our apartment before move-in. Every surface spotless — even cleaned inside the cabinets.', reviewer: 'Dina F.', avatarId: 21 },
    painting:   { text: 'Clean lines, no mess, perfect finish. The color consultation alone was worth it.', reviewer: 'Omar T.', avatarId: 68 },
    carpentry:  { text: 'Built us a stunning custom bookcase. Precise craftsmanship and a great eye for detail.', reviewer: 'Layla R.', avatarId: 56 },
    default:    { text: 'Outstanding work from start to finish. Punctual, professional, and genuinely quality service.', reviewer: 'Ahmed K.', avatarId: 15 },
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
    const rating    = parseFloat(svc.averageRating) || 0;
    const reviews   = parseInt(svc.totalReviews) || 0;
    const price     = svc.basePrice || 0;
    const priceUnit = svc.priceUnit === 'per_hour' ? '/hr' : svc.priceUnit === 'per_sqm' ? '/m²' : '';

    svcDrawerImg.src          = DRAWER_HERO_IMGS[category] || DRAWER_HERO_IMGS.default;
    svcDrawerImg.alt          = title;
    svcDrawerCategory.textContent = (svc.category || 'Service').charAt(0).toUpperCase() + (svc.category || 'Service').slice(1) + ' Service';
    svcDrawerTitle.textContent    = title;

    svcDrawerStats.innerHTML = [
      { icon: '★', value: rating > 0 ? rating.toFixed(1) : '—', label: 'Rating' },
      { icon: '💬', value: reviews > 0 ? reviews : '—', label: 'Reviews' },
      { icon: '💰', value: price > 0 ? `${price} EGP${priceUnit}` : '—', label: 'Starting From' },
    ].map(s => `
      <div class="svc-drawer__stat">
        <div class="svc-drawer__stat-icon">${s.icon}</div>
        <div class="svc-drawer__stat-value">${s.value}</div>
        <div class="svc-drawer__stat-label">${s.label}</div>
      </div>
    `).join('');

    const features = DRAWER_FEATURES[category] || DRAWER_FEATURES.default;
    svcDrawerFeatures.innerHTML = features.map(f => `
      <div class="svc-drawer__feature-row">
        <span class="svc-drawer__feature-check">
          <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"/></svg>
        </span>
        ${f}
      </div>
    `).join('');

    const base = price || 50;
    svcDrawerPricing.innerHTML = [
      { tier: 'Basic',    amount: base,              unit: priceUnit, desc: 'Minor repairs & fixes' },
      { tier: 'Standard', amount: Math.round(base * 1.4), unit: priceUnit, desc: 'Installations & overhauls', featured: true },
      { tier: 'Premium',  amount: Math.round(base * 2),   unit: priceUnit, desc: 'Full renovation scope' },
    ].map(p => `
      <div class="svc-drawer__price-card${p.featured ? ' is-featured' : ''}">
        <div class="svc-drawer__price-tier">${p.tier}</div>
        <div class="svc-drawer__price-amount">${p.amount} EGP<sub>${p.unit}</sub></div>
        <div class="svc-drawer__price-desc">${p.desc}</div>
      </div>
    `).join('');

    const rev = DRAWER_REVIEWS[category] || DRAWER_REVIEWS.default;
    svcDrawerReviewText.textContent   = rev.text;
    svcDrawerReviewerName.textContent = rev.reviewer;
    svcDrawerAvatar.src = `https://i.pravatar.cc/68?img=${rev.avatarId}`;

    if (svcDrawerCta) svcDrawerCta.href = `./technician-listing.html?service=${category}`;

    // Reset scroll-collapse state
    if (svcDrawerImg)         svcDrawerImg.style.transform = 'scale(1.08) translateY(0)';
    if (svcDrawerTopbar)      svcDrawerTopbar.classList.remove('is-solid');
    if (svcDrawerTopbarTitle) svcDrawerTopbarTitle.textContent = title;
    if (svcDrawerTopbarEyebrow) {
      const cat = (svc.category || 'service');
      svcDrawerTopbarEyebrow.textContent = cat.charAt(0).toUpperCase() + cat.slice(1) + ' · SERVIO';
    }
    if (svcDrawerTopbarIcon) {
      const TOPBAR_ICONS = {
        plumbing:    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"/><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"/></svg>`,
        electrical:  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>`,
        hvac:        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h20"/><path d="M12 2v20"/><path d="m20 16-4-4 4-4"/><path d="m4 8 4 4-4 4"/><path d="m16 4-4 4-4-4"/><path d="m8 20 4-4 4 4"/></svg>`,
        cleaning:    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/></svg>`,
        painting:    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>`,
        carpentry:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"/></svg>`,
        flooring:    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/></svg>`,
        appliance:   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="20" x="3" y="2" rx="2"/><circle cx="12" cy="13" r="5"/><path d="M6 6h.01"/><path d="M9 6h.01"/></svg>`,
        handyman:    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`,
        renovation:  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>`,
        roofing:     `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7"/><path d="M3 9v13h18V9"/><path d="M9 22V12h6v10"/></svg>`,
        landscaping: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22v-7l-2-2"/><path d="M17 8v.8A6 6 0 0 1 13.8 20v0H10v0A6.5 6.5 0 0 1 7 8h0a5 5 0 0 1 10 0z"/><path d="m14 14-2 2-2-2"/></svg>`,
        installation:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>`,
      };
      svcDrawerTopbarIcon.innerHTML = TOPBAR_ICONS[category] || `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`;
    }
    if (svcDrawerScroller)    svcDrawerScroller.scrollTop = 0;
    svcDrawerScroller?.addEventListener('scroll', handleDrawerScroll);

    svcDrawerOverlay?.classList.add('is-open');
    svcDrawer.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    document.querySelector('[data-chat-fab]')?.style.setProperty('display', 'none');
  }

  function closeServiceDrawer() {
    svcDrawerOverlay?.classList.remove('is-open');
    svcDrawer?.classList.remove('is-open');
    document.body.style.overflow = '';
    document.querySelector('[data-chat-fab]')?.style.removeProperty('display');
    svcDrawerScroller?.removeEventListener('scroll', handleDrawerScroll);
  }

  // ── Drawer Hero Parallax on Scroll (GPU-only, zero reflow) ───────────────
  function handleDrawerScroll() {
    if (!svcDrawerScroller || !svcDrawerImg || !svcDrawerTopbar) return;
    const scrollY = svcDrawerScroller.scrollTop;
    svcDrawerImg.style.transform = `scale(1.08) translateY(${scrollY * 0.25}px)`;
    svcDrawerTopbar.classList.toggle('is-solid', scrollY > 140);
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

  // ── Main Filter Application ────────────────────────────────────────────────
  function applyFilters() {
    const hasAdvancedFilters = (state.advanced.category && state.advanced.category.length > 0)
      || (state.advanced.scope && state.advanced.scope.length > 0)
      || (state.advanced.cert && state.advanced.cert.length > 0)
      || state.advanced.price.min !== null
      || state.advanced.price.max !== null;
    const isFiltering = state.query !== '' || state.filter !== 'all' || hasAdvancedFilters;

    if (featuredSection) featuredSection.style.display = isFiltering ? 'none' : '';

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
          
          groups[master].services.forEach(svc => {
            grid.appendChild(generateServiceCard(svc));
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
  const urlQuery = new URLSearchParams(window.location.search).get('q');
  if (urlQuery && searchInput) {
    searchInput.value = urlQuery;
    state.query = urlQuery.toLowerCase().trim();
    if (searchClear) searchClear.hidden = false;
  }

  // Init
  fetchServices();
});


