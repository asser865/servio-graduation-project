/**
 * services-marketplace.js
 * Search, category filter, sort, result count, empty state — fully interactive
 */

document.addEventListener('DOMContentLoaded', () => {
  // ── DOM refs ──────────────────────────────────────────────────────────────
  const searchInput      = document.getElementById('service-search');
  const searchClear      = document.getElementById('serviceSearchClear');
  const filterBtns       = document.querySelectorAll('.filter-chip[data-filter]');
  const productCards     = document.querySelectorAll('.product-card');
  const categoryGroups   = document.querySelectorAll('.category-group');
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
      availability: [],
      rating: null,
      badges: [],
      price: { min: null, max: null },
      details: []
    }
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

  // ── Sorting Logic ─────────────────────────────────────────────────────────
  function sortCards(cards) {
    const list = [...cards];
    if (state.sort === 'featured') return list;
    
    return list.sort((a, b) => {
      const titleA = (a.querySelector('.product-card__title')?.textContent || '').toLowerCase();
      const titleB = (b.querySelector('.product-card__title')?.textContent || '').toLowerCase();
      
      switch(state.sort) {
        case 'price_low': return 100 - 200; // Mock price logic
        case 'price_high': return 200 - 100;
        case 'top_rated': return -1; // Mock rating logic
        default: return titleA.localeCompare(titleB);
      }
    });
  }

  // ── Filter Tokens Logic ───────────────────────────────────────────────────
  function updateFilterTokens() {
    if (!activeFiltersContainer) return;
    activeFiltersContainer.innerHTML = '';
    let count = 0;

    // Helper to add token
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

    // Availability
    state.advanced.availability.forEach(v => addToken(`Availability: ${v}`, 'availability', v));
    // Badges
    state.advanced.badges.forEach(v => addToken(v.charAt(0).toUpperCase() + v.slice(1), 'badge', v));
    // Rating
    if (state.advanced.rating) addToken(`${state.advanced.rating}+ Stars`, 'rating', state.advanced.rating);
    // Price
    if (state.advanced.price.min !== null || state.advanced.price.max !== null) {
      let priceLabel = 'Price: ';
      if (state.advanced.price.min && state.advanced.price.max) priceLabel += `${state.advanced.price.min} - ${state.advanced.price.max} EGP`;
      else if (state.advanced.price.min) priceLabel += `>${state.advanced.price.min} EGP`;
      else priceLabel += `<${state.advanced.price.max} EGP`;
      addToken(priceLabel, 'price', 'range');
    }
    
    // Update badge
    if (filterCountBadge) {
      filterCountBadge.textContent = count;
      filterCountBadge.hidden = count === 0;
    }

    // Token removal listeners
    activeFiltersContainer.querySelectorAll('.filter-token__remove').forEach(btn => {
      btn.addEventListener('click', () => {
        removeSpecificFilter(btn.dataset.type, btn.dataset.value);
      });
    });
  }

  function removeSpecificFilter(type, value) {
    if (type === 'availability') state.advanced.availability = state.advanced.availability.filter(v => v !== value);
    if (type === 'badge') state.advanced.badges = state.advanced.badges.filter(v => v !== value);
    if (type === 'rating') state.advanced.rating = null;
    if (type === 'price') { state.advanced.price.min = null; state.advanced.price.max = null; }
    
    // Sync UI elements back
    syncFilterPanelToState();
    state.page = 1;
    applyFilters();
  }

  function syncFilterPanelToState() {
    if (!filterPanel) return;
    // Checks
    filterPanel.querySelectorAll('input[type="checkbox"]').forEach(cb => {
      const name = cb.name;
      const val = cb.value;
      if (name === 'availability') cb.checked = state.advanced.availability.includes(val);
      if (name === 'badge') cb.checked = state.advanced.badges.includes(val);
    });
    // Radios
    filterPanel.querySelectorAll('.filter-radio-btn').forEach(btn => {
      btn.classList.toggle('is-active', btn.dataset.value === state.advanced.rating);
    });
    // Price inputs
    const minInput = document.getElementById('price-min');
    const maxInput = document.getElementById('price-max');
    if (minInput) minInput.value = state.advanced.price.min || '';
    if (maxInput) maxInput.value = state.advanced.price.max || '';
  }

  // ── Main Filter Application ────────────────────────────────────────────────
  function applyFilters() {
    const hasAdvancedFilters = state.advanced.availability.length > 0
      || state.advanced.badges.length > 0
      || !!state.advanced.rating
      || state.advanced.details.length > 0
      || state.advanced.price.min !== null
      || state.advanced.price.max !== null;
    const isFiltering = state.query !== '' || state.filter !== 'all' || hasAdvancedFilters;

    if (featuredSection) featuredSection.style.display = isFiltering ? 'none' : '';

    const filteredCards = [];

    productCards.forEach(card => {
      const title = (card.querySelector('.product-card__title')?.textContent || '').toLowerCase();
      const desc = (card.querySelector('.product-card__desc')?.textContent || '').toLowerCase();
      const category = card.getAttribute('data-category') || '';

      const matchesSearch = !state.query || title.includes(state.query) || desc.includes(state.query);
      const matchesFilter = state.filter === 'all' || category === state.filter;

      // Advanced Filter Logic
      let matchesAdvanced = true;

      // 1. Availability
      if (state.advanced.availability.length > 0) {
        const cardAvail = (card.getAttribute('data-availability') || '').split(',');
        const hasMatch = state.advanced.availability.some(v => cardAvail.includes(v));
        if (!hasMatch) matchesAdvanced = false;
      }

      // 2. Badges
      if (matchesAdvanced && state.advanced.badges.length > 0) {
        const cardBadges = (card.getAttribute('data-badges') || '').split(',');
        const hasMatch = state.advanced.badges.some(v => cardBadges.includes(v));
        if (!hasMatch) matchesAdvanced = false;
      }

      // 3. Rating
      if (matchesAdvanced && state.advanced.rating) {
        const cardRating = parseFloat(card.getAttribute('data-rating') || '0');
        if (cardRating < parseFloat(state.advanced.rating)) matchesAdvanced = false;
      }

      // 4. Price Range
      if (matchesAdvanced && (state.advanced.price.min !== null || state.advanced.price.max !== null)) {
        const cardPrice = parseFloat(card.getAttribute('data-price') || '0');
        if (state.advanced.price.min !== null && cardPrice < state.advanced.price.min) matchesAdvanced = false;
        if (state.advanced.price.max !== null && cardPrice > state.advanced.price.max) matchesAdvanced = false;
      }

      if (matchesSearch && matchesFilter && matchesAdvanced) filteredCards.push(card);
    });

    const orderedCards = state.sort !== 'featured' ? sortCards(filteredCards) : filteredCards;

    if (state.sort !== 'featured') {
      orderedCards.forEach(card => card.parentElement?.appendChild(card));
    }

    const total = orderedCards.length;
    const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
    state.page = Math.min(state.page, totalPages);

    const pageStart = (state.page - 1) * PAGE_SIZE;
    const pageCards = orderedCards.slice(pageStart, pageStart + PAGE_SIZE);
    const pageCardSet = new Set(pageCards);
    const groupVisible = {};
    categoryGroups.forEach(group => {
      groupVisible[group.getAttribute('data-group')] = false;
    });

    productCards.forEach(card => {
      const category = card.getAttribute('data-category') || '';
      const visible = pageCardSet.has(card);
      card.style.display = visible ? '' : 'none';
      if (visible && Object.prototype.hasOwnProperty.call(groupVisible, category)) {
        groupVisible[category] = true;
      }
    });

    categoryGroups.forEach(group => {
      const key = group.getAttribute('data-group');
      group.style.display = groupVisible[key] ? '' : 'none';
    });

    const hasVisibleCards = pageCards.length > 0;

    if (resultCount) animateCount(resultCount, total);
    if (resultLabel) {
      resultLabel.textContent = isFiltering ? `service${total === 1 ? '' : 's'} found` : `service${total === 1 ? '' : 's'} available`;
    }

    if (emptyState) emptyState.classList.toggle('is-visible', isFiltering && !hasVisibleCards);
    renderPagination(total);

    updateFilterTokens();
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
      state.advanced.availability = Array.from(filterPanel.querySelectorAll('input[name="availability"]:checked')).map(cb => cb.value);
      state.advanced.badges = Array.from(filterPanel.querySelectorAll('input[name="badge"]:checked')).map(cb => cb.value);
      
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
      state.advanced = { availability: [], rating: null, badges: [], price: { min: null, max: null }, details: [] };
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
      state.advanced = { availability: [], rating: null, badges: [], price: { min: null, max: null }, details: [] };
      
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
  applyFilters();

  // ── Card click → service details page ────
  productCards.forEach(card => {
    card.style.cursor = 'pointer';
    card.addEventListener('click', e => {
      if (e.target.closest('a')) return; // let anchor handle navigation
      const link = card.querySelector('.product-card__action');
      if (link) window.location.href = link.href;
    });
  });

});

// .
