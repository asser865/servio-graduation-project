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
      plumbing:   { label: 'Emergency Ready', labelAr: 'جاهز للطوارئ',  cls: 'tag--danger',    i18n: 'badge_emergency_ready' },
      electrical: { label: 'Licensed Pro',    labelAr: 'محترف مرخّص',    cls: 'tag--secondary', i18n: 'badge_licensed_pro'    },
      hvac:       { label: 'Climate Expert',  labelAr: 'خبير مناخي',     cls: 'tag--secondary', i18n: 'badge_climate_expert'  },
      cleaning:   { label: 'Deep Clean Pro',  labelAr: 'تنظيف عميق',     cls: 'tag--success',   i18n: 'badge_deep_clean'      },
      painting:   { label: 'Master Finish',   labelAr: 'دهان محترف',     cls: 'tag--paint',     i18n: 'badge_master_finish'   },
      carpentry:  { label: 'Custom Craft',    labelAr: 'نجارة مخصصة',    cls: 'tag--wood',      i18n: 'badge_custom_craft'    },
      flooring:   { label: 'Floor Expert',    labelAr: 'خبير أرضيات',    cls: 'tag--outline',   i18n: 'badge_floor_expert'    },
      other:      { label: 'Specialist',      labelAr: 'متخصص',          cls: 'tag--outline',   i18n: 'badge_specialist'      },
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
      plumbing:   `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"/><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"/></svg>`,
      electrical: `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>`,
      hvac:       `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12h20"/><path d="M12 2v20"/><path d="m20 16-4-4 4-4"/><path d="m4 8 4 4-4 4"/><path d="m16 4-4 4-4-4"/><path d="m8 20 4-4 4 4"/></svg>`,
      cleaning:   `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4.5 8-11.8A8 8 0 0 0 12 2a8 8 0 0 0-8 8.2c0 7.3 8 11.8 8 11.8z"/><circle cx="12" cy="10" r="3"/></svg>`,
      painting:   `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>`,
      carpentry:  `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"/></svg>`,
      flooring:   `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/></svg>`,
      other:      `<svg width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>`,
    };

    const iconClass = ['plumbing','hvac','electrical'].includes(category)
      ? 'product-card__icon--primary'
      : 'product-card__icon--secondary';

    const { primary, secondary } = resolveServiceBadges(svc);
    const primaryLabel    = isAr ? primary.labelAr    : primary.label;
    const secondaryLabel  = secondary ? (isAr ? secondary.labelAr : secondary.label) : null;

    const priceUnitMeta = {
      per_hour: { en: '/hr',  ar: '/ساعة', prefixEn: 'From ', prefixAr: 'من ' },
      per_sqm:  { en: '/m²',  ar: '/م²',   prefixEn: 'From ', prefixAr: 'من ' },
      fixed:    { en: 'flat', ar: 'ثابت',  prefixEn: '',      prefixAr: ''    },
    };
    const priceMeta = priceUnitMeta[svc.priceUnit] || priceUnitMeta.fixed;
    const priceText = isAr
      ? `<span class="price-amount">${priceMeta.prefixAr}${svc.basePrice || 0} ج.م</span><span class="price-unit">${priceMeta.ar}</span>`
      : `<span class="price-amount">${priceMeta.prefixEn}${svc.basePrice || 0} EGP</span><span class="price-unit">${priceMeta.en}</span>`;

    const rating  = parseFloat(svc.averageRating) || 0;
    const reviews = parseInt(svc.totalReviews)    || 0;
    const ratingBubble = rating > 0
      ? `<span class="metric-bubble metric-bubble--rating" aria-label="Rating ${rating.toFixed(1)}">
           <svg viewBox="0 0 24 24" fill="currentColor" width="13" height="13"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
           <strong>${rating.toFixed(1)}</strong>${reviews > 0 ? `<span class="rating-count">(${reviews})</span>` : ''}
         </span>`
      : '';

    const article = document.createElement('article');
    article.className = 'product-card';
    article.dataset.id       = svc._id;
    article.dataset.category = category;
    article.dataset.rating   = svc.averageRating || '0';
    article.dataset.price    = svc.basePrice || 0;
    article.style.cursor     = 'pointer';
    article.dataset.reveal   = '';

    article.innerHTML = `
      <div class="product-card__header">
        <div class="product-card__icon ${iconClass}">${icons[category] || icons.other}</div>
        <div class="product-card__tags">
          <span class="product-card__tag ${primary.cls}" data-i18n="${primary.i18n}">${primaryLabel}</span>
          ${secondaryLabel ? `<span class="product-card__tag ${secondary.cls}" data-i18n="${secondary.i18n}">${secondaryLabel}</span>` : ''}
        </div>
      </div>
      <h4 class="product-card__title" data-i18n="${nameKey}">${displayTitle}</h4>
      <p class="product-card__desc" data-i18n="${descKey}">${svc.description || ''}</p>
      <div class="product-card__metrics">
        <span class="metric-bubble" aria-label="Instant Booking">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
          <strong data-i18n="smp_instant">Instant</strong>
        </span>
        ${ratingBubble}
        <span class="metric-bubble" aria-label="Price" style="flex: 1; justify-content: center;">
          ${priceText}
        </span>
      </div>
      <div class="product-card__footer">
        <a class="product-card__action" href="./service-details.html?service=${category}">
          <span data-i18n="smp_view_techs">View Technicians →</span>
        </a>
      </div>
    `;

    article.addEventListener('click', e => {
      if (e.target.closest('a')) return;
      window.location.href = `./service-details.html?service=${category}`;
    });

    return article;
  }

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


