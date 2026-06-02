/* ═══════════════════════════════════════════════════════════
   technician-dashboard.js
   ═══════════════════════════════════════════════════════════ */
import { revealAll } from '../components/scroll-reveal.js';
import { showToast } from '../components/toast.js';
import { skCardGrid, skList, skStatGrid, skTableRows } from '../components/skeleton.js';
import { getInitials } from '../utils/string.js';
import { getMe, updateMe, updatePassword, updateEmail, deleteMe, updateAvailability, toggleAvailableNow, toggleBlockedDate } from '../api/users.js';
import { uploadPublicFile } from '../api/uploads.js';
import { getWorkerBookings, updateBookingStatus, submitCompletionOutcome } from '../api/bookings.js';
import { openCompletionOutcomeModal } from '../components/completion-outcome-modal.js';
import { getWorkerReviews } from '../api/reviews.js';
import { getServices } from '../api/services.js';
import { getMyDebts, getWorkerDisputes, getPartyDisputeById, addDisputeEvidence, appealDispute, getMyDebtsV2, getMySettlements, getMyPayouts, getWorkerEarnings, getWorkerEarningsHistory } from '../api/payments.js';
import { openSettleDebtModal } from '../components/settle-debt-form.js';
import { openPayoutRequestModal } from '../components/payout-request-form.js';
import { getNotifications as apiGetTechNotifs, markOneRead as apiMarkTechNotifRead, markAllRead as apiMarkTechAllRead, getNotificationPreferences, updateNotificationPreferences } from '../api/notifications.js';
import { getHierarchy as getLocationHierarchy, resolveSlug as resolveLocationSlug, labelForSlug as locationLabel, getDescendants as locationDescendants } from '../data/locations.js';
import { calculateBookingFee, DEFAULT_PLATFORM_FEE_RATE, money } from '../utils/fee.js';
import { createPoller, hasChanged, snapshotFocus, restoreFocus } from '../utils/live-poll.js';

// Per-booking fee snapshot. Uses booking's recorded fee if backend stamped it,
// else recomputes via platform default. Returns { gross, fee, net, feeRate }.
function bookingFeeSnapshot(b) {
  const gross = money(b?.totalPrice ?? 0);
  const rate = Number.isFinite(Number(b?.platformFeeRate))
    ? Number(b.platformFeeRate)
    : DEFAULT_PLATFORM_FEE_RATE;
  const fee = b?.platformFeeAmount != null
    ? money(b.platformFeeAmount)
    : calculateBookingFee(gross, rate).feeAmount;
  return { gross, fee, net: money(gross - fee), feeRate: rate };
}

const TAB_KEY = 'servio_activeTab_technician';

// Holds uploaded avatar URL between file-select and form-save
let _pendingPhotoUrl = null;
const DAYS_KEYS = ['avail_day_mon', 'avail_day_tue', 'avail_day_wed', 'avail_day_thu', 'avail_day_fri', 'avail_day_sat', 'avail_day_sun'];
const SKILLS_KEYS = ['skill_plumbing', 'skill_electrical', 'skill_hvac', 'skill_painting', 'skill_carpentry',
  'skill_cleaning', 'skill_roofing', 'skill_flooring', 'skill_appliance', 'skill_landscaping', 'skill_general'];

// Legacy flat list — superseded by the hierarchical picker built from the
// shared locations taxonomy. Kept as a tiny safety net for environments where
// the data module fails to load.
const DEFAULT_COVERAGE_AREAS = [
  'Cairo', 'Giza', 'Alexandria', 'Maadi', 'Heliopolis', 'Nasr City',
  'New Cairo', '6th of October', 'Sheikh Zayed', 'Mohandessin', 'Dokki',
];

function normalizeAreaList(items) {
  const values = Array.isArray(items) ? items : String(items || '').split(',');
  const seen = new Set();
  const result = [];
  values.forEach(item => {
    const area = String(item || '').trim();
    const key = area.toLowerCase();
    if (!area || seen.has(key)) return;
    seen.add(key);
    result.push(area);
  });
  return result;
}

function getCoverageAreasFromAccount(account) {
  if (Array.isArray(account?.coverageAreas) && account.coverageAreas.length) {
    return normalizeAreaList(account.coverageAreas);
  }
  return normalizeAreaList([account?.serviceArea, account?.locationLabel].filter(Boolean).join(','));
}

function getSelectedCoverageAreas(container) {
  if (!container) return [];
  if (Array.isArray(container.__selectedCoverageAreas)) {
    return normalizeAreaList(container.__selectedCoverageAreas);
  }
  return normalizeAreaList([...container.querySelectorAll('[data-area][aria-pressed="true"]')].map(btn => btn.dataset.area));
}

function getCustomCoverageAreas(customInput) {
  return normalizeAreaList(customInput?.value || '');
}

function splitCoverageAreasByTaxonomy(areas) {
  const known = [];
  const custom = [];
  normalizeAreaList(areas).forEach((area) => {
    if (resolveLocationSlug(area)) known.push(area);
    else custom.push(area);
  });
  return { known: normalizeAreaList(known), custom: normalizeAreaList(custom) };
}

function coverageKey(area) {
  return resolveLocationSlug(area) || String(area || '').trim().toLowerCase();
}

function sameCoverageList(a = [], b = []) {
  const left = normalizeAreaList(a).map(coverageKey).sort();
  const right = normalizeAreaList(b).map(coverageKey).sort();
  return left.length === right.length && left.every((key, index) => key === right[index]);
}

function getCoverageDirtyState(container, customInput) {
  if (!container?.__coverageBaselineReady) return false;
  return !sameCoverageList(getSelectedCoverageAreas(container), container.__savedCoverageAreas || [])
    || !sameCoverageList(getCustomCoverageAreas(customInput), container.__savedCustomAreas || []);
}

function updateCoverageSummary(summaryEl, areas) {
  if (!summaryEl) return;
  const count = areas.length;
  const countEl = document.getElementById('coverage-selected-count');
  if (countEl) countEl.textContent = `${count} area${count === 1 ? '' : 's'}`;
  summaryEl.textContent = count
    ? areas.slice(0, 4).join(', ') + (count > 4 ? ` + ${count - 4} more` : '')
    : 'No coverage areas selected.';
}

function syncCoverageCompactCard(container, customInput) {
  const countEl = document.getElementById('coverage-card-count');
  const summaryEl = document.getElementById('coverage-card-summary');
  const strip = document.getElementById('coverage-card-strip');
  if (!container || (!countEl && !summaryEl && !strip)) return;

  const selected = getSelectedCoverageAreas(container);
  const customAreas = getCustomCoverageAreas(customInput);
  const combined = normalizeAreaList([...selected, ...customAreas]);
  const isDirty = getCoverageDirtyState(container, customInput);
  const clearBtn = document.getElementById('coverage-card-clear');
  const saveBtn = document.getElementById('coverage-card-save');
  const dirtyEl = document.getElementById('coverage-card-dirty-state');

  if (countEl) countEl.textContent = `${combined.length} area${combined.length === 1 ? '' : 's'}`;
  if (summaryEl) {
    summaryEl.textContent = combined.length
      ? combined.slice(0, 4).join(', ') + (combined.length > 4 ? ` + ${combined.length - 4} more` : '')
      : 'No coverage areas selected. Customers cannot book you by location yet.';
  }
  if (clearBtn) clearBtn.disabled = combined.length === 0;
  if (saveBtn) saveBtn.disabled = !isDirty;
  if (dirtyEl) dirtyEl.hidden = !isDirty;

  if (!strip) return;
  strip.innerHTML = '';
  if (!combined.length) {
    const empty = document.createElement('span');
    empty.className = 'coverage-selected-strip__empty';
    empty.textContent = 'Open Manage coverage to add districts.';
    strip.appendChild(empty);
    return;
  }

  combined.slice(0, 6).forEach((area) => {
    const chip = document.createElement('span');
    chip.className = 'coverage-selected-chip coverage-selected-chip--readonly';
    chip.textContent = area;
    strip.appendChild(chip);
  });
  if (combined.length > 6) {
    const more = document.createElement('span');
    more.className = 'coverage-selected-chip coverage-selected-chip--more';
    more.textContent = `+ ${combined.length - 6} more`;
    strip.appendChild(more);
  }
}

function syncCoverageControls(container, summaryEl, customInput) {
  if (!container) return;
  const selected = getSelectedCoverageAreas(container);
  const customAreas = getCustomCoverageAreas(customInput);
  const combined = normalizeAreaList([...selected, ...customAreas]);
  const isDirty = getCoverageDirtyState(container, customInput);
  const clearBtn = document.getElementById('coverage-clear');
  const resetBtn = document.getElementById('coverage-reset');
  const modalResetBtn = document.getElementById('coverage-modal-reset');
  const saveBtn = document.getElementById('save-coverage');
  const dirtyEl = document.getElementById('coverage-dirty-state');
  const customDetails = document.querySelector('.coverage-custom-details');

  updateCoverageSummary(summaryEl, combined);
  if (clearBtn) clearBtn.disabled = combined.length === 0;
  if (resetBtn) resetBtn.disabled = !isDirty;
  if (modalResetBtn) modalResetBtn.disabled = !isDirty;
  if (saveBtn) saveBtn.disabled = !isDirty;
  if (dirtyEl) dirtyEl.hidden = !isDirty;
  if (customDetails && customAreas.length) customDetails.open = true;
  updateCoverageSelectedStrip(container, summaryEl, customInput);
  syncCoverageCompactCard(container, customInput);
}

function updateCoverageSelectedStrip(container, summaryEl, customInput) {
  const strip = document.getElementById('coverage-selected-strip');
  if (!strip || !container) return;
  const selected = getSelectedCoverageAreas(container);
  const customAreas = getCustomCoverageAreas(customInput);
  strip.innerHTML = '';

  if (!selected.length && !customAreas.length) {
    const empty = document.createElement('span');
    empty.className = 'coverage-selected-strip__empty';
    empty.textContent = 'No districts selected yet.';
    strip.appendChild(empty);
    return;
  }

  selected.forEach((area) => {
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = 'coverage-selected-chip';
    chip.dataset.area = area;
    chip.setAttribute('aria-label', `Remove ${area}`);
    chip.innerHTML = `<span></span><b aria-hidden="true">x</b>`;
    chip.querySelector('span').textContent = area;
    chip.addEventListener('click', () => {
      const areaSlug = resolveLocationSlug(area);
      commitSelection(
        container,
        summaryEl,
        customInput,
        getSelectedCoverageAreas(container).filter((item) => resolveLocationSlug(item) !== areaSlug)
      );
    });
    strip.appendChild(chip);
  });

  customAreas.forEach((area) => {
    const tag = document.createElement('span');
    tag.className = 'coverage-selected-chip coverage-selected-chip--custom';
    tag.textContent = `Custom: ${area}`;
    strip.appendChild(tag);
  });
}

// Hierarchical picker: governorate → districts. Selecting a governorate is
// shorthand for covering every district inside it — the backend's
// `coverageMatchSlugs` expansion handles the matching, but we keep the UI
// explicit so technicians see exactly what they accept.
function renderCoverageEditor({ container, searchInput, summaryEl, selectedAreas = null, customInput }) {
  if (!container) return;
  const selectedList = normalizeAreaList(Array.isArray(selectedAreas)
    ? selectedAreas
    : (container.__selectedCoverageAreas || []));
  container.__selectedCoverageAreas = selectedList;
  container.__coverageSearchInput = searchInput || container.__coverageSearchInput || null;
  if (!container.__expandedCoverageGovs) container.__expandedCoverageGovs = new Set(['cairo-gov', 'giza-gov']);
  if (!container.__coverageBaselineReady) {
    container.__savedCoverageAreas = normalizeAreaList(selectedList);
    container.__savedCustomAreas = getCustomCoverageAreas(customInput);
    container.__coverageBaselineReady = true;
  }

  // Map any current selections to their canonical slugs so a governorate-level
  // selection is recognised even if it was stored as "Cairo" instead of the
  // slug "cairo-gov".
  const selectedSlugs = new Set(
    selectedList.map(resolveLocationSlug).filter(Boolean)
  );
  const query = String(searchInput?.value || '').trim().toLowerCase();
  const hasQuery = query.length > 0;
  const querySlug = hasQuery ? resolveLocationSlug(query) : '';

  let hierarchy = [];
  try { hierarchy = getLocationHierarchy(); } catch { hierarchy = []; }

  container.innerHTML = '';

  if (!hierarchy.length) {
    // Hard fallback to the legacy flat list if the taxonomy module is unavailable.
    DEFAULT_COVERAGE_AREAS.forEach((area) => {
      const btn = buildChip(area, selectedList.includes(area), () =>
        toggleSelection(container, summaryEl, customInput, area));
      container.appendChild(btn);
    });
    syncCoverageControls(container, summaryEl, customInput);
    return;
  }

  let renderedGroups = 0;
  hierarchy.forEach((gov) => {
    const descendants = locationDescendants(gov.slug);
    const directGovMatches = !query
      || gov.name.toLowerCase().includes(query)
      || gov.slug === querySlug;
    const govMatches = directGovMatches || descendants.includes(querySlug);
    const visibleDistricts = gov.districts.filter((d) =>
      directGovMatches || d.name.toLowerCase().includes(query) || d.slug === querySlug
    );
    if (!govMatches && !visibleDistricts.length) return;

    const group = document.createElement('div');
    group.className = 'coverage-group';

    const header = document.createElement('div');
    header.className = 'coverage-group__header';

    const govSelected = selectedSlugs.has(gov.slug);
    const hasSelectedDistrict = gov.districts.some((d) => selectedSlugs.has(d.slug));
    const isExpanded = hasQuery || govSelected || hasSelectedDistrict || container.__expandedCoverageGovs.has(gov.slug);
    group.classList.toggle('coverage-group--selected', govSelected || hasSelectedDistrict);
    group.classList.toggle('coverage-group--collapsed', !isExpanded);

    const toggleBtn = document.createElement('button');
    toggleBtn.type = 'button';
    toggleBtn.className = 'coverage-group__toggle';
    toggleBtn.setAttribute('aria-expanded', String(isExpanded));
    const chevron = document.createElement('span');
    chevron.className = 'coverage-group__chevron';
    chevron.setAttribute('aria-hidden', 'true');
    const nameEl = document.createElement('span');
    nameEl.textContent = gov.name;
    const countEl = document.createElement('small');
    countEl.textContent = gov.districts.length
      ? `${gov.districts.length} districts`
      : 'Governorate level';
    toggleBtn.append(chevron, nameEl, countEl);
    toggleBtn.addEventListener('click', () => {
      if (container.__expandedCoverageGovs.has(gov.slug)) container.__expandedCoverageGovs.delete(gov.slug);
      else container.__expandedCoverageGovs.add(gov.slug);
      renderCoverageEditor({
        container,
        searchInput: container.__coverageSearchInput,
        summaryEl,
        selectedAreas: container.__selectedCoverageAreas,
        customInput,
      });
    });
    header.appendChild(toggleBtn);

    const govChip = buildChip(`${gov.name} (all)`, govSelected, () => {
      // Selecting a governorate clears its districts to keep the list tidy —
      // the slug-expansion on the backend already implies coverage of all of them.
      const next = govSelected
        ? (container.__selectedCoverageAreas || []).filter((a) => resolveLocationSlug(a) !== gov.slug)
        : [
          ...(container.__selectedCoverageAreas || []).filter((a) => {
            const slug = resolveLocationSlug(a);
            return !slug || !descendants.includes(slug);
          }),
          gov.name,
        ];
      commitSelection(container, summaryEl, customInput, next);
    });
    govChip.classList.add('coverage-chip--gov');
    header.appendChild(govChip);
    group.appendChild(header);

    if (isExpanded && govSelected) {
      const note = document.createElement('p');
      note.className = 'coverage-group__covered-note';
      const preview = gov.districts.slice(0, 5).map((d) => d.name).join(', ');
      note.textContent = gov.districts.length
        ? `All ${gov.districts.length} districts are covered, including ${preview}${gov.districts.length > 5 ? ', and more' : ''}.`
        : `${gov.name} is covered.`;
      group.appendChild(note);
    } else if (isExpanded && visibleDistricts.length) {
      const districtRow = document.createElement('div');
      districtRow.className = 'coverage-group__districts';

      visibleDistricts.forEach((d) => {
        const isSelected = selectedSlugs.has(d.slug);
        const chip = buildChip(d.name, isSelected, () => {
          const next = isSelected
            ? (container.__selectedCoverageAreas || []).filter((a) => resolveLocationSlug(a) !== d.slug)
            : [...(container.__selectedCoverageAreas || []), d.name];
          commitSelection(container, summaryEl, customInput, next);
        });
        districtRow.appendChild(chip);
      });

      group.appendChild(districtRow);
    }
    container.appendChild(group);
    renderedGroups += 1;
  });

  const emptyState = document.getElementById('coverage-empty-state');
  if (emptyState) emptyState.hidden = renderedGroups > 0;
  syncCoverageControls(container, summaryEl, customInput);
}

function buildChip(label, pressed, onClick) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'skill-tag coverage-chip';
  btn.dataset.area = label;
  btn.setAttribute('aria-pressed', String(pressed));
  btn.textContent = label;
  btn.addEventListener('click', onClick);
  return btn;
}

function commitSelection(container, summaryEl, customInput, nextList) {
  container.__selectedCoverageAreas = normalizeAreaList(nextList);
  // Re-render so the implicit-coverage chips update when a governorate toggles.
  renderCoverageEditor({
    container,
    searchInput: container.__coverageSearchInput,
    summaryEl,
    selectedAreas: container.__selectedCoverageAreas,
    customInput,
  });
}

function setCoverageSavedBaseline(container, customInput) {
  if (!container) return;
  container.__savedCoverageAreas = getSelectedCoverageAreas(container);
  container.__savedCustomAreas = getCustomCoverageAreas(customInput);
  container.__coverageBaselineReady = true;
  syncCoverageControls(container, document.getElementById('coverage-summary'), customInput);
}

function resetCoverageToSaved(container, summaryEl, customInput) {
  if (!container) return;
  container.__selectedCoverageAreas = normalizeAreaList(container.__savedCoverageAreas || []);
  if (customInput) customInput.value = normalizeAreaList(container.__savedCustomAreas || []).join(', ');
  renderCoverageEditor({
    container,
    searchInput: container.__coverageSearchInput,
    summaryEl,
    selectedAreas: container.__selectedCoverageAreas,
    customInput,
  });
}

function clearCoverageSelection(container, summaryEl, customInput) {
  if (!container) return;
  container.__selectedCoverageAreas = [];
  if (customInput) customInput.value = '';
  renderCoverageEditor({
    container,
    searchInput: container.__coverageSearchInput,
    summaryEl,
    selectedAreas: [],
    customInput,
  });
}

function toggleSelection(container, summaryEl, customInput, area) {
  const pressed = (container.__selectedCoverageAreas || [])
    .some((a) => a.toLowerCase() === area.toLowerCase());
  const next = pressed
    ? (container.__selectedCoverageAreas || []).filter((a) => a.toLowerCase() !== area.toLowerCase())
    : [...(container.__selectedCoverageAreas || []), area];
  commitSelection(container, summaryEl, customInput, next);
}

function openCoverageModal() {
  const modal = document.getElementById('coverage-modal');
  if (!modal) return;
  modal.classList.add('is-open');
  modal.setAttribute('aria-hidden', 'false');
  document.body.classList.add('coverage-modal-open');
  const searchInput = document.getElementById('coverage-search');
  const container = document.getElementById('coverage-area-chips');
  const customInput = document.getElementById('service-area');
  renderCoverageEditor({
    container,
    searchInput,
    summaryEl: document.getElementById('coverage-summary'),
    selectedAreas: getSelectedCoverageAreas(container),
    customInput,
  });
  window.setTimeout(() => searchInput?.focus(), 40);
}

function closeCoverageModal({ reset = false } = {}) {
  const modal = document.getElementById('coverage-modal');
  const container = document.getElementById('coverage-area-chips');
  const customInput = document.getElementById('service-area');
  const summaryEl = document.getElementById('coverage-summary');
  if (reset) resetCoverageToSaved(container, summaryEl, customInput);
  modal?.classList.remove('is-open');
  modal?.setAttribute('aria-hidden', 'true');
  document.body.classList.remove('coverage-modal-open');
  document.getElementById('coverage-open-modal')?.focus();
}

// Tab label map for topbar title (keys resolved via t() at render time)
const TAB_LABEL_KEYS = {
  'overview': 'tech_nav_overview',
  'job-queue': 'tech_nav_job_queue',
  'earnings': 'tech_nav_earnings',
  'availability': 'tech_nav_availability',
  'reviews': 'tech_nav_reviews',
  'verification': 'tech_nav_verification',
  'settings': 'tech_nav_settings',
  'job-board': 'tech_nav_job_board',
  'my-proposals': 'tech_nav_proposals',
  'disputes': 'tech_nav_disputes',
};

function getSession() {
  try { return JSON.parse(localStorage.getItem('servio_session') || 'null'); } catch { return null; }
}

// ── Auth Guard ──────────────────────────────────────────
const session = getSession();
if (!session) {
  window.location.href = './login.html';
} else if (session.role === 'admin') {
  window.location.href = './admin-dashboard.html';
} else if (session.role === 'customer') {
  window.location.href = './customer-dashboard.html';
}

function getAccount() {
  try { return JSON.parse(localStorage.getItem('servio_account') || 'null'); } catch { return null; }
}
/* ── Topbar notification badge ──────────────────────────── */
function updateTopbarBadge(count) {
  const badge = document.getElementById('topbar-notif-badge');
  if (!badge) return;
  badge.hidden = count === 0;
  badge.textContent = count > 9 ? '9+' : String(count);
}

/* ── Sidebar nav indicators (unseen counts per tab) ─────── */
const NAV_SEEN_KEY = 'servio_nav_seen_v1';
function getNavSeen() {
  try { return JSON.parse(localStorage.getItem(NAV_SEEN_KEY) || '{}'); } catch { return {}; }
}
function setNavSeen(map) {
  try { localStorage.setItem(NAV_SEEN_KEY, JSON.stringify(map)); } catch { }
}
function setNavBadge(tabId, count) {
  const badges = document.querySelectorAll(`[data-nav-badge="${tabId}"]`);
  if (!badges.length) return;
  badges.forEach(el => {
    if (count > 0) {
      el.hidden = false;
      el.textContent = count > 9 ? '9+' : String(count);
      el.setAttribute('aria-label', `${count} new update${count === 1 ? '' : 's'}`);
    } else {
      el.hidden = true;
      el.removeAttribute('aria-label');
    }
  });
}
function updateSidebarIndicators(bookings) {
  const seen = getNavSeen();
  const list = Array.isArray(bookings) ? bookings : [];

  // Job Queue: pending bookings awaiting acceptance
  const pendingCount = list.filter(b => b.status === 'pending').length;
  setNavBadge('job-queue', pendingCount);

  // Earnings: completed bookings since user last viewed earnings tab
  const lastSeenEarnings = seen.earnings || 0;
  const newCompleted = list.filter(b => {
    if (b.status !== 'completed') return false;
    const t = new Date(b.completedAt || b.updatedAt || b.scheduledDate).getTime();
    return t > lastSeenEarnings;
  }).length;
  setNavBadge('earnings', newCompleted);
}
function updateReviewIndicator(reviews) {
  const seen = getNavSeen();
  const lastSeenReviews = seen.reviews || 0;
  const list = Array.isArray(reviews) ? reviews : [];
  const newReviews = list.filter(r => {
    const t = new Date(r.createdAt || r.updatedAt).getTime();
    return Number.isFinite(t) && t > lastSeenReviews;
  }).length;
  setNavBadge('reviews', newReviews);
}
function markTabSeen(tabId) {
  const seen = getNavSeen();
  seen[tabId] = Date.now();
  setNavSeen(seen);
  // Clear that tab's indicator immediately
  setNavBadge(tabId, 0);
}

/* ── Topbar avatar ──────────────────────────────────────── */
function initTopbarAvatar() {
  try {
    const session = JSON.parse(localStorage.getItem('servio_session') || '{}');
    const initial = (session.name || 'T')[0].toUpperCase();
    const el = document.getElementById('topbar-avatar');
    if (el) el.textContent = initial;
  } catch { }
}

/* ── Topbar theme toggle ────────────────────────────────── */
function initTabs() {
  const tabs = document.querySelectorAll('[data-tab]');
  const panels = document.querySelectorAll('[data-panel]');
  const mobileTabs = document.querySelector('[data-mobile-tabs]');

  if (mobileTabs) {
    tabs.forEach(tab => {
      const btn = document.createElement('button');
      btn.className = 'dash-mobile-tab';
      btn.type = 'button';
      const label = tab.querySelector('.dash-nav__label')?.textContent.trim() || tab.textContent.trim();
      btn.append(document.createTextNode(label));
      btn.dataset.mobileTab = tab.dataset.tab;
      if (tab.querySelector('[data-nav-badge]')) {
        const badge = document.createElement('span');
        badge.className = 'dash-mobile-tab__badge';
        badge.dataset.navBadge = tab.dataset.tab;
        badge.hidden = true;
        badge.textContent = '0';
        btn.appendChild(badge);
      }
      mobileTabs.appendChild(btn);
    });
  }

  // Timestamps of last data refresh per tab (ms). Avoids redundant API calls on rapid switches.
  const tabLastRefresh = {};
  const TAB_REFRESH_TTL = 30_000; // 30 s

  function showTab(id) {
    tabs.forEach(t => {
      const active = t.dataset.tab === id;
      t.classList.toggle('is-active', active);
      t.setAttribute('aria-selected', String(active));
    });
    document.querySelectorAll('.dash-mobile-tab').forEach(t => {
      t.classList.toggle('is-active', t.dataset.mobileTab === id);
    });
    panels.forEach(p => {
      const active = p.dataset.panel === id;
      p.classList.toggle('is-active', active);
      p.hidden = !active;
      if (active) revealAll(p);
    });
    sessionStorage.setItem(TAB_KEY, id);
    markTabSeen(id);
    // Update topbar title
    const labelKey = TAB_LABEL_KEYS[id];
    const el = document.getElementById('dash-topbar-title');
    if (el) {
      if (labelKey && typeof window.t === 'function') {
        el.textContent = window.t(labelKey);
        el.removeAttribute('data-i18n');
      } else if (labelKey) {
        el.setAttribute('data-i18n', labelKey);
      } else {
        el.textContent = id;
      }
    }

    // Refresh data for data-driven tabs (skip on first load — initDashboard already fetched)
    const now = Date.now();
    const stale = !tabLastRefresh[id] || (now - tabLastRefresh[id]) > TAB_REFRESH_TTL;
    if (stale && tabLastRefresh[id] !== undefined) {
      tabLastRefresh[id] = now;
      if (id === 'job-queue') {
        initJobQueue().catch(() => { });
      } else if (id === 'overview' || id === 'earnings') {
        populateStats().catch(() => { });
      } else if (id === 'disputes') {
        loadTechDisputes().catch(() => { });
      }
    } else if (tabLastRefresh[id] === undefined) {
      if (id === 'disputes') {
        loadTechDisputes().catch(() => { });
      }
      // Mark as seen so next visit triggers refresh
      tabLastRefresh[id] = now;
    }
  }

  tabs.forEach(tab => tab.addEventListener('click', () => showTab(tab.dataset.tab)));
  document.querySelectorAll('[data-tab-link]').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.tabLink));
  });
  document.querySelectorAll('.dash-mobile-tab').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.mobileTab));
  });

  // Quick availability button in overview
  const quickAvail = document.querySelector('[data-quick-availability]');
  if (quickAvail) quickAvail.addEventListener('click', () => showTab('availability'));

  const hashTab = (location.hash || '').replace('#', '').trim();
  const knownTabs = Array.from(tabs).map(t => t.dataset.tab);
  const saved = (hashTab && knownTabs.includes(hashTab))
    ? hashTab
    : (sessionStorage.getItem(TAB_KEY) || 'overview');
  showTab(saved);

  window.addEventListener('hashchange', () => {
    const h = (location.hash || '').replace('#', '').trim();
    if (h && knownTabs.includes(h)) showTab(h);
  });
}

function populateProfile() {
  const session = getSession();
  const account = getAccount();
  if (!session) {
    const currentPath = window.location.pathname;
    const currentPage = currentPath.substring(currentPath.lastIndexOf('/') + 1) || 'index.html';
    const redirectParam = encodeURIComponent('./' + currentPage + window.location.search);
    window.location.href = './login.html?redirect=' + redirectParam;
    return;
  }

  const name = session.name || account?.fullName || 'Technician';
  const initials = getInitials(name);

  document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = initials; });
  const nameEl = document.querySelector('[data-dash-name]');
  const emailEl = document.querySelector('[data-dash-email]');
  if (nameEl) nameEl.textContent = name;
  if (emailEl) {
    const email = session.email || account?.email || '';
    emailEl.textContent = email || '—';
  }
  // Topbar avatar initial
  const topbarAvatar = document.getElementById('topbar-avatar');
  if (topbarAvatar && !topbarAvatar.hasAttribute('data-dash-initials')) topbarAvatar.textContent = initials[0] || 'T';
  // First name in welcome banner
  document.querySelectorAll('[data-dash-firstname]').forEach(el => { el.textContent = name.split(' ')[0]; });

  // Build an effective account by merging session fields as fallback for missing account data
  const effectiveAccount = {
    fullName: session.name || '',
    name: session.name || '',
    email: session.email || '',
    phone: session.phone || '',
    skills: session.skills || [],
    specialty: Array.isArray(session.skills) ? session.skills.join(', ') : '',
    hourlyRate: session.hourlyRate ?? '',
    yearsExperience: session.yearsExperience ?? '',
    experience: session.yearsExperience ?? '',
    bio: session.bio || '',
    ...(account || {}),
  };

  // Normalise field aliases
  if (!effectiveAccount.fullName && effectiveAccount.name) effectiveAccount.fullName = effectiveAccount.name;
  if (effectiveAccount.yearsExperience != null && effectiveAccount.experience == null) {
    effectiveAccount.experience = effectiveAccount.yearsExperience;
  }
  if (!effectiveAccount.specialty && Array.isArray(effectiveAccount.skills) && effectiveAccount.skills.length) {
    effectiveAccount.specialty = effectiveAccount.skills.join(', ');
  }

  document.querySelectorAll('[data-settings-field]').forEach(f => {
    const val = effectiveAccount[f.dataset.settingsField];
    if (val != null && val !== '') f.value = val;
  });
  const initialCoverage = getCoverageAreasFromAccount(effectiveAccount);
  const serviceAreaInput = document.getElementById('service-area');
  const initialCoverageSplit = splitCoverageAreasByTaxonomy(initialCoverage);
  if (serviceAreaInput) {
    serviceAreaInput.value = initialCoverageSplit.custom.join(', ');
  }
  renderCoverageEditor({
    container: document.getElementById('coverage-area-chips'),
    searchInput: document.getElementById('coverage-search'),
    summaryEl: document.getElementById('coverage-summary'),
    selectedAreas: initialCoverageSplit.known,
    customInput: serviceAreaInput,
  });
  setCoverageSavedBaseline(document.getElementById('coverage-area-chips'), serviceAreaInput);
  document.getElementById('coverage-search')?.addEventListener('input', () => renderCoverageEditor({
    container: document.getElementById('coverage-area-chips'),
    searchInput: document.getElementById('coverage-search'),
    summaryEl: document.getElementById('coverage-summary'),
    selectedAreas: getSelectedCoverageAreas(document.getElementById('coverage-area-chips')),
    customInput: serviceAreaInput,
  }));
  serviceAreaInput?.addEventListener('input', () => syncCoverageControls(
    document.getElementById('coverage-area-chips'),
    document.getElementById('coverage-summary'),
    serviceAreaInput
  ));

  // Render avatar — photo takes priority over initials
  const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
  // Only trust server URL if it's an actual HTTP/HTTPS/relative URL (not a local filesystem path)
  const serverImg = session.profileImage || '';
  const serverImgUsable = serverImg && (serverImg.startsWith('http') || serverImg.startsWith('/'));
  const photoUrl = serverImgUsable ? serverImg : (localStorage.getItem('servio_avatar_cache') || null);
  const preview = document.querySelector('[data-avatar-preview]');
  const topbar = document.getElementById('topbar-avatar');

  if (preview) {
    if (photoUrl) {
      preview.innerHTML = `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`;
      preview.classList.remove('avatar-required');
    } else {
      preview.innerHTML = `<span>${initials}</span>`;
      // Mandatory guard — red ring + hint when no photo
      preview.classList.add('avatar-required');
      const wrap = preview.closest('.settings-avatar-wrap');
      if (wrap && !wrap.querySelector('.avatar-required-hint')) {
        const hint = document.createElement('p');
        hint.className = 'avatar-required-hint';
        hint.textContent = typeof window.t === 'function'
          ? window.t('toast_photo_required')
          : 'Please add a profile photo before saving.';
        wrap.insertAdjacentElement('afterend', hint);
      }
    }
  }
  if (topbar) {
    topbar.innerHTML = photoUrl
      ? `<img src="${photoUrl}" alt="Profile photo" style="${imgStyle}" />`
      : (initials[0] || 'T');
  }

  // Sync from API — refresh photo and populate form fields with authoritative data
  getMe().then(user => {
    if (!user) return;

    // Update profile photo if changed (only use server URL if it's a real HTTP URL)
    const apiImg = user.profileImage || '';
    const apiImgUsable = apiImg && (apiImg.startsWith('http') || apiImg.startsWith('/'));
    const resolvedPhoto = apiImgUsable ? apiImg : (localStorage.getItem('servio_avatar_cache') || null);
    if (resolvedPhoto && resolvedPhoto !== photoUrl) {
      if (apiImgUsable) {
        const s = getSession();
        if (s) { s.profileImage = apiImg; localStorage.setItem('servio_session', JSON.stringify(s)); }
      }
      if (preview) {
        preview.innerHTML = `<img src="${resolvedPhoto}" alt="Profile photo" style="${imgStyle}" />`;
        preview.classList.remove('avatar-required');
        const hint = preview.closest('.settings-avatar-wrap')?.nextElementSibling;
        if (hint?.classList.contains('avatar-required-hint')) hint.remove();
      }
      if (topbar) topbar.innerHTML = `<img src="${resolvedPhoto}" alt="Profile photo" style="${imgStyle}" />`;
    }

    // Populate settings form fields from live API data
    const fieldMap = {
      fullName: user.name,
      email: user.email,
      phone: user.phone,
      specialty: Array.isArray(user.skills) ? user.skills.join(', ') : (user.specialty || ''),
      hourlyRate: user.hourlyRate,
      experience: user.yearsExperience,
      bio: user.bio,
      facebook: user.facebook,
      instagram: user.instagram,
      portfolio: user.portfolioUrl,
    };
    Object.entries(fieldMap).forEach(([field, val]) => {
      if (val == null || val === '') return;
      const el = document.querySelector(`[data-settings-field="${field}"]`);
      if (el) el.value = val;
    });

    // Update sidebar name and initials
    if (user.name) {
      document.querySelectorAll('[data-dash-name]').forEach(el => { el.textContent = user.name; });
      const freshInitials = getInitials(user.name);
      document.querySelectorAll('[data-dash-initials]').forEach(el => { el.textContent = freshInitials; });
      document.querySelectorAll('[data-dash-firstname]').forEach(el => { el.textContent = user.name.split(' ')[0]; });
    }

    // Persist updated data locally for offline use
    try {
      const acc = getAccount() || {};
      if (user.name) { acc.fullName = user.name; acc.name = user.name; }
      if (user.phone) acc.phone = user.phone;
      if (user.skills) { acc.skills = user.skills; acc.specialty = user.skills.join(', '); }
      if (user.hourlyRate) acc.hourlyRate = user.hourlyRate;
      if (user.yearsExperience != null) { acc.yearsExperience = user.yearsExperience; acc.experience = user.yearsExperience; }
      if (user.bio) acc.bio = user.bio;
      if (user.facebook) acc.facebook = user.facebook;
      if (user.instagram) acc.instagram = user.instagram;
      if (user.portfolioUrl) acc.portfolio = user.portfolioUrl;
      localStorage.setItem('servio_account', JSON.stringify(acc));
    } catch (_) { }

    // Wire "View Profile" link so tech sees their own public profile (read-only)
    const techId = user._id || user.id;
    if (techId) {
      document.querySelectorAll('a[data-i18n="tech_view_profile"]').forEach(link => {
        link.href = `./technician-profile.html?id=${techId}&preview=1`;
      });
    }
  }).catch(() => { });
}

function updateWelcomeText() {
  // Time-aware greeting
  const hour = new Date().getHours();
  const greetingKey = hour < 12 ? 'greeting_morning' : hour < 17 ? 'greeting_afternoon' : 'greeting_evening';
  const greeting = typeof window.t === 'function' ? window.t(greetingKey) : (hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening');
  document.querySelectorAll('[data-dash-greeting], .dash-welcome__greeting').forEach(el => {
    el.textContent = greeting;
  });

  // Populate first name in the welcome banner
  const session = getSession();
  const account = getAccount();
  const name = session?.name || account?.fullName || 'Technician';
  const firstName = name.split(' ')[0];
  document.querySelectorAll('[data-dash-firstname]').forEach(el => { el.textContent = firstName; });

  // Legacy selector support
  const welcomeEl = document.querySelector('[data-dash-welcome]');
  if (welcomeEl) {
    const welcomeKey = typeof window.t === 'function' ? window.t('tech_welcome_back') : 'Welcome back, ';
    welcomeEl.textContent = `${welcomeKey}${firstName}!`;
  }

  // Status sub-text
  const pending = parseInt(document.querySelector('[data-stat="pending-requests"]')?.textContent, 10) || 0;
  let subText;
  if (typeof window.t === 'function') {
    subText = pending === 0
      ? window.t('tech_no_requests')
      : pending === 1
        ? window.t('tech_n_requests', { n: 1 })
        : window.t('tech_n_requests_plural', { n: pending });
  } else {
    subText = pending === 0 ? 'No new requests right now.' : `You have ${pending} new job request${pending > 1 ? 's' : ''} waiting.`;
  }
  document.querySelectorAll('[data-dash-status-sub], .dash-welcome__sub').forEach(el => {
    el.textContent = subText;
  });
}

const TECH_STATS_CACHE_KEY = 'servio_technician_stats_cache_v1';

function setStatTextEl(key, val) {
  const el = document.querySelector(`[data-stat="${key}"]`);
  if (el) el.textContent = val;
}
function setStatSubTextEl(key, val) {
  const el = document.querySelector(`[data-stat-sub="${key}"]`);
  if (el) el.textContent = val;
}

function renderCachedTechStats() {
  try {
    const c = JSON.parse(localStorage.getItem(TECH_STATS_CACHE_KEY) || 'null');
    if (!c) return;
    if (c.totalJobs != null) setStatTextEl('total-jobs', c.totalJobs);
    if (c.totalJobsMonthSub) setStatSubTextEl('total-jobs-month', c.totalJobsMonthSub);
    if (c.monthEarningsLabel) setStatTextEl('month-earnings', c.monthEarningsLabel);
    if (c.monthEarningsChange) setStatSubTextEl('month-earnings-change', c.monthEarningsChange);
    if (c.pendingRequests != null) setStatTextEl('pending-requests', c.pendingRequests);
    if (c.pendingRequestsNote) setStatSubTextEl('pending-requests-note', c.pendingRequestsNote);
    if (c.outstandingHtml) {
      const el = document.querySelector('[data-stat="outstanding-balance"]');
      if (el) el.innerHTML = c.outstandingHtml;
    }
  } catch { /* ignore */ }
}

async function populateStats() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  function setStat(key, val) { setStatTextEl(key, val); }
  function setStatSub(key, val) { setStatSubTextEl(key, val); }

  // Fetch all bookings for this worker (up to 200 to compute stats)
  let bookings = [];
  let totalCount = 0;
  try {
    const res = await getWorkerBookings({ limit: 200 });
    bookings = res?.bookings || [];
    totalCount = res?.pagination?.total ?? bookings.length;
  } catch (_) { }

  let earnings = null;
  try {
    earnings = await getWorkerEarnings();
  } catch (err) {
    console.warn('[tech] Failed to fetch canonical earnings breakdown', err);
  }

  updateSidebarIndicators(bookings);

  const now = new Date();
  const thisMonth = now.getMonth();
  const thisYear = now.getFullYear();
  const lastMonth = thisMonth === 0 ? 11 : thisMonth - 1;
  const lastYear = thisMonth === 0 ? thisYear - 1 : thisYear;

  const completed = bookings.filter(b => b.status === 'completed');
  const pending = bookings.filter(b => b.status === 'pending');
  const cashCompleted = completed.filter(b => b.paymentMethod === 'cash');
  const breakdown = earnings?.breakdown || null;

  // Legacy fallback when the canonical earnings breakdown is unavailable.
  let monthEarningsGross = 0;
  const fallbackMonthEarnings = completed.reduce((sum, b) => {
    const d = new Date(b.scheduledDate || b.createdAt);
    if (d.getMonth() === thisMonth && d.getFullYear() === thisYear) {
      const { gross, net } = bookingFeeSnapshot(b);
      monthEarningsGross += gross;
      return sum + net;
    }
    return sum;
  }, 0);

  // Last month earnings for delta (net, same basis)
  const fallbackLastMonthEarnings = completed.reduce((sum, b) => {
    const d = new Date(b.scheduledDate || b.createdAt);
    if (d.getMonth() === lastMonth && d.getFullYear() === lastYear) {
      return sum + bookingFeeSnapshot(b).net;
    }
    return sum;
  }, 0);

  const monthEarnings = Number.isFinite(Number(breakdown?.thisMonthTakeHome))
    ? Number(breakdown.thisMonthTakeHome)
    : fallbackMonthEarnings;
  const lastMonthEarnings = Number.isFinite(Number(breakdown?.lastMonthTakeHome))
    ? Number(breakdown.lastMonthTakeHome)
    : fallbackLastMonthEarnings;
  const outstandingAmount = money(
    Number.isFinite(Number(breakdown?.outstandingCashFees))
      ? Number(breakdown.outstandingCashFees)
      : cashCompleted.reduce((sum, b) => sum + bookingFeeSnapshot(b).fee, 0)
  );

  // This month's job count
  const monthJobs = bookings.filter(b => {
    const d = new Date(b.scheduledDate || b.createdAt);
    return d.getMonth() === thisMonth && d.getFullYear() === thisYear && b.status !== 'cancelled' && b.status !== 'rejected';
  }).length;

  // Update stat card values
  const nonCancelled = bookings.filter(b => b.status !== 'cancelled' && b.status !== 'rejected');
  setStat('total-jobs', totalCount > bookings.length ? totalCount : nonCancelled.length);
  setStatSub('total-jobs-month', `+${monthJobs} ${_t('tech_stat_this_month') || 'this month'}`);

  setStat('month-earnings', monthEarnings > 0 ? `EGP ${monthEarnings.toLocaleString('en-US')}` : 'EGP 0');
  const delta = monthEarnings - lastMonthEarnings;
  const deltaStr = delta >= 0
    ? `+EGP ${Math.abs(delta).toLocaleString('en-US')} vs last`
    : `-EGP ${Math.abs(delta).toLocaleString('en-US')} vs last`;
  setStatSub('month-earnings-change', deltaStr);

  setStat('pending-requests', pending.length);
  const _tSafe = k => { const v = typeof window.t === 'function' ? window.t(k) : null; return (v && v !== k) ? v : null; };
  setStatSub('pending-requests-note', pending.length > 0 ? (_tSafe('tech_action_needed') || 'Action needed') : (_tSafe('tech_no_pending') || 'All clear'));

  // Outstanding balance stat card
  const outstandingHtml = `${outstandingAmount.toLocaleString('en-US')} <span data-i18n="currency_egp">EGP</span>`;
  const outstandingEl = document.querySelector('[data-stat="outstanding-balance"]');
  if (outstandingEl) outstandingEl.innerHTML = outstandingHtml;

  // Cache snapshot so refresh shows last-known numbers immediately instead of
  // flashing the skeleton placeholder before the API responds.
  try {
    const pendingNote = pending.length > 0
      ? (_tSafe('tech_action_needed') || 'Action needed')
      : (_tSafe('tech_no_pending') || 'All clear');
    localStorage.setItem(TECH_STATS_CACHE_KEY, JSON.stringify({
      totalJobs: totalCount > bookings.length ? totalCount : nonCancelled.length,
      totalJobsMonthSub: `+${monthJobs} ${_t('tech_stat_this_month') || 'this month'}`,
      monthEarningsLabel: monthEarnings > 0 ? `EGP ${monthEarnings.toLocaleString('en-US')}` : 'EGP 0',
      monthEarningsChange: deltaStr,
      pendingRequests: pending.length,
      pendingRequestsNote: pendingNote,
      outstandingHtml,
      ts: Date.now()
    }));
  } catch { /* quota */ }

  // Notification badge = pending requests
  updateTopbarBadge(pending.length);

  // Update welcome sub-text with real pending count
  document.querySelectorAll('[data-dash-status-sub], .dash-welcome__sub').forEach(el => {
    let subText;
    if (pending.length === 0) {
      subText = _t('tech_no_requests') || 'No new requests right now.';
    } else if (pending.length === 1) {
      subText = _t('tech_n_requests') ? _t('tech_n_requests').replace('{n}', 1) : 'You have 1 new job request waiting.';
    } else {
      const key = _t('tech_n_requests_plural') || `You have ${pending.length} new job requests waiting.`;
      subText = key.replace('{n}', pending.length);
    }
    el.textContent = subText;
  });

  // Populate earnings panel.
  // Dual-writer guard: renderCanonicalEarningsPanel and populateEarningsLegacy
  // both write to the SAME DOM ids (walletAvailable, walletPending,
  // liabilityAmount, etc.). Exactly ONE renderer may run per cycle, otherwise
  // the second write clobbers the first and produces inconsistent UI.
  // The canonical breakdown (earnings.breakdown) is the source of truth when
  // present; absence indicates the /workers/me/earnings endpoint failed or
  // returned a partial payload, so fall back to the legacy reducer path.
  if (earnings?.breakdown) {
    renderCanonicalEarningsPanel({
      bookings,
      completed,
      cashCompleted,
      monthEarnings,
      lastMonthEarnings,
      outstandingAmount,
      earnings,
    });
  } else {
    populateEarningsLegacy(
      bookings,
      completed,
      monthEarnings,
      lastMonthEarnings,
      cashCompleted,
      outstandingAmount
    );
  }

  // Populate overview panels
  populateOverviewIncoming(pending);
  populateOverviewSchedule(bookings);

  // Load notifications from backend API
  loadNotifications();
  setInterval(loadNotifications, 20_000);

  return { bookings, pending, completed, monthEarnings, outstandingAmount };
}

// ── Available Now Toggle ──────────────────────────────────────────────────────
// Connects the toggle to PATCH /users/me/available with debounce + UI feedback
function updateSidebarAvailabilityStatus(isOn) {
  const safeT = (key, fallback) => {
    const value = typeof window.t === 'function' ? window.t(key) : null;
    return value && value !== key ? value : fallback;
  };
  const label = isOn
    ? safeT('tech_dash_available', 'Available')
    : safeT('tech_dash_unavailable', 'Offline');
  const labelKey = isOn ? 'tech_dash_available' : 'tech_dash_unavailable';
  document.querySelectorAll('[data-sidebar-availability]').forEach(chip => {
    chip.classList.toggle('is-available', !!isOn);
    chip.classList.toggle('is-offline', !isOn);
    chip.setAttribute('aria-label', label);
  });
  document.querySelectorAll('[data-sidebar-availability-label]').forEach(el => {
    el.setAttribute('data-i18n', labelKey);
    el.textContent = label;
  });
}

function initAvailableNowToggle(initialState) {
  const toggle = document.getElementById('avail-now-toggle');
  const card = document.getElementById('avail-now-card');
  const pill = document.getElementById('avail-now-pill');
  const icon = document.getElementById('avail-now-icon');
  if (!toggle) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  function applyUIState(isOn) {
    const safeT = (k, def) => {
      const r = _t(k);
      return (r === k || !r) ? def : r;
    };
    toggle.checked = isOn;
    updateSidebarAvailabilityStatus(isOn);
    if (card) card.classList.toggle('is-active', isOn);
    if (pill) {
      pill.textContent = isOn ? safeT('avail_status_online', 'Online') : safeT('avail_status_offline', 'Offline');
      pill.classList.toggle('is-online', isOn);
    }

    // When offline: visually mark all day rows as not available
    const scheduleEl = document.getElementById('avail-schedule');
    if (scheduleEl) {
      scheduleEl.querySelectorAll('.avail-day-row').forEach(row => {
        if (!isOn) {
          row.classList.add('is-toggled-offline');
          const chip = row.querySelector('.avail-day-toggle-chip');
          if (chip) chip.setAttribute('aria-disabled', 'true');
          const times = row.querySelector('.avail-day-row__times');
          if (times) times.style.opacity = '0.3';
        } else {
          row.classList.remove('is-toggled-offline');
          const chip = row.querySelector('.avail-day-toggle-chip');
          if (chip) chip.removeAttribute('aria-disabled');
          const times = row.querySelector('.avail-day-row__times');
          if (times) times.style.opacity = '';
        }
      });
    }
  }

  // Seed from API state
  applyUIState(!!initialState);

  let debounceTimer = null;
  toggle.addEventListener('change', () => {
    const isOn = toggle.checked;
    applyUIState(isOn);

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(async () => {
      toggle.disabled = true;
      try {
        await toggleAvailableNow(isOn);
        // Persist to session
        try {
          const s = JSON.parse(localStorage.getItem('servio_session') || '{}');
          s.isAvailable = isOn;
          localStorage.setItem('servio_session', JSON.stringify(s));
        } catch (_) { }
        try {
          const acc = JSON.parse(localStorage.getItem('servio_account') || '{}');
          acc.isAvailable = isOn;
          localStorage.setItem('servio_account', JSON.stringify(acc));
        } catch (_) { }
        const _tSafe2 = (k, def) => { const v = _t(k); return (v && v !== k) ? v : def; };
        const msg = isOn
          ? _tSafe2('toast_avail_on', 'You are now visible and accepting bookings.')
          : _tSafe2('toast_avail_off', 'You are now offline. New bookings are paused.');
        showToast(msg, isOn ? 'success' : 'info');
      } catch (err) {
        // Revert on error
        applyUIState(!isOn);
        showToast(err?.message || 'Failed to update availability.', 'error');
      } finally {
        toggle.disabled = false;
      }
    }, 350);
  });
}

// ── Weekly Schedule Builder ────────────────────────────────────────────────────
// Renders structured day rows with AM/PM dropdowns, on/off chip, and validation
function initAvailabilitySchedule(savedSlots) {
  const container = document.getElementById('avail-schedule');
  if (!container) return;
  const T = typeof window.t === 'function' ? window.t.bind(window) : (k) => k;

  const DAY_CONFIGS = [
    { key: 'monday', label: T('avail_day_mon') || 'Monday', abbr: 'MON', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'tuesday', label: T('avail_day_tue') || 'Tuesday', abbr: 'TUE', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'wednesday', label: T('avail_day_wed') || 'Wednesday', abbr: 'WED', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'thursday', label: T('avail_day_thu') || 'Thursday', abbr: 'THU', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'friday', label: T('avail_day_fri') || 'Friday', abbr: 'FRI', defaultFrom: '09:00', defaultTo: '17:00' },
    { key: 'saturday', label: T('avail_day_sat') || 'Saturday', abbr: 'SAT', defaultFrom: '10:00', defaultTo: '15:00' },
    { key: 'sunday', label: T('avail_day_sun') || 'Sunday', abbr: 'SUN', defaultFrom: '10:00', defaultTo: '15:00' },
  ];

  // Build half-hour time options for dropdown
  function buildTimeOptions() {
    const opts = [];
    for (let h = 6; h <= 23; h++) {
      for (const m of [0, 30]) {
        const pad = n => String(n).padStart(2, '0');
        const val = `${pad(h)}:${pad(m)}`;
        const h12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
        const ampm = h >= 12 ? 'PM' : 'AM';
        const lbl = `${h12}:${pad(m)} ${ampm}`;
        opts.push({ val, lbl });
      }
    }
    return opts;
  }
  const TIME_OPTIONS = buildTimeOptions();

  function makeSelect(id, selectedVal) {
    const sel = document.createElement('select');
    sel.className = 'avail-time-select';
    sel.id = id;
    sel.setAttribute('aria-label', id);
    TIME_OPTIONS.forEach(({ val, lbl }) => {
      const opt = document.createElement('option');
      opt.value = val;
      opt.textContent = lbl;
      if (val === selectedVal) opt.selected = true;
      sel.appendChild(opt);
    });
    return sel;
  }

  function validateRow(fromSel, toSel) {
    const fromVal = fromSel.value;
    const toVal = toSel.value;
    const isValid = toVal > fromVal;
    toSel.classList.toggle('is-error', !isValid);
    return isValid;
  }

  container.innerHTML = '';

  DAY_CONFIGS.forEach(day => {
    const savedSlot = (savedSlots || []).find(s => s.day === day.key);
    const isActive = !!savedSlot;
    const fromVal = savedSlot?.from || day.defaultFrom;
    const toVal = savedSlot?.to || day.defaultTo;

    const row = document.createElement('div');
    row.className = `avail-day-row${isActive ? '' : ' is-off'}`;
    row.dataset.day = day.key;

    // Day name
    const nameEl = document.createElement('span');
    nameEl.className = 'avail-day-row__name';
    nameEl.textContent = day.abbr;
    nameEl.title = day.label;

    // Time selects
    const timesDiv = document.createElement('div');
    timesDiv.className = 'avail-day-row__times';
    const fromSel = makeSelect(`avail-from-${day.key}`, fromVal);
    const sep = document.createElement('span');
    sep.className = 'avail-day-row__sep';
    sep.textContent = T('avail_to') || 'to';
    const toSel = makeSelect(`avail-to-${day.key}`, toVal);
    timesDiv.append(fromSel, sep, toSel);

    // Validate on change
    function onTimeChange() { validateRow(fromSel, toSel); }
    fromSel.addEventListener('change', onTimeChange);
    toSel.addEventListener('change', onTimeChange);

    // On/Off chip
    const chip = document.createElement('button');
    const safeT = (k, def) => {
      const v = T(k);
      return (v === k || !v) ? def : v;
    };
    chip.type = 'button';
    chip.className = `avail-day-toggle-chip${isActive ? ' is-on' : ''}`;
    chip.textContent = isActive ? safeT('avail_working', 'Working') : safeT('avail_day_off', 'Not Available');
    chip.setAttribute('aria-pressed', String(isActive));
    chip.addEventListener('click', () => {
      const nowOn = !chip.classList.contains('is-on');
      chip.classList.toggle('is-on', nowOn);
      chip.textContent = nowOn ? safeT('avail_working', 'Working') : safeT('avail_day_off', 'Not Available');
      chip.setAttribute('aria-pressed', String(nowOn));
      row.classList.toggle('is-off', !nowOn);
      timesDiv.style.visibility = nowOn ? '' : 'hidden';
    });
    if (!isActive) timesDiv.style.visibility = 'hidden';

    row.append(nameEl, timesDiv, chip);
    container.appendChild(row);
  });

  // Clear All handler
  document.getElementById('avail-clear-schedule')?.addEventListener('click', () => {
    const safeT = (k, def) => {
      const v = T(k);
      return (v === k || !v) ? def : v;
    };
    container.querySelectorAll('.avail-day-row').forEach(row => {
      row.classList.add('is-off');
      const chip = row.querySelector('.avail-day-toggle-chip');
      if (chip) {
        chip.classList.remove('is-on');
        chip.textContent = safeT('avail_day_off', 'Not Available');
        chip.setAttribute('aria-pressed', 'false');
      }
      const times = row.querySelector('.avail-day-row__times');
      if (times) times.style.visibility = 'hidden';
    });
  });
}

function initBlockedDatesCalendar(workerAvailability, initialBlockedDates) {
  let blockedDates = new Set(initialBlockedDates || []);
  let currentYear = new Date().getFullYear();
  let currentMonth = new Date().getMonth();

  const DAY_NAMES = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const avDays = (workerAvailability || []).map(a => a.day);

  function renderBlockedCal() {
    const grid = document.getElementById('blockedCalGrid');
    const label = document.getElementById('blockedCalLabel');
    const prev = document.getElementById('blockedCalPrev');
    const next = document.getElementById('blockedCalNext');
    if (!grid) return;

    const today = new Date(); today.setHours(0, 0, 0, 0);
    const maxDate = new Date(); maxDate.setDate(maxDate.getDate() + 60); maxDate.setHours(0, 0, 0, 0);
    const firstDay = new Date(currentYear, currentMonth, 1);
    const lastDay = new Date(currentYear, currentMonth + 1, 0);
    const prevEnd = new Date(currentYear, currentMonth, 0);
    const nextStart = new Date(currentYear, currentMonth + 1, 1);

    if (label) label.textContent = firstDay.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    if (prev) prev.disabled = prevEnd < today;
    if (next) next.disabled = nextStart > maxDate;

    let html = '';
    for (let i = 0; i < firstDay.getDay(); i++) html += '<div class="bcal-day bcal-day--empty"></div>';

    for (let d = 1; d <= lastDay.getDate(); d++) {
      const date = new Date(currentYear, currentMonth, d);
      const dateStr = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const isPast = date < today;
      const isFar = date > maxDate;
      const isToday = date.getTime() === today.getTime();
      const dayName = DAY_NAMES[date.getDay()];
      const isOffSched = avDays.length > 0 && !avDays.includes(dayName);
      const isBlocked = blockedDates.has(dateStr);

      let cls = 'bcal-day';
      if (isToday) cls += ' bcal-day--today';
      if (isPast || isFar) cls += ' bcal-day--past';
      else if (isOffSched) cls += ' bcal-day--off-schedule';
      else if (isBlocked) cls += ' bcal-day--blocked';
      else cls += ' bcal-day--working';

      const canClick = !isPast && !isFar && !isOffSched;
      html += `<div class="${cls}" ${canClick ? `data-date="${dateStr}"` : ''}>${d}</div>`;
    }

    grid.innerHTML = html;

    grid.querySelectorAll('.bcal-day[data-date]').forEach(cell => {
      cell.addEventListener('click', async () => {
        const d = cell.dataset.date;
        try {
          await toggleBlockedDate(d);
          if (blockedDates.has(d)) blockedDates.delete(d);
          else blockedDates.add(d);
          renderBlockedCal();
          // Show brief feedback
          const fb = document.getElementById('blocked-dates-feedback');
          if (fb) { fb.hidden = false; setTimeout(() => { fb.hidden = true; }, 2000); }
        } catch (err) {
          console.error('Failed to toggle blocked date:', err);
        }
      });
    });
  }

  document.getElementById('blockedCalPrev')?.addEventListener('click', () => {
    currentMonth--;
    if (currentMonth < 0) { currentMonth = 11; currentYear--; }
    renderBlockedCal();
  });
  document.getElementById('blockedCalNext')?.addEventListener('click', () => {
    currentMonth++;
    if (currentMonth > 11) { currentMonth = 0; currentYear++; }
    renderBlockedCal();
  });

  renderBlockedCal();
}

async function initJobQueue(restoreTab = null) {
  const container = document.getElementById('job-queue-list');
  if (!container) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  const showMsg = (text, color = '#6b7280') =>
  (container.innerHTML = `<div style="display:flex;flex-direction:column;align-items:center;padding:48px 24px;gap:12px;text-align:center;">
      <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="${color}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" opacity="0.5"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/></svg>
      <p style="color:${color};font-size:0.95rem;margin:0;">${text}</p>
    </div>`);

  // Loading state — shimmer skeleton
  container.innerHTML = skCardGrid(4, { wide: true });

  let bookings = [];
  try {
    const res = await getWorkerBookings({ limit: 50 });
    // Backend returns { bookings: [...], pagination: {...} }
    bookings = Array.isArray(res) ? res : (res?.bookings || []);
    updateSidebarIndicators(bookings);
  } catch (err) {
    showMsg('Failed to load jobs. Please refresh.', '#dc2626');
    console.error('[Job Queue] API error:', err);
    return;
  }

  if (bookings.length === 0) {
    showMsg('No jobs assigned yet. Bookings from customers will appear here.');
    return;
  }

  const pending = bookings.filter(b => b.status === 'pending');
  const ongoing = bookings.filter(b => ['accepted', 'en_route', 'arrived', 'in_progress'].includes(b.status));
  const waiting = bookings.filter(b => ['awaiting_customer_confirmation', 'pending_admin_review'].includes(b.status));
  const done = bookings.filter(b => b.status === 'completed');
  const cancelled = bookings.filter(b => ['cancelled', 'rejected'].includes(b.status));

  // Default tab: preserve caller's active sub-tab, else show active > pending > waiting > done
  const defaultTab = restoreTab || (ongoing.length ? 'active' : pending.length ? 'pending' : waiting.length ? 'waiting' : done.length ? 'done' : 'cancelled');

  function badgeHtml(n) {
    return n > 0 ? `<span class="jq-tab-badge">${n}</span>` : '';
  }

  function makePane(id, items, emptyMsg) {
    const pane = document.createElement('div');
    pane.id = `stab-jq-${id}`;
    pane.className = 'stab-pane jq-tab-pane';
    if (id !== defaultTab) pane.setAttribute('hidden', '');
    else pane.classList.add('stab-pane--active');

    if (items.length === 0) {
      pane.innerHTML = `<div class="jq-empty-state"><svg viewBox="0 0 24 24" width="36" height="36" fill="none" stroke="#6b7280" stroke-width="1.5" opacity="0.4"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 00-2-2h-4a2 2 0 00-2 2v2"/></svg><p>${emptyMsg}</p></div>`;
    } else {
      const list = document.createElement('div');
      list.className = 'jq-queue-list';
      items.forEach(b => {
        try { list.appendChild(buildJobCard(b, _t)); }
        catch (e) { console.error('[Job Queue] card error', b._id, e); }
      });
      pane.appendChild(list);
    }
    return pane;
  }

  container.innerHTML = '';

  // ── Tab bar ──
  const tabBar = document.createElement('nav');
  tabBar.id = 'jq-tab-bar';
  tabBar.className = 'stab-bar jq-stab-bar';
  tabBar.setAttribute('role', 'tablist');
  tabBar.innerHTML = `
    <button class="stab-btn${defaultTab === 'pending' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'pending'}" data-stab="jq-pending">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9"/><path d="M12 8v4l2 2"/></svg>
      Awaiting Response${badgeHtml(pending.length)}
    </button>
    <button class="stab-btn${defaultTab === 'active' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'active'}" data-stab="jq-active">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><polyline points="13 2 13 9 20 9"/><path d="M21 3L13 11l-4-4L2 14"/></svg>
      Active Jobs${badgeHtml(ongoing.length)}
    </button>
    <button class="stab-btn${defaultTab === 'waiting' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'waiting'}" data-stab="jq-waiting">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/><path d="M8 3.5 6 6M16 3.5 18 6"/></svg>
      Waiting${badgeHtml(waiting.length)}
    </button>
    <button class="stab-btn${defaultTab === 'done' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'done'}" data-stab="jq-done">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><polyline points="20 6 9 17 4 12"/></svg>
      Completed${badgeHtml(done.length)}
    </button>
    <button class="stab-btn${defaultTab === 'cancelled' ? ' stab-btn--active' : ''}" role="tab"
      aria-selected="${defaultTab === 'cancelled'}" data-stab="jq-cancelled">
      <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9"/><path d="M15 9l-6 6M9 9l6 6"/></svg>
      Cancelled${badgeHtml(cancelled.length)}
    </button>`;
  container.appendChild(tabBar);

  // ── Panes ──
  container.appendChild(makePane('pending', pending, 'No pending requests.'));
  container.appendChild(makePane('active', ongoing, 'No active jobs right now.'));
  container.appendChild(makePane('waiting', waiting, 'No jobs are waiting on customer confirmation or release.'));
  container.appendChild(makePane('done', done, 'No completed jobs yet.'));
  container.appendChild(makePane('cancelled', cancelled, 'No cancelled jobs.'));

  // ── Tab switching ──
  tabBar.addEventListener('click', e => {
    const btn = e.target.closest('.stab-btn');
    if (!btn) return;
    const target = btn.dataset.stab;
    tabBar.querySelectorAll('.stab-btn').forEach(b => {
      b.classList.toggle('stab-btn--active', b === btn);
      b.setAttribute('aria-selected', b === btn ? 'true' : 'false');
    });
    container.querySelectorAll('.jq-tab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
  });

  wireArrivalFlows(container);
  revealAll(container);
}

/* ── Job Flow Modal ──────────────────────────────────────────────────────── */
function ensureJobModal() {
  if (document.getElementById('jq-modal')) return;
  const el = document.createElement('div');
  el.id = 'jq-modal';
  el.className = 'jq-modal-overlay';
  el.innerHTML = `<div class="jq-modal-box" role="dialog" aria-modal="true"><div class="jq-modal-inner"></div></div>`;
  document.body.appendChild(el);
  el.addEventListener('click', e => { if (e.target === el) closeJobModal(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeJobModal(); });
}
function openJobModal(html) {
  ensureJobModal();
  const overlay = document.getElementById('jq-modal');
  overlay.querySelector('.jq-modal-inner').innerHTML = html;
  overlay.classList.add('is-open');
  document.body.style.overflow = 'hidden';
}
function closeJobModal() {
  const overlay = document.getElementById('jq-modal');
  if (!overlay) return;
  overlay.classList.remove('is-open');
  document.body.style.overflow = '';
}

/* ── Duration-override modal (shown before accepting a job) ──────────────── */
const DURATION_PRESETS = [30, 60, 90, 120, 180, 240];

function openAcceptModal({ defaultDurationMin, onConfirm, jobContext = {} }) {
  const { service = '', notes = '' } = jobContext;
  const presetsHtml = DURATION_PRESETS.map(m => {
    const label = m < 60 ? `${m}m` : m % 60 === 0 ? `${m / 60}h` : `${Math.floor(m / 60)}h${m % 60}m`;
    return `<button type="button" class="accept-modal__preset${m === defaultDurationMin ? ' is-active' : ''}" data-preset="${m}">${label}</button>`;
  }).join('');

  const wrap = document.createElement('div');
  wrap.className = 'modal-backdrop';
  wrap.innerHTML = `
    <div class="modal accept-modal">
      <div class="accept-modal__header">
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>
        <h3>Accept Job</h3>
      </div>
      ${service ? `<div class="accept-modal__service">${service}</div>` : ''}
      ${notes ? `<div class="accept-modal__notes"><span>Customer note:</span> ${notes}</div>` : ''}
      <div class="accept-modal__duration-label">
        How long do you estimate this will take?
        <span class="accept-modal__duration-hint">You can update this on-site</span>
      </div>
      <div class="accept-modal__presets">${presetsHtml}</div>
      <div class="accept-modal__custom-row">
        <label for="accept-duration">Custom (min)</label>
        <input type="number" id="accept-duration" min="15" max="480" step="15" value="${defaultDurationMin}" placeholder="e.g. 90">
      </div>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-action="cancel">Cancel</button>
        <button class="btn btn--accent accept-modal__confirm-btn" data-action="confirm">
          <svg viewBox="0 0 20 20" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="4,10 8,14 16,6"/></svg>
          Confirm &amp; Accept
        </button>
      </div>
    </div>`;

  document.body.appendChild(wrap);

  const input = wrap.querySelector('#accept-duration');

  wrap.querySelectorAll('.accept-modal__preset').forEach(btn => {
    btn.addEventListener('click', () => {
      wrap.querySelectorAll('.accept-modal__preset').forEach(b => b.classList.remove('is-active'));
      btn.classList.add('is-active');
      input.value = btn.dataset.preset;
    });
  });

  input.addEventListener('input', () => {
    wrap.querySelectorAll('.accept-modal__preset').forEach(b => b.classList.remove('is-active'));
  });

  wrap.querySelector('[data-action="cancel"]').addEventListener('click', () => wrap.remove());
  wrap.querySelector('[data-action="confirm"]').addEventListener('click', () => {
    const val = Number(input.value);
    if (!Number.isFinite(val) || val < 15 || val > 480) {
      input.style.borderColor = '#ef4444';
      input.focus();
      return;
    }
    wrap.remove();
    onConfirm(val);
  });

  setTimeout(() => input.focus(), 50);
}

/* ── Update estimate modal (usable after accepting, any active state) ─────── */
function openUpdateEstimateModal({ currentMin, onConfirm }) {
  const presetsHtml = DURATION_PRESETS.map(m => {
    const label = m < 60 ? `${m}m` : m % 60 === 0 ? `${m / 60}h` : `${Math.floor(m / 60)}h${m % 60}m`;
    return `<button type="button" class="accept-modal__preset${m === currentMin ? ' is-active' : ''}" data-preset="${m}">${label}</button>`;
  }).join('');

  const wrap = document.createElement('div');
  wrap.className = 'modal-backdrop';
  wrap.innerHTML = `
    <div class="modal accept-modal">
      <div class="accept-modal__header">
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
        <h3>Update Duration Estimate</h3>
      </div>
      <p style="font-size:0.88rem;color:var(--color-text-secondary,#aaa);margin:0">Revise your estimate based on what you've found on-site. The customer will be notified.</p>
      <div class="accept-modal__presets">${presetsHtml}</div>
      <div class="accept-modal__custom-row">
        <label for="update-duration">Custom (min)</label>
        <input type="number" id="update-duration" min="15" max="480" step="15" value="${currentMin || 60}" placeholder="e.g. 90">
      </div>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-action="cancel">Cancel</button>
        <button class="btn btn--accent" data-action="confirm">Update Estimate</button>
      </div>
    </div>`;

  document.body.appendChild(wrap);

  const input = wrap.querySelector('#update-duration');
  wrap.querySelectorAll('.accept-modal__preset').forEach(btn => {
    btn.addEventListener('click', () => {
      wrap.querySelectorAll('.accept-modal__preset').forEach(b => b.classList.remove('is-active'));
      btn.classList.add('is-active');
      input.value = btn.dataset.preset;
    });
  });
  input.addEventListener('input', () => {
    wrap.querySelectorAll('.accept-modal__preset').forEach(b => b.classList.remove('is-active'));
  });
  wrap.querySelector('[data-action="cancel"]').addEventListener('click', () => wrap.remove());
  wrap.querySelector('[data-action="confirm"]').addEventListener('click', () => {
    const val = Number(input.value);
    if (!Number.isFinite(val) || val < 15 || val > 480) {
      input.style.borderColor = '#ef4444';
      input.focus();
      return;
    }
    wrap.remove();
    onConfirm(val);
  });
}

/* ── Progress Stepper ────────────────────────────────────────────────────── */
function buildStepperHtml(localState) {
  const steps = ['Accepted', 'En Route', 'Arrived', 'Working', 'Done'];
  const idx = { accepted: 0, 'en-route': 1, arrived: 2, 'in-progress': 3, 'complete-confirm': 3, done: 4 };
  const cur = idx[localState] ?? 0;
  const checkSvg = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>`;

  return `
    <div class="jq-stepper-container">
      <div class="jq-stepper">
        ${steps.map((label, i) => {
    const done = i < cur;
    const active = i === cur;
    let stateClass = '';
    if (done) stateClass = 'is-done';
    else if (active) stateClass = 'is-active';

    return `
            <div class="jq-step ${stateClass}">
              <div class="jq-step__indicator">
                ${done ? checkSvg : `<span>${i + 1}</span>`}
              </div>
              <span class="jq-step__label">${label}</span>
            </div>
            ${i < steps.length - 1 ? `<div class="jq-step-line ${done ? 'is-done' : (i === cur ? 'is-active' : '')}"></div>` : ''}
          `;
  }).join('')}
      </div>
    </div>
  `;
}

/* ─────────────────────────────────────────────────────────────────────────── */
function buildJobCard(b, _t) {
  const id = b._id;
  const shortId = id.slice(-6).toUpperCase();
  const service = b.serviceName || b.service?.title || b.serviceCategory || 'Service';
  const badge = (b.serviceCategory || b.service?.category || 'service').replace(/_/g, ' ').toUpperCase();
  const customer = b.user?.name || '—';
  const address = b.address || '—';
  const mapsUrl = `https://maps.google.com/?q=${encodeURIComponent(address)}`;
  const date = b.scheduledDate
    ? new Date(b.scheduledDate).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' })
    : '—';
  const time = b.scheduledTime || '';
  const price = b.totalPrice != null ? `${Number(b.totalPrice).toLocaleString('en-US')} EGP` : '—';
  const payment = b.paymentMethod === 'cash' ? 'Cash' : 'Credit Card';
  const pin = b.pin || '';
  const category = b.serviceCategory || b.service?.category || 'other';
  const _rawIconSvg = (CATEGORY_ICONS[category] || CATEGORY_ICONS.other || '');
  const notesRaw = String(b.description || '').trim();
  const notesText = notesRaw ? escapeHtml(notesRaw) : 'No customer notes provided.';
  const notesCard = `
    <div class="jq-customer-notes ${notesRaw ? '' : 'is-empty'}">
      <div class="jq-customer-notes__label">
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H8l-5 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
        Customer notes
      </div>
      <p class="jq-customer-notes__text">${notesText}</p>
    </div>`;

  const statusCfg = {
    pending: { label: 'Pending Acceptance', dot: 'amber' },
    accepted: { label: 'Accepted', dot: 'blue' },
    en_route: { label: 'En Route', dot: 'blue' },
    arrived: { label: 'Arrived', dot: 'amber' },
    in_progress: { label: 'In Progress', dot: 'purple' },
    awaiting_customer_confirmation: { label: 'Waiting for Customer', dot: 'amber' },
    pending_admin_review: b.paymentMethod === 'cash'
      ? { label: 'Cash Review', dot: 'blue' }
      : { label: 'Pending Release', dot: 'blue' },
    completed: { label: 'Completed', dot: 'green' },
    cancelled: { label: 'Cancelled', dot: 'grey' },
    rejected: { label: 'Declined', dot: 'grey' },
  };
  const { label: statusLabel, dot: dotColor } = statusCfg[b.status] || { label: b.status, dot: 'grey' };
  const isActive = ['accepted', 'en_route', 'arrived', 'in_progress'].includes(b.status);

  let flowHtml = '';
  if (b.status === 'pending') {
    flowHtml = `
      <div class="jq-flow" data-booking-id="${id}" data-pin="${pin}"
        data-customer="${customer}" data-address="${address}"
        data-date="${date}" data-time="${time}" data-price="${price}" data-payment="${payment}" data-service="${service}" data-notes="${escapeHtml(notesRaw)}">
        <div class="jq-section" data-section="pending">
          <div class="jq-premium-actions">
            <button class="btn-premium btn-premium--primary" data-flow-action="accept">
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
              See Details
            </button>
            <button class="btn-premium btn-premium--danger-outline" data-flow-action="decline">
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              Decline
            </button>
          </div>
        </div>
      </div>`;
  } else if (['accepted', 'en_route', 'arrived', 'in_progress'].includes(b.status)) {
    flowHtml = `
      <div class="jq-flow" data-booking-id="${id}" data-pin="${pin}" data-customer="${customer}" data-address="${address}" data-estimated-duration-min="${b.estimatedDurationMin || 60}">
        <div class="jq-section" data-section="accepted">
          <div class="jq-accepted-action-bar">
            <div class="jq-nav-info">
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="12" r="3"/></svg>
              <span class="truncate">${address}</span>
            </div>
            <div class="jq-accepted-actions">
              <a class="btn-premium btn-premium--accent btn-premium--sm" href="${mapsUrl}" target="_blank" rel="noopener">Navigate</a>
              <button class="btn-premium btn-premium--primary btn-premium--sm" data-flow-action="on-my-way">
                I'm On My Way
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
              </button>
            </div>
          </div>
        </div>
        <div class="jq-section" data-section="en-route" hidden>
          <div class="jq-accepted-action-bar">
            <div class="jq-nav-info">
              <div class="jq-pulse-indicator jq-pulse-indicator--sm">
                <span class="pulse-dot"></span>
                <span class="pulse-ring"></span>
              </div>
              <span class="jq-enroute-label">EN ROUTE</span>
              <span class="jq-enroute-sep">·</span>
              <span class="truncate">${address}</span>
            </div>
            <div class="jq-accepted-actions">
              <a class="btn-premium btn-premium--blue btn-premium--sm" href="${mapsUrl}" target="_blank" rel="noopener">Maps</a>
              <button class="btn-premium btn-premium--primary btn-premium--sm" data-flow-action="arrived">
                I've Arrived
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="12" r="3"/></svg>
              </button>
            </div>
          </div>
        </div>
        <div class="jq-section" data-section="arrived" hidden>
          <div class="jq-premium-pin-card">
            <div class="jq-pin-icon-box">
              <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
            </div>
            <div class="jq-pin-content">
              <h4>Customer Verification</h4>
              <p>Ask <strong>${customer}</strong> for their 4-digit PIN</p>
            </div>
          </div>
          <div class="jq-premium-pin-group" data-pin-group>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
            <input type="text" inputmode="numeric" maxlength="1" class="jq-pin-box" autocomplete="off"/>
          </div>
          <p class="jq-pin-error" hidden>Incorrect PIN — please try again.</p>
          <div class="jq-flow-footer">
            <button class="btn-premium btn-premium--amber" data-flow-action="start-job">
              <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
              Verify &amp; Start Job
            </button>
            <button class="btn-premium btn-premium--red" data-flow-action="customer-no-show" style="margin-left:8px;">
              Mark Customer No-Show
            </button>
          </div>
        </div>
        <div class="jq-section" data-section="in-progress" hidden>
          <div class="jq-premium-timer-card">
            <div class="jq-timer-split">
              <div class="jq-timer-left">
                <div class="jq-timer-live-indicator">
                  <div class="jq-timer-live-dot"></div>
                  <span class="jq-timer-status-label">In Progress</span>
                </div>
                <div class="jq-timer-clock-row">
                  <div class="jq-timer-text" id="timer-${id}">00:00:00</div>
                  <span class="jq-timer-pill">LIVE</span>
                </div>
              </div>
              <div class="jq-timer-split-divider"></div>
              <div class="jq-timer-right">
                <button class="btn-premium btn-premium--emerald" data-flow-action="complete">
                  <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
                  Mark Job Complete
                </button>
                <a href="./messages.html?booking=${id}" class="jq-timer-chat-btn" target="_blank">
                  <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                  Message Customer
                </a>
                <button class="jq-timer-chat-btn" data-flow-action="update-estimate" style="border-color:rgba(166,110,88,0.4);color:var(--color-accent,#D9A28B);">
                  <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
                  Update Estimate
                </button>
              </div>
            </div>
          </div>
        </div>
        <div class="jq-section" data-section="complete-confirm" hidden>
          <div class="jq-confirm-strip">
            <div class="jq-confirm-strip__icon">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
            </div>
            <div class="jq-confirm-strip__text">
              <h4>Confirm Completion</h4>
              <p>Ensure all work is finished before submitting.</p>
            </div>
          </div>
          <div class="jq-completion-entry">
            <div class="jq-notes-field jq-notes-field--work">
              <label>Work done <span>(optional)</span></label>
              <div class="jq-work-field-wrap">
                <textarea class="jq-notes-textarea" placeholder="Describe the work completed..." maxlength="400" rows="2"></textarea>
                <label class="jq-proof-upload jq-proof-upload--inline" title="Add completion image" aria-label="Add completion image">
                  <input class="jq-completion-image-input" type="file" accept="image/jpeg,image/png,image/webp" hidden>
                  <span class="jq-proof-upload__icon">
                    <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
                  </span>
                  <span class="jq-proof-upload__filename" data-completion-file>JPG, PNG, or WEBP up to 5 MB</span>
                </label>
              </div>
            </div>
            <div class="jq-completion-separator" aria-hidden="true"></div>
            <div class="jq-completion-side">
              <button class="btn-premium btn-premium--primary jq-submit-completion-btn" data-flow-action="submit-complete">Submit Completion</button>
            </div>
          </div>
        </div>
      </div>`;
  } else if (b.status === 'awaiting_customer_confirmation') {
    const workerNotesText = escapeHtml(b.workerNotes || '');
    const proofImg = (Array.isArray(b.workerCompletionImages) && b.workerCompletionImages[0]) || '';
    flowHtml = `
      <div class="jq-done-banner">
        <div class="jq-done-icon">
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="4,12 9,17 20,6"/></svg>
        </div>
        <div class="jq-done-info">
          <p class="jq-done-label">Waiting for customer confirmation</p>
          <p class="jq-done-sub">${customer} has not confirmed the job yet.</p>
        </div>
        <div class="jq-done-earnings">${price}</div>
      </div>
      ${workerNotesText ? `<div class="jq-done-notes"><div class="jq-notes-label">Work done:</div><p>${workerNotesText}</p></div>` : ''}
      ${proofImg ? `<div class="jq-done-image"><img src="${proofImg}" alt="Completed work photo"></div>` : ''}`;
  } else if (b.status === 'pending_admin_review') {
    const isCashReview = b.paymentMethod === 'cash';
    const workerNotesText = escapeHtml(b.workerNotes || b.completionNotes || '');
    const proofImg = (Array.isArray(b.workerCompletionImages) && b.workerCompletionImages[0]) || (Array.isArray(b.completionPhotos) && b.completionPhotos[0]) || '';
    flowHtml = `
      <div class="jq-done-banner jq-done-banner--pending-release">
        <div class="jq-done-icon jq-done-icon--pending-release">
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
        </div>
        <div class="jq-done-info">
          <p class="jq-done-label">${isCashReview ? 'Cash Confirmation Review' : 'Pending Release'}</p>
          <p class="jq-done-sub">${isCashReview
            ? 'Customer paid cash. SERVIO is reconciling the commission record.'
            : 'Customer confirmed. SERVIO is finalizing payment release.'}</p>
        </div>
        <div class="jq-done-earnings jq-done-earnings--pending-release">${price}</div>
      </div>
      <div class="jq-status-note">${isCashReview
        ? 'Cash was collected directly. No payment release is required; SERVIO is checking the commission settlement record.'
        : 'This job is confirmed by the customer. Earnings appear as available after admin release approval.'}</div>
      ${workerNotesText ? `<div class="jq-done-notes"><div class="jq-notes-label">Work done:</div><p>${workerNotesText}</p></div>` : ''}
      ${proofImg ? `<div class="jq-done-image"><img src="${proofImg}" alt="Completed work photo"></div>` : ''}`;
  } else if (b.status === 'completed') {
    flowHtml = `
      <div class="jq-premium-completion">
        <div class="jq-completion-hero">
          <div class="jq-check-blob">
            <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
          </div>
          <div class="jq-completion-text">
            <h4>Job Completed</h4>
            <p>${customer}</p>
          </div>
        </div>
        <div class="jq-completion-value">${price}</div>
      </div>`;
  } else {
    flowHtml = '';
  }

  const article = document.createElement('article');
  article.className = `jq-premium-card status-${b.status}`.trim();
  article.id = `jq-${id}`;
  article.setAttribute('data-reveal', '');
  article.dataset.status = b.status;

  const serviceIconHtml = `
    <div class="jq-premium-icon-wrap jq-premium-icon-wrap--${dotColor}">
      ${_rawIconSvg.replace(/width="\d+" height="\d+"/g, 'width="28" height="28"')}
    </div>
  `;
  const identityIconSvg = _rawIconSvg.replace(/width="\d+" height="\d+"/g, 'width="20" height="20"');

  article.innerHTML = `
    <div class="jq-premium-card__header">
      <div class="jq-header-left">
        <span class="jq-premium-badge">${badge}</span>
        <span class="jq-premium-id">#${shortId}</span>
      </div>
      <div class="jq-premium-status jq-status--${dotColor}">
        <span class="status-dot"></span>
        <span class="status-label">${statusLabel}</span>
      </div>
    </div>

    ${isActive ? `
    <div class="jq-identity-bar">
      <div class="jq-identity-bar__icon jq-identity-bar__icon--${dotColor}">
        ${identityIconSvg}
      </div>
      <div class="jq-identity-bar__info">
        <div class="jq-identity-bar__name">
          <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          ${customer}
        </div>
        <div class="jq-identity-bar__sub">
          ${service}
          <span class="jq-identity-bar__sep">·</span>
          <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>
          ${address}
        </div>
      </div>
      <div class="jq-identity-bar__payout">
        <div class="jq-identity-bar__amount">${price}</div>
        <div class="jq-identity-bar__label">PAYOUT</div>
      </div>
    </div>
    <div class="jq-premium-stepper-wrap" id="stepper-${id}">${buildStepperHtml({ accepted: 'accepted', en_route: 'en-route', arrived: 'arrived', in_progress: 'in-progress' }[b.status] || 'accepted')}</div>
    ` : ''}

    <div class="jq-premium-card__body${isActive ? ' jq-premium-card__body--hidden' : ''}">
      <div class="jq-body-main">
        ${serviceIconHtml}
        <div class="jq-body-content">
          <h3 class="jq-premium-name">${customer}</h3>
          <div class="jq-premium-meta">
            <div class="meta-item">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="12" r="3"/></svg>
              <span>${address}</span>
            </div>
            <div class="meta-chips">
              <span class="meta-chip">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
                ${date}${time ? ' · ' + time : ''}
              </span>
              <span class="meta-chip">
                <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
                ${payment}
              </span>
            </div>
          </div>
          ${notesCard}
        </div>
      </div>
      <div class="jq-body-payout">
        <div class="payout-amount">${price}</div>
        <div class="payout-label">TOTAL PAYOUT</div>
      </div>
    </div>

    <div class="jq-premium-card__footer">
      ${flowHtml}
    </div>

    ${isActive ? `
    <button class="jq-details-toggle" data-details-toggle type="button">
      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>
      Job Details
    </button>
    <div class="jq-details-body" data-details-body>
      <div class="jq-details-inner">
        <div class="jq-details-row">
          <span>Date &amp; Time</span>
          <span>${date}${time ? ' · ' + time : ''}</span>
        </div>
        <div class="jq-details-row">
          <span>Payment</span>
          <span>${payment}</span>
        </div>
        <div class="jq-details-row jq-details-row--notes">
          <span>Notes</span>
          <span>${notesRaw ? escapeHtml(notesRaw) : 'None'}</span>
        </div>
      </div>
    </div>
    ` : ''}
  `;
  return article;
}

function wireArrivalFlows(container) {
  container.querySelectorAll('.jq-flow').forEach(flow => {
    const bookingId = flow.dataset.bookingId;
    const correctPin = flow.dataset.pin;
    const storeKey = `servio_flow_${bookingId}`;
    const timerKey = `servio_timer_${bookingId}`;
    let timerInterval = null;

    /* ── Section visibility ── */
    function showSection(name) {
      flow.querySelectorAll('.jq-section').forEach(s => { s.hidden = true; });
      const target = flow.querySelector(`[data-section="${name}"]`);
      if (target) target.hidden = false;
      localStorage.setItem(storeKey, name);
      const stepperWrap = document.getElementById(`stepper-${bookingId}`);
      if (stepperWrap) stepperWrap.innerHTML = buildStepperHtml(name);
      const _card = flow.closest('.jq-premium-card');
      _card?.querySelector('[data-details-body]')?.classList.remove('open');
      _card?.querySelector('[data-details-toggle]')?.classList.remove('open');
    }

    /* ── Timer (wall-clock based so refresh-safe) ── */
    function startTimer() {
      const el = document.getElementById(`timer-${bookingId}`);
      if (!el) return;
      clearInterval(timerInterval);
      let t0 = parseInt(localStorage.getItem(timerKey) || '0');
      if (!t0) { t0 = Date.now(); localStorage.setItem(timerKey, t0); }
      const tick = () => {
        const s = Math.floor((Date.now() - t0) / 1000);
        const h = String(Math.floor(s / 3600)).padStart(2, '0');
        const m = String(Math.floor((s % 3600) / 60)).padStart(2, '0');
        const sec = String(s % 60).padStart(2, '0');
        if (el) el.textContent = `${h}:${m}:${sec}`;
      };
      tick();
      timerInterval = setInterval(tick, 1000);
    }

    /* ── Restore persisted state on load ── */
    const stored = localStorage.getItem(storeKey);
    const backendState = { accepted: 'accepted', en_route: 'en-route', arrived: 'arrived', in_progress: 'in-progress' }[flow.closest('.jq-premium-card')?.dataset.status || ''];
    const initialState = stored || backendState;
    if (initialState) {
      showSection(initialState);
      if (initialState === 'in-progress') startTimer();
    }

    /* ── Job Details accordion ── */
    const _accordionCard = flow.closest('.jq-premium-card');
    _accordionCard?.querySelector('[data-details-toggle]')?.addEventListener('click', () => {
      const body = _accordionCard.querySelector('[data-details-body]');
      const toggle = _accordionCard.querySelector('[data-details-toggle]');
      if (!body) return;
      const isOpen = body.classList.toggle('open');
      toggle.classList.toggle('open', isOpen);
    });

    /* ── PIN box auto-advance + backspace ── */
    const pinGroup = flow.querySelector('[data-pin-group]');
    if (pinGroup) {
      const boxes = [...pinGroup.querySelectorAll('.jq-pin-box')];
      boxes.forEach((box, i) => {
        box.addEventListener('input', e => {
          const v = e.target.value.replace(/\D/g, '');
          e.target.value = v;
          box.classList.toggle('is-filled', !!v);
          if (v && i < boxes.length - 1) boxes[i + 1].focus();
        });
        box.addEventListener('keydown', e => {
          if (e.key === 'Backspace' && !box.value && i > 0) boxes[i - 1].focus();
        });
        box.addEventListener('paste', e => {
          e.preventDefault();
          const digits = (e.clipboardData.getData('text') || '').replace(/\D/g, '').slice(0, 4);
          [...digits].forEach((d, j) => { if (boxes[j]) boxes[j].value = d; });
          boxes[Math.min(digits.length, boxes.length - 1)]?.focus();
        });
      });
    }

    /* ── Accept modal ── */
    flow.querySelectorAll('.jq-completion-image-input').forEach(input => {
      input.addEventListener('change', () => {
        const file = input.files?.[0];
        const label = input.closest('.jq-proof-upload')?.querySelector('[data-completion-file]');
        const uploadBox = input.closest('.jq-proof-upload');
        uploadBox?.classList.remove('is-invalid');
        if (!file) {
          if (label) label.textContent = 'JPG, PNG, or WEBP up to 5 MB';
          return;
        }
        const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
        if (!allowedTypes.includes(file.type) || file.size > 5 * 1024 * 1024) {
          input.value = '';
          uploadBox?.classList.add('is-invalid');
          if (label) label.textContent = 'Choose a JPG, PNG, or WEBP under 5 MB';
          showToast('Completion image must be JPG, PNG, or WEBP under 5 MB.', 'error');
          return;
        }
        if (label) label.textContent = file.name;
        uploadBox?.classList.add('has-file');
      });
    });

    function showAcceptModal() {
      const { service, customer, address, date, time, price, payment, notes } = flow.dataset;
      const notesHtml = `
        <div class="jqm-notes-card ${notes ? '' : 'is-empty'}">
          <div class="jqm-notes-card__label">
            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H8l-5 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
            Customer notes
          </div>
          <p class="jqm-notes-card__text">${notes ? escapeHtml(notes) : 'No customer notes provided.'}</p>
        </div>`;
      const circumference = 2 * Math.PI * 16; // r=16 → ~100.5
      openJobModal(`
        <div class="jqm-accept">
          <div class="jqm-accept-head">
            <div class="jqm-countdown-wrap">
              <svg class="jqm-countdown-svg" viewBox="0 0 40 40" width="64" height="64">
                <circle cx="20" cy="20" r="16" fill="none" stroke="var(--dash-card-border)" stroke-width="3"/>
                <circle cx="20" cy="20" r="16" fill="none" stroke="var(--color-accent)" stroke-width="3"
                  stroke-dasharray="${circumference.toFixed(2)}"
                  stroke-dashoffset="0" stroke-linecap="round"
                  transform="rotate(-90 20 20)" id="accept-ring"/>
              </svg>
              <span class="jqm-countdown-num" id="accept-secs">30</span>
            </div>
            <div class="jqm-accept-title">
              <h2>New Job Request</h2>
              <p>Review details before accepting</p>
            </div>
            <button class="jqm-close-btn" data-modal-close aria-label="Close">
              <svg viewBox="0 0 20 20" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="5" x2="15" y2="15"/><line x1="15" y1="5" x2="5" y2="15"/></svg>
            </button>
          </div>
          <div class="jqm-detail-list">
            <div class="jqm-row"><span>Service</span><strong>${service || '—'}</strong></div>
            <div class="jqm-row"><span>Customer</span><strong>${customer || '—'}</strong></div>
            <div class="jqm-row"><span>Address</span><strong>${address || '—'}</strong></div>
            <div class="jqm-row"><span>Date</span><strong>${date || '—'}${time ? ' · ' + time : ''}</strong></div>
            <div class="jqm-row jqm-row--payout"><span>Payout</span><strong>${price || '—'}</strong></div>
            <div class="jqm-row"><span>Payment</span><strong>${payment || '—'}</strong></div>
          </div>
          ${notesHtml}
          <div class="jqm-actions">
            <button class="jqm-btn-pass" id="modal-pass-btn">Pass on this job</button>
            <button class="jqm-btn-confirm-accept" id="modal-accept-btn">
              <svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="4,10 8,14 16,6"/></svg>
              Accept Job
            </button>
          </div>
        </div>`);

      /* countdown ring */
      let secs = 30;
      const ring = document.getElementById('accept-ring');
      const secsEl = document.getElementById('accept-secs');
      const cdInterval = setInterval(() => {
        secs--;
        if (secsEl) secsEl.textContent = secs;
        if (ring) ring.style.strokeDashoffset = String((circumference * (1 - secs / 30)).toFixed(2));
        if (secs <= 0) { clearInterval(cdInterval); closeJobModal(); }
      }, 1000);

      document.getElementById('modal-accept-btn')?.addEventListener('click', () => {
        clearInterval(cdInterval);
        closeJobModal();
        openAcceptModal({
          defaultDurationMin: 60,
          jobContext: {
            service: flow.dataset.service || '',
            notes: flow.dataset.notes || '',
          },
          onConfirm: async (durationMin) => {
            try {
              await updateBookingStatus(bookingId, 'accepted', { estimatedDurationMin: durationMin });
              const card = flow.closest('.jq-premium-card');
              if (card) {
                card.classList.add('jq-premium-card--accepted');
                const statusEl = card.querySelector('.jq-premium-status');
                if (statusEl) {
                  statusEl.innerHTML = `<span class="status-dot"></span><span>Accepted</span>`;
                  statusEl.className = 'jq-premium-status jq-status--blue';
                }
                if (!document.getElementById(`stepper-${bookingId}`)) {
                  const sw = document.createElement('div');
                  sw.className = 'jq-premium-stepper-wrap';
                  sw.id = `stepper-${bookingId}`;
                  sw.innerHTML = buildStepperHtml('accepted');
                  card.querySelector('.jq-premium-card__body')?.before(sw);
                }
                const cardBody = card.querySelector('.jq-premium-card__body');
                if (cardBody && !cardBody.classList.contains('jq-premium-card__body--hidden')) {
                  cardBody.classList.add('jq-premium-card__body--hidden');
                }
                if (card && !card.querySelector('.jq-identity-bar')) {
                  const iBar = document.createElement('div');
                  iBar.className = 'jq-identity-bar';
                  iBar.innerHTML = `
                  <div class="jq-identity-bar__info">
                    <div class="jq-identity-bar__name">${flow.dataset.customer || '—'}</div>
                    <div class="jq-identity-bar__sub">${flow.dataset.service || ''} · ${flow.dataset.address || ''}</div>
                  </div>
                  <div class="jq-identity-bar__payout">
                    <div class="jq-identity-bar__amount">${flow.dataset.price || '—'}</div>
                    <div class="jq-identity-bar__label">PAYOUT</div>
                  </div>`;
                  const sw = card.querySelector('.jq-premium-stepper-wrap');
                  if (sw) sw.before(iBar);
                  else cardBody.before(iBar);
                }
              }
              showSection('accepted');
              showToast('Job accepted! Head to the customer location.', 'success');
            } catch (err) {
              showToast(err?.message || 'Failed to accept job.', 'error');
            }
          },
        });
      });

      document.getElementById('modal-pass-btn')?.addEventListener('click', () => {
        clearInterval(cdInterval);
        closeJobModal();
        showDeclineModal();
      });

      document.querySelector('#jq-modal [data-modal-close]')?.addEventListener('click', () => {
        clearInterval(cdInterval);
        closeJobModal();
      });
    }

    /* ── Decline modal ── */
    function showDeclineModal() {
      openJobModal(`
        <div class="jqm-decline">
          <div class="jqm-decline-icon">
            <svg viewBox="0 0 48 48" width="52" height="52" fill="none" stroke="#EF4444" stroke-width="2"><circle cx="24" cy="24" r="20"/><line x1="15" y1="15" x2="33" y2="33"/><line x1="33" y1="15" x2="15" y2="33"/></svg>
          </div>
          <h2>Decline This Job?</h2>
          <p>Select a reason — this helps improve job matching for you.</p>
          <select class="jqm-reason-select" id="decline-reason">
            <option value="">Select a reason…</option>
            <option value="busy">I'm busy at this time</option>
            <option value="too_far">Location is too far</option>
            <option value="outside_skills">Outside my skill set</option>
            <option value="emergency">Personal emergency</option>
            <option value="other">Other</option>
          </select>
          <div class="jqm-actions">
            <button class="jqm-btn-keep" id="decline-cancel-btn">Keep Job</button>
            <button class="jqm-btn-confirm-decline" id="decline-confirm-btn" disabled>Decline Job</button>
          </div>
        </div>`);

      document.getElementById('decline-reason')?.addEventListener('change', e => {
        const b = document.getElementById('decline-confirm-btn');
        if (b) b.disabled = !e.target.value;
      });

      document.getElementById('decline-cancel-btn')?.addEventListener('click', closeJobModal);

      document.getElementById('decline-confirm-btn')?.addEventListener('click', async () => {
        const btn = document.getElementById('decline-confirm-btn');
        if (btn) { btn.disabled = true; btn.textContent = 'Declining…'; }
        try {
          await updateBookingStatus(bookingId, 'rejected');
          closeJobModal();
          const card = flow.closest('.jq-premium-card');
          if (card) {
            card.style.transition = 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
            card.style.opacity = '0';
            card.style.transform = 'scale(0.95) translateY(10px)';
            setTimeout(() => card.remove(), 420);
          }
          localStorage.removeItem(storeKey);
          showToast('Job declined.', 'info');
        } catch (err) {
          closeJobModal();
          showToast(err?.message || 'Failed to decline.', 'error');
        }
      });
    }

    /* ── Main click handler ── */
    flow.addEventListener('click', async e => {
      const btn = e.target.closest('[data-flow-action]');
      if (!btn) return;
      const action = btn.dataset.flowAction;

      if (action === 'accept') { showAcceptModal(); return; }

      if (action === 'decline') { showDeclineModal(); return; }

      if (action === 'on-my-way') {
        btn.disabled = true;
        try {
          await updateBookingStatus(bookingId, 'en_route');
        } catch (err) {
          btn.disabled = false;
          showToast(err?.message || 'Failed to update status.', 'error');
          return;
        }
        showSection('en-route');
        showToast('Customer notified — you\'re on your way!', 'info');
        return;
      }

      if (action === 'arrived') {
        btn.disabled = true;
        try {
          await updateBookingStatus(bookingId, 'arrived');
        } catch (err) {
          btn.disabled = false;
          showToast(err?.message || 'Failed to update arrival.', 'error');
          return;
        }
        showSection('arrived');
        setTimeout(() => flow.querySelector('.jq-pin-box')?.focus(), 80);
        showToast('Ask the customer for their 4-digit PIN.', 'info');
        return;
      }

      if (action === 'customer-no-show') {
        const note = window.prompt('Describe what happened (min 5 chars):', '');
        if (!note || note.trim().length < 5) {
          showToast('Please describe what happened (5+ chars).', 'error');
          return;
        }
        if (!window.confirm('Mark customer as no-show? You will receive a partial fee; the customer is refunded the remainder.')) return;
        btn.disabled = true;
        try {
          const { markCustomerNoShow } = await import('../api/bookings.js');
          const res = await markCustomerNoShow(bookingId, { note: note.trim(), evidence: [] });
          const r = res?.data || res;
          showToast(`Marked no-show. Fee: ${r?.workerCompensation || 0} EGP.`, 'success');
          setTimeout(() => window.location.reload(), 800);
        } catch (err) {
          btn.disabled = false;
          showToast(err?.message || 'Failed to mark no-show.', 'error');
        }
        return;
      }

      if (action === 'start-job') {
        const boxes = [...flow.querySelectorAll('.jq-pin-box')];
        const entered = boxes.map(b => b.value).join('');
        const errEl = flow.querySelector('.jq-pin-error');
        if (correctPin && entered !== correctPin) {
          const pg = flow.querySelector('[data-pin-group]');
          if (pg) { pg.classList.remove('jq-pin--shake'); void pg.offsetWidth; pg.classList.add('jq-pin--shake'); }
          if (errEl) errEl.hidden = false;
          boxes.forEach(b => { b.value = ''; b.classList.remove('is-filled'); });
          boxes[0]?.focus();
          return;
        }
        if (errEl) errEl.hidden = true;
        btn.disabled = true; btn.textContent = 'Starting…';
        try {
          await updateBookingStatus(bookingId, 'in_progress');
          const card = flow.closest('.jq-premium-card');
          if (card) {
            card.classList.add('jq-premium-card--in-progress');
            const statusEl = card.querySelector('.jq-premium-status');
            if (statusEl) {
              statusEl.innerHTML = `<span class="status-dot"></span><span>In Progress</span>`;
              statusEl.className = 'jq-premium-status jq-status--purple';
            }
          }
          showSection('in-progress');
          startTimer();
          showToast('Job started! Timer is running.', 'success');
        } catch (err) {
          btn.disabled = false; btn.textContent = 'Verify & Start Job';
          showToast(err?.message || 'Failed to start job.', 'error');
        }
        return;
      }

      if (action === 'update-estimate') {
        const currentMin = Number(flow.dataset.estimatedDurationMin) || 60;
        openUpdateEstimateModal({
          currentMin,
          onConfirm: async (newMin) => {
            try {
              await updateBookingStatus(bookingId, 'in_progress', { estimatedDurationMin: newMin });
              flow.dataset.estimatedDurationMin = String(newMin);
              const h = Math.floor(newMin / 60);
              const m = newMin % 60;
              const label = h > 0 ? (m > 0 ? `${h}h ${m}m` : `${h}h`) : `${m}m`;
              showToast(`Estimate updated to ${label}`, 'success');
            } catch (err) {
              showToast(err?.message || 'Failed to update estimate.', 'error');
            }
          },
        });
        return;
      }

      if (action === 'complete') {
        showSection('complete-confirm');
        return;
      }

      if (action === 'back-to-inprogress') {
        showSection('in-progress');
        startTimer();
        return;
      }

      if (action === 'submit-complete') {
        // Payments overhaul — open outcome modal (paid / refused / could-not-complete)
        // instead of the legacy single-photo + notes flow.
        btn.disabled = true;
        const prevLabel = btn.textContent;
        btn.textContent = 'Opening…';
        try {
          await openCompletionOutcomeModal({
            bookingId,
            onSubmit: async (payload) => {
              await submitCompletionOutcome(bookingId, payload);
              clearInterval(timerInterval);
              localStorage.removeItem(storeKey);
              localStorage.removeItem(timerKey);
              await initJobQueue('waiting');
            },
          });
        } finally {
          btn.disabled = false;
          btn.textContent = prevLabel;
        }
        return;
      }
    });
  });
}

// ── Populate overview incoming requests ──────────────────────────────────────
function populateOverviewIncoming(pendingBookings) {
  const container = document.getElementById('overview-incoming-list');
  if (!container) return;
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  const preview = pendingBookings.slice(0, 3);
  if (preview.length === 0) {
    const _raw = typeof window.t === 'function' ? window.t('tech_no_pending_requests') : null;
    const noReqMsg = (_raw && _raw !== 'tech_no_pending_requests') ? _raw : 'No pending requests right now.';
    container.innerHTML = `<p style="color:var(--color-text-muted);font-size:0.85rem;padding:12px 0;">${noReqMsg}</p>`;
    return;
  }

  container.innerHTML = preview.map(b => {
    const service = b.service?.title || b.service?.category || 'Service';
    const customer = b.user?.name || '—';
    const address = b.address || '—';
    const price = b.totalPrice != null ? `~EGP ${Number(b.totalPrice).toLocaleString('en-US')}` : '—';
    return `
      <div class="job-card-v2">
        <div class="job-card-v2__icon">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="#9A8C73" stroke-width="2" aria-hidden="true"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
        </div>
        <div class="job-card-v2__body">
          <h4 class="job-card-v2__title">${service}</h4>
          <p class="job-card-v2__meta">
            <span>${customer}</span><span class="job-card-v2__sep">·</span>
            <span>${address}</span><span class="job-card-v2__sep">·</span>
            <span class="job-card-v2__price">${price}</span>
          </p>
        </div>
        <span class="badge badge--pending">${_t('status_new') || 'New'}</span>
      </div>`;
  }).join('');
}

// ── Populate overview upcoming schedule ──────────────────────────────────────
function populateOverviewSchedule(bookings) {
  const container = document.getElementById('overview-schedule-list');
  if (!container) return;
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  const now = new Date();
  const upcoming = bookings
    .filter(b => {
      const d = new Date(b.scheduledDate);
      return d >= now && ['pending', 'accepted', 'en_route', 'arrived', 'in_progress'].includes(b.status);
    })
    .sort((a, b) => new Date(a.scheduledDate) - new Date(b.scheduledDate))
    .slice(0, 4);

  if (upcoming.length === 0) {
    container.innerHTML = `<p style="color:var(--color-text-muted);font-size:0.85rem;padding:12px 0;">${_t('tech_no_upcoming') || 'No upcoming jobs scheduled.'}</p>`;
    return;
  }

  const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  container.innerHTML = upcoming.map(b => {
    const d = new Date(b.scheduledDate);
    const day = String(d.getDate()).padStart(2, '0');
    const month = MONTHS[d.getMonth()];
    const service = b.service?.title || b.service?.category || 'Service';
    const time = b.scheduledTime || '—';
    const loc = b.address ? b.address.split(',')[0] : '—';
    return `
      <div class="dash-schedule-item">
        <div class="dash-schedule-date">
          <span class="dash-schedule-day">${day}</span>
          <span class="dash-schedule-month">${month}</span>
        </div>
        <div class="dash-schedule-content">
          <h4 class="dash-schedule-title">${service}</h4>
          <p class="dash-schedule-info">
            <span class="dash-schedule-time">${time}</span>
            <span class="dash-schedule-sep">·</span>
            <span class="dash-schedule-loc">${loc}</span>
          </p>
        </div>
      </div>`;
  }).join('');
}

// ── Atelier sparkline: 7-day earnings trend ──────────────────────────────────
function renderEarningsSparkline(series = []) {
  const area = document.getElementById('sparkArea');
  const line = document.getElementById('sparkLine');
  if (!area || !line) return;

  const buckets = Array.isArray(series) && series.length
    ? series.slice(0, 7).map(v => Number(v) || 0)
    : new Array(7).fill(0);

  const max = Math.max(...buckets, 1);
  const W = 120, H = 28, pad = 2;
  const step = (W - pad * 2) / Math.max(1, buckets.length - 1);
  const points = buckets.map((v, i) => {
    const x = pad + i * step;
    const y = H - pad - (v / max) * (H - pad * 2 - 2);
    return [x, y];
  });

  const linePath = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const areaPath = `${linePath} L${points[points.length - 1][0].toFixed(1)} ${H} L${points[0][0].toFixed(1)} ${H} Z`;

  line.setAttribute('d', linePath);
  area.setAttribute('d', areaPath);
}

// Canonical money formatter — single source of truth for currency display
// across the dashboard. Use:
//   - moneyFmt.card(x)    → "1,234.56"           (plain 2-decimal numeric)
//   - moneyFmt.compact(x) → "1,234.5" / "1,234"  (0..2 fraction digits, stat strip)
//   - moneyFmt.html(x)    → "1,234.56 <span class=\"money-card__ccy-inline\">EGP</span>"
//   - moneyFmt.text(x)    → "1,234.56 EGP"
const moneyFmt = {
  card:    v => (Number(v) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
  compact: v => (Number(v) || 0).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 }),
  html:    v => `${moneyFmt.card(v)} <span class="money-card__ccy-inline">EGP</span>`,
  text:    v => `${moneyFmt.card(v)} EGP`,
};

function buildFallbackSparklineSeries(completed = []) {
  const days = 7;
  const now = new Date();
  const buckets = new Array(days).fill(0);
  completed.forEach(b => {
    const d = new Date(b.scheduledDate || b.updatedAt);
    if (Number.isNaN(d.getTime())) return;
    const diff = Math.floor((now - d) / 86400000);
    if (diff >= 0 && diff < days) {
      buckets[days - 1 - diff] += bookingFeeSnapshot(b).net;
    }
  });
  return buckets;
}

function renderCanonicalEarningsPanel({
  bookings = [],
  completed = [],
  monthEarnings = 0,
  lastMonthEarnings = 0,
  cashCompleted = [],
  outstandingAmount = 0,
  earnings = null,
} = {}) {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const breakdown = earnings?.breakdown || null;
  const numberOr = (value, fallback = 0) => {
    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : fallback;
  };
  const formatDeltaHtml = (current, previous) => {
    const delta = numberOr(current) - numberOr(previous);
    if (!previous && !current) return 'No take-home yet this month';
    if (!previous) return `Started this month with ${moneyFmt.text(current)}`;
    const isUp = delta >= 0;
    const arrow = isUp ? '+' : '-';
    const sign = isUp ? '+' : '-';
    return `
      <span class="${isUp ? 'jq-earn-trend-up' : 'jq-earn-trend-down'}">
        ${arrow} ${sign}${moneyFmt.text(Math.abs(delta))}
      </span> vs last month`;
  };
  const fallbackRecentItems = completed
    .slice()
    .sort((a, b) => new Date(b.scheduledDate || b.updatedAt) - new Date(a.scheduledDate || a.updatedAt))
    .slice(0, 10)
    .map((booking) => {
      const snapshot = bookingFeeSnapshot(booking);
      const isCash = String(booking.paymentMethod || '').toLowerCase() === 'cash';
      return {
        bookingId: booking._id,
        shortBookingId: String(booking._id || '').slice(-6).toUpperCase(),
        paymentMethod: booking.paymentMethod || (isCash ? 'cash' : 'online'),
        customerName: booking.user?.name || '',
        serviceName: booking.service?.title || booking.service?.category || booking.serviceName || 'Service',
        gross: snapshot.gross,
        fee: snapshot.fee,
        displayAmount: snapshot.net,
        walletCreditAmount: isCash ? 0 : snapshot.net,
        cashCollectedAmount: isCash ? snapshot.net : 0,
        settlementType: isCash ? 'cash_collected' : 'released_to_wallet',
        occurredAt: booking.scheduledDate || booking.updatedAt,
      };
    });

  const availableToWithdraw = numberOr(breakdown?.availableToWithdraw, earnings?.wallet?.balance);
  _availableBalanceCache = { value: Number(availableToWithdraw) || 0, ts: Date.now() };
  const pendingRelease = numberOr(breakdown?.pendingRelease, earnings?.wallet?.pendingBalance);
  const pendingJobsCount = Math.max(0, Math.round(numberOr(
    breakdown?.pendingJobsCount,
    earnings?.wallet?.pendingJobs ?? earnings?.pendingJobsCount
  )));
  const walletReleasedNet = numberOr(breakdown?.walletReleasedNet, earnings?.wallet?.totalEarned);
  const collectedCashNet = numberOr(
    breakdown?.collectedCashNet,
    cashCompleted.reduce((sum, booking) => sum + bookingFeeSnapshot(booking).net, 0)
  );
  const cashCompletedJobsCount = Math.max(0, Math.round(numberOr(breakdown?.cashCompletedJobsCount, cashCompleted.length)));
  const lifetimeTakeHome = numberOr(breakdown?.lifetimeTakeHome, walletReleasedNet + collectedCashNet);
  const completedJobsCount = Math.max(0, Math.round(numberOr(breakdown?.completedJobs, completed.length)));
  const cashFeesLifetime = numberOr(
    breakdown?.cashFeesLifetime,
    cashCompleted.reduce((sum, booking) => sum + bookingFeeSnapshot(booking).fee, 0)
  );
  const averageCashFee = numberOr(
    breakdown?.averageCashFee,
    cashCompleted.length ? cashFeesLifetime / cashCompleted.length : 0
  );
  const monthTakeHome = numberOr(breakdown?.thisMonthTakeHome, monthEarnings);
  const previousMonthTakeHome = numberOr(breakdown?.lastMonthTakeHome, lastMonthEarnings);
  const outstandingCashFees = numberOr(breakdown?.outstandingCashFees, outstandingAmount);
  const outstandingCashFeeItems = Array.isArray(breakdown?.outstandingCashFeeItems)
    ? breakdown.outstandingCashFeeItems
    : cashCompleted.slice(0, 5).map((booking) => {
      const snapshot = bookingFeeSnapshot(booking);
      return {
        bookingId: booking._id,
        shortBookingId: String(booking._id || '').slice(-6).toUpperCase(),
        gross: snapshot.gross,
        fee: snapshot.fee,
        remaining: snapshot.fee,
        status: 'outstanding',
      };
    });
  const recentEarnings = Array.isArray(breakdown?.recentEarnings) && breakdown.recentEarnings.length
    ? breakdown.recentEarnings
    : fallbackRecentItems;
  const sparkSeries = Array.isArray(breakdown?.sevenDayTrend) && breakdown.sevenDayTrend.length
    ? breakdown.sevenDayTrend
    : buildFallbackSparklineSeries(completed);

  const periodEl = document.getElementById('ledgerPeriod');
  if (periodEl) {
    const now = new Date();
    const month = now.toLocaleString('en-US', { month: 'short' }).toUpperCase();
    periodEl.textContent = `${month} \u00B7 ${now.getFullYear()}`;
  }

  const earnTotalEl = document.getElementById('earn-total');
  if (earnTotalEl) earnTotalEl.textContent = moneyFmt.compact(lifetimeTakeHome);

  const earnMonthEl = document.getElementById('earn-month');
  if (earnMonthEl) earnMonthEl.textContent = moneyFmt.compact(monthTakeHome);

  const deltaEl = document.getElementById('earn-month-delta');
  if (deltaEl) {
    const last = Number(previousMonthTakeHome) || 0;
    const cur  = Number(monthTakeHome) || 0;
    const valueEl = deltaEl.querySelector('[data-delta-value]');
    const iconEl  = deltaEl.querySelector('[data-delta-icon]');

    let direction = 'flat';
    let label = '—';

    if (last > 0) {
      const pct = ((cur - last) / last) * 100;
      if (pct > 0.5)  direction = 'up';
      else if (pct < -0.5) direction = 'down';
      const arrow = pct > 0 ? '+' : '';
      label = `${arrow}${pct.toFixed(0)}%`;
    } else if (cur > 0) {
      direction = 'up';
      label = 'New';
    }

    deltaEl.dataset.direction = direction;
    if (valueEl) valueEl.textContent = label;
    if (iconEl) {
      const paths = {
        up:   'M12 19V5M5 12l7-7 7 7',
        down: 'M12 5v14M5 12l7 7 7-7',
        flat: 'M5 12h14',
      };
      const pathEl = iconEl.querySelector('path');
      if (pathEl) pathEl.setAttribute('d', paths[direction]);
    }
  }

  const earnCashEl = document.getElementById('earn-cash');
  if (earnCashEl) earnCashEl.textContent = moneyFmt.compact(collectedCashNet);

  const earnCashSubEl = document.getElementById('earn-cash-sub');
  if (earnCashSubEl) {
    earnCashSubEl.textContent = cashCompletedJobsCount > 0
      ? `${cashCompletedJobsCount} completed cash ${cashCompletedJobsCount === 1 ? 'job' : 'jobs'}`
      : 'No completed cash jobs yet';
  }

  const earnCompletedEl = document.getElementById('earn-completed-count');
  if (earnCompletedEl) earnCompletedEl.textContent = completedJobsCount;

  const debtLifetimeEl = document.getElementById('debtLifetimeFees');
  if (debtLifetimeEl) debtLifetimeEl.textContent = moneyFmt.card(cashFeesLifetime);
  const debtAvgEl = document.getElementById('debtAvgFee');
  if (debtAvgEl) debtAvgEl.textContent = moneyFmt.card(averageCashFee);

  renderEarningsSparkline(sparkSeries);

  const bridgeWalletEl = document.getElementById('bridgeWalletNum');
  const bridgeCashEl   = document.getElementById('bridgeCashNum');
  const fmtChip = v => Math.round(Number(v) || 0).toLocaleString('en-US');
  if (bridgeWalletEl) bridgeWalletEl.textContent = fmtChip(walletReleasedNet);
  if (bridgeCashEl)   bridgeCashEl.textContent   = fmtChip(collectedCashNet);

  const availableEl = document.getElementById('walletAvailable');
  if (availableEl) availableEl.innerHTML = moneyFmt.html(availableToWithdraw);

  const availableTagEl = document.getElementById('availableWithdrawTag');
  if (availableTagEl) {
    availableTagEl.innerHTML = availableToWithdraw > 0
      ? '<span class="money-card__dot" aria-hidden="true"></span>Ready now'
      : '<span class="money-card__dot" aria-hidden="true"></span>No funds yet';
  }

  const availableNoteEl = document.getElementById('availableWithdrawNote');
  if (availableNoteEl) {
    availableNoteEl.textContent = availableToWithdraw > 0
      ? 'Money already released into your Servio wallet.'
      : 'No released money is available in your Servio wallet yet.';
  }

  const pendingEl = document.getElementById('walletPending');
  if (pendingEl) pendingEl.innerHTML = moneyFmt.html(pendingRelease);

  const pendingTagEl = document.getElementById('pendingReleaseTag');
  if (pendingTagEl) pendingTagEl.textContent = pendingRelease > 0 ? 'In review' : 'No holds';

  const pendingJobsEl = document.getElementById('pendingJobsCount');
  if (pendingJobsEl) pendingJobsEl.textContent = pendingJobsCount === 1 ? '1 job' : `${pendingJobsCount} jobs`;

  const pendingNoteEl = document.getElementById('pendingReleaseNote');
  if (pendingNoteEl) {
    if (pendingJobsCount > 0) {
      pendingNoteEl.textContent = pendingJobsCount === 1
        ? 'One online job is still waiting for release approval.'
        : `${pendingJobsCount} online jobs are still waiting for release approval.`;
    } else {
      pendingNoteEl.textContent = 'No online jobs are waiting for release right now.';
    }
  }

  const pendingBusyEl = document.querySelector('[data-pending-busy]');
  const pendingEmptyEl = document.querySelector('[data-pending-empty]');
  const pendingCard = document.getElementById('pendingCard');
  
  const hasPending = Number(pendingRelease) > 0 || Number(pendingJobsCount) > 0;
  
  if (pendingBusyEl) pendingBusyEl.hidden = !hasPending;
  if (pendingEmptyEl) pendingEmptyEl.hidden = hasPending;
  if (pendingCard) pendingCard.dataset.state = hasPending ? 'busy' : 'settled';

  const liabilityAmountEl = document.getElementById('liabilityAmount');
  if (liabilityAmountEl) liabilityAmountEl.innerHTML = moneyFmt.html(outstandingCashFees);
  const liabilityCard = document.getElementById('liabilityCard');
  if (liabilityCard) liabilityCard.dataset.state = outstandingCashFees > 0 ? 'owing' : 'settled';
  const payLiabBtn = document.getElementById('payLiabilityBtn');
  if (payLiabBtn) payLiabBtn.hidden = outstandingCashFees <= 0;

  const debtDueTag = document.getElementById('debtDueTag');
  if (debtDueTag) debtDueTag.textContent = outstandingCashFees > 0 ? 'Outstanding' : 'All settled';

  const wBtn = document.getElementById('btnRequestPayout');
  if (wBtn) {
    const tooLow = availableToWithdraw < 50;
    wBtn.disabled = tooLow;
    wBtn.title = tooLow ? `Minimum 50 EGP needed (${moneyFmt.card(availableToWithdraw)} available)` : '';
  }

  const bankLabel = document.getElementById('withdrawBankLabel');
  const bankEdit = document.getElementById('withdrawBankEdit');
  if (bankLabel) {
    const method = String(earnings?.payoutMethod || earnings?.wallet?.payoutMethod || '').toLowerCase();
    const map = { bank: 'Bank transfer', instapay: 'InstaPay', vodafone: 'Vodafone Cash', wallet: 'E-wallet' };
    if (map[method]) {
      bankLabel.innerHTML = `Paying to <strong>${map[method]}</strong>`;
      if (bankEdit) bankEdit.textContent = 'Change';
    } else {
      bankLabel.textContent = 'No payout method set yet';
      if (bankEdit) bankEdit.textContent = 'Add now';
    }
  }

  const liabilityList = document.getElementById('liability-items-list');
  if (liabilityList) {
    if (!outstandingCashFeeItems.length || outstandingCashFees <= 0) {
      liabilityList.innerHTML = `
        <div class="liability-empty">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M20 6 9 17l-5-5"/></svg>
          <span>${_t('tech_no_outstanding') || 'All settled - no outstanding cash balance.'}</span>
        </div>`;
    } else {
      liabilityList.innerHTML = outstandingCashFeeItems.slice(0, 5).map(item => {
        const feeStr = moneyFmt.text(item.remaining);
        const breakdownText = item.gross > 0
          ? `${moneyFmt.text(item.gross)} gross - fee ${moneyFmt.text(item.fee)}`
          : `Fee ${moneyFmt.text(item.fee)}`;
        return `
          <div class="jq-premium-liability-row">
            <div class="jq-premium-liability-info">
              <span class="jq-premium-liability-id">#${item.shortBookingId}</span>
              <span class="jq-premium-liability-tag">${_t('tech_commission') || 'Commission'}</span>
              <span class="jq-premium-liability-breakdown">${breakdownText}</span>
            </div>
            <span class="jq-premium-liability-val">${feeStr}</span>
          </div>`;
      }).join('');
    }
  }

  const liabilityWarning = document.getElementById('liabilityWarning');
  if (liabilityWarning) liabilityWarning.hidden = outstandingCashFees < 2000;

  const recentList = document.getElementById('earnings-recent-list');
  if (recentList) {
    if (!recentEarnings.length) {
      recentList.innerHTML = `
        <div class="recent-jobs__empty">
          <strong>No jobs yet.</strong>
          <span>Once you complete a job, it'll appear here with its settlement type.</span>
        </div>`;
    } else {
      recentList.innerHTML = recentEarnings.slice(0, 3).map(item => {
        const service = item.serviceName || 'Service';
        const dateSource = item.occurredAt || item.scheduledDate;
        const dateStr = dateSource
          ? new Date(dateSource).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })
          : '-';
        const customer = item.customerName || 'Not listed';
        let badgeCls = 'jq-earn-row-tag--wallet';
        let badgeLbl = 'WALLET';
        let amountValue = numberOr(item.walletCreditAmount, item.displayAmount);
        let amountPrefix = '+';
        let amountClass = '';

        if (item.settlementType === 'cash_collected') {
          badgeCls = 'jq-earn-row-tag--cash';
          badgeLbl = 'CASH';
          amountValue = numberOr(item.cashCollectedAmount, item.displayAmount);
        } else if (item.settlementType === 'released_after_offset') {
          badgeCls = 'jq-earn-row-tag--wallet';
          badgeLbl = 'WALLET';
          amountValue = numberOr(item.walletCreditAmount, item.displayAmount);
        } else if (item.settlementType === 'released_to_wallet') {
          badgeCls = 'jq-earn-row-tag--wallet';
          badgeLbl = 'WALLET';
          amountValue = numberOr(item.walletCreditAmount, item.displayAmount);
        } else if (item.settlementType === 'pending_release') {
          badgeCls = 'jq-earn-row-tag--pending';
          badgeLbl = 'PENDING';
          amountValue = numberOr(item.displayAmount, item.gross);
          amountPrefix = '';
          amountClass = ' jq-earn-row-amount__net--pending';
        }

        const amountStr = `${amountPrefix}${moneyFmt.text(amountValue)}`;
        const feeStr = moneyFmt.text(item.fee);
        return `
          <div class="jq-premium-earn-row" data-reveal>
            <div class="jq-earn-row-left">
              <div class="jq-earn-row-icon">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
              </div>
              <div class="jq-earn-row-info">
                <div class="jq-earn-row-title">
                  <h4>${escapeHtml(service)}</h4>
                  <span class="jq-earn-row-date">${escapeHtml(dateStr)}</span>
                </div>
                <div class="jq-earn-row-customer">
                  <span class="jq-earn-row-customer__label">Customer</span>
                  <span class="jq-earn-row-customer__name">${escapeHtml(customer)}</span>
                </div>
              </div>
            </div>
            <div class="jq-earn-row-amount">
              <span class="jq-earn-row-amount__net${amountClass}">${amountStr}</span>
              <span class="jq-earn-row-tag ${badgeCls}">${badgeLbl}</span>
              <span class="jq-earn-row-fee"><span>Fee</span><strong>${feeStr}</strong></span>
            </div>
          </div>`;
      }).join('');
    }
  }

  renderEarningsOverviewExtras({ monthTakeHome, completed });
}

// ── Earnings goals + linked accounts (real data) ──────────────────────────────
const EARNINGS_GOALS_KEY = 'servio_earnings_goals_v1';
function getEarningsGoals() {
  try {
    const stored = JSON.parse(localStorage.getItem(EARNINGS_GOALS_KEY) || 'null');
    if (stored && Number.isFinite(stored.monthly) && Number.isFinite(stored.daily)) return stored;
  } catch {}
  return { monthly: 5000, daily: 250 };
}
function setEarningsGoals(goals) {
  try { localStorage.setItem(EARNINGS_GOALS_KEY, JSON.stringify(goals)); } catch {}
}

function computeTodayTakeHome(completed) {
  if (!Array.isArray(completed)) return 0;
  const now = new Date();
  const y = now.getFullYear(), m = now.getMonth(), d = now.getDate();
  return completed.reduce((sum, b) => {
    const when = new Date(b.scheduledDate || b.updatedAt || 0);
    if (when.getFullYear() === y && when.getMonth() === m && when.getDate() === d) {
      const snap = bookingFeeSnapshot(b);
      return sum + (Number(snap.net) || 0);
    }
    return sum;
  }, 0);
}

function maskAccountNumber(raw) {
  const digits = String(raw || '').replace(/\D/g, '');
  if (!digits) return '';
  if (digits.length <= 4) return `•••• ${digits}`;
  return `•••• ${digits.slice(-4)}`;
}

function renderLinkedAccountsTile(account) {
  const list = document.querySelector('.eog-tile--accounts .eog-accounts__list');
  if (!list) return;
  const acc = account || {};
  const method = String(acc.payoutMethod || '').toLowerCase();
  const bankSet    = !!(acc.bankName || acc.accountHolder || acc.accountNumber);
  const walletSet  = !!acc.walletNumber;

  const bankIcon = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 21h18M5 21V10M19 21V10M3 10h18L12 3 3 10z"/></svg>`;
  const cardIcon = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M2 10h20"/></svg>`;
  const editIcon = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 20h4l11-11-4-4L4 16v4z"/></svg>`;
  const escape = (s) => String(s || '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));

  const items = [];

  if (bankSet) {
    const title = method !== 'wallet' ? 'Default payout · Bank' : 'Linked Bank';
    const sub = [escape(acc.bankName), maskAccountNumber(acc.accountNumber)].filter(Boolean).join(' · ');
    items.push(`
      <li class="eog-accounts__item${method !== 'wallet' ? ' eog-accounts__item--active' : ''}">
        <span class="eog-accounts__icon" aria-hidden="true">${bankIcon}</span>
        <div class="eog-accounts__body">
          <strong>${title}</strong>
          <span>${sub || 'Bank transfer'}</span>
        </div>
        <a class="eog-accounts__edit" href="#" data-jump-payout-settings aria-label="Edit bank">${editIcon}</a>
      </li>`);
  }
  if (walletSet) {
    const title = method === 'wallet' ? 'Default payout · Wallet' : 'Mobile Wallet';
    items.push(`
      <li class="eog-accounts__item${method === 'wallet' ? ' eog-accounts__item--active' : ''}">
        <span class="eog-accounts__icon" aria-hidden="true">${cardIcon}</span>
        <div class="eog-accounts__body">
          <strong>${title}</strong>
          <span>${maskAccountNumber(acc.walletNumber)}</span>
        </div>
        <a class="eog-accounts__edit" href="#" data-jump-payout-settings aria-label="Edit wallet">${editIcon}</a>
      </li>`);
  }
  if (!items.length) {
    items.push(`
      <li class="eog-accounts__item eog-accounts__item--empty">
        <span class="eog-accounts__icon" aria-hidden="true">${bankIcon}</span>
        <div class="eog-accounts__body">
          <strong>No payout method yet</strong>
          <span>Add a bank or wallet to receive earnings</span>
        </div>
        <a class="eog-accounts__edit" href="#" data-jump-payout-settings aria-label="Add payout method">${editIcon}</a>
      </li>`);
  } else if (items.length === 1) {
    const missing = bankSet ? 'wallet' : 'bank';
    const ico = missing === 'bank' ? bankIcon : cardIcon;
    items.push(`
      <li class="eog-accounts__item eog-accounts__item--placeholder">
        <span class="eog-accounts__icon" aria-hidden="true">${ico}</span>
        <div class="eog-accounts__body">
          <strong>Backup method</strong>
          <span>Add a ${missing} for redundancy</span>
        </div>
        <a class="eog-accounts__edit" href="#" data-jump-payout-settings aria-label="Add backup method">${editIcon}</a>
      </li>`);
  }

  list.innerHTML = items.join('');
}

function renderEarningsGoalsTile(monthTakeHome, todayTakeHome) {
  const goals = getEarningsGoals();
  const monthLabel = document.querySelector('.eog-tile--goals .eog-goal:not(.eog-goal--daily) .eog-goal__label');
  const monthBar   = document.getElementById('monthlyGoalBar');
  const monthScale = document.querySelector('.eog-tile--goals .eog-goal:not(.eog-goal--daily) .eog-goal__scale');
  const monthPct   = document.querySelector('.eog-tile--goals .eog-goal:not(.eog-goal--daily) .eog-goal__pct');
  const dailyLabel = document.querySelector('.eog-tile--goals .eog-goal--daily .eog-goal__label');
  const dailyBadge = document.querySelector('.eog-tile--goals .eog-goal--daily .eog-goal__badge');

  const monthValue = Math.max(0, Number(monthTakeHome) || 0);
  const todayValue = Math.max(0, Number(todayTakeHome) || 0);
  const monthlyTarget = Math.max(1, goals.monthly);
  const dailyTarget   = Math.max(1, goals.daily);
  const monthPctNum   = Math.min(100, Math.round((monthValue / monthlyTarget) * 100));
  const dailyPctNum   = Math.min(100, Math.round((todayValue / dailyTarget) * 100));

  if (monthLabel) monthLabel.innerHTML = `Monthly Target: <strong>${moneyFmt.compact(monthlyTarget)} EGP</strong>`;
  if (monthBar)   monthBar.style.width = `${monthPctNum}%`;
  if (monthPct)   monthPct.innerHTML = `${moneyFmt.compact(monthValue)} <em>/ ${moneyFmt.compact(monthlyTarget)} EGP</em>`;
  if (monthScale) monthScale.innerHTML = `<span>0</span><span>${moneyFmt.compact(monthlyTarget/2)}</span><span>${moneyFmt.compact(monthlyTarget)}</span>`;

  if (dailyLabel) dailyLabel.innerHTML = `Daily Goal: <strong>${moneyFmt.compact(dailyTarget)} EGP</strong> · today <strong>${moneyFmt.compact(todayValue)}</strong>`;
  if (dailyBadge) {
    const hit = dailyPctNum >= 100;
    dailyBadge.classList.toggle('eog-goal__badge--hit', hit);
    const checkSvg = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M20 6 9 17l-5-5"/></svg>`;
    const sparkSvg = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M12 2v4M12 18v4M2 12h4M18 12h4M4.9 4.9l2.8 2.8M16.3 16.3l2.8 2.8M4.9 19.1l2.8-2.8M16.3 7.7l2.8-2.8"/></svg>`;
    dailyBadge.innerHTML = `${hit ? checkSvg : sparkSvg}<span>${hit ? 'Daily goal reached — nice work.' : `${dailyPctNum}% toward today's goal · keep going.`}</span>`;
  }
}

function wireAutoWithdrawalToggle(account) {
  const toggle = document.getElementById('autoWithdrawalToggle');
  if (!toggle) return;
  const acc = account || {};
  toggle.checked = !!acc.autoWithdraw;
  if (toggle.dataset.wired === '1') return;
  toggle.dataset.wired = '1';
  toggle.addEventListener('change', () => {
    const current = getAccount() || {};
    current.autoWithdraw = !!toggle.checked;
    try { localStorage.setItem('servio_account', JSON.stringify(current)); } catch {}
  });
}

function renderEarningsOverviewExtras({ monthTakeHome, completed }) {
  const account = getAccount();
  renderLinkedAccountsTile(account);
  wireAutoWithdrawalToggle(account);
  renderEarningsGoalsTile(monthTakeHome, computeTodayTakeHome(completed));
}

// ── Populate earnings panel ───────────────────────────────────────────────────
function populateEarningsLegacy(allBookings, completed, monthEarnings, lastMonthEarnings, cashCompleted, outstandingAmount) {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);

  // Ledger period header (e.g. "MAY · 2026")
  const periodEl = document.getElementById('ledgerPeriod');
  if (periodEl) {
    const now = new Date();
    const month = now.toLocaleString('en-US', { month: 'short' }).toUpperCase();
    periodEl.textContent = `${month} \u00B7 ${now.getFullYear()}`;
  }

  // Summary stats — NET take-home (gross minus platform fee). Gross shown as sub-label.
  const totals = completed.reduce((acc, b) => {
    const snap = bookingFeeSnapshot(b);
    acc.gross += snap.gross;
    acc.net += snap.net;
    acc.fee += snap.fee;
    return acc;
  }, { gross: 0, net: 0, fee: 0 });
  const totalEarned = money(totals.net);

  const earnTotalEl = document.getElementById('earn-total');
  if (earnTotalEl) earnTotalEl.textContent = moneyFmt.compact(totalEarned);

  // Legacy mode lacks the wallet/cash lifetime split exposed by the canonical
  // breakdown — fall back to zeros so the chips render valid digits until the
  // canonical renderer takes over.
  const bridgeWalletElLegacy = document.getElementById('bridgeWalletNum');
  const bridgeCashElLegacy   = document.getElementById('bridgeCashNum');
  if (bridgeWalletElLegacy) bridgeWalletElLegacy.textContent = '0';
  if (bridgeCashElLegacy)   bridgeCashElLegacy.textContent   = '0';

  const earnMonthEl = document.getElementById('earn-month');
  if (earnMonthEl) earnMonthEl.textContent = moneyFmt.compact(monthEarnings);

  const deltaEl = document.getElementById('earn-month-delta');
  if (deltaEl) {
    const last = Number(lastMonthEarnings) || 0;
    const cur  = Number(monthEarnings) || 0;
    const valueEl = deltaEl.querySelector('[data-delta-value]');
    const iconEl  = deltaEl.querySelector('[data-delta-icon]');

    let direction = 'flat';
    let label = '—';

    if (last > 0) {
      const pct = ((cur - last) / last) * 100;
      if (pct > 0.5)  direction = 'up';
      else if (pct < -0.5) direction = 'down';
      const arrow = pct > 0 ? '+' : '';
      label = `${arrow}${pct.toFixed(0)}%`;
    } else if (cur > 0) {
      direction = 'up';
      label = 'New';
    }

    deltaEl.dataset.direction = direction;
    if (valueEl) valueEl.textContent = label;
    if (iconEl) {
      const paths = {
        up:   'M12 19V5M5 12l7-7 7 7',
        down: 'M12 5v14M5 12l7 7 7-7',
        flat: 'M5 12h14',
      };
      const pathEl = iconEl.querySelector('path');
      if (pathEl) pathEl.setAttribute('d', paths[direction]);
    }
  }

  const earnCompletedEl = document.getElementById('earn-completed-count');
  if (earnCompletedEl) earnCompletedEl.textContent = completed.length;

  // Debt card lifetime context — force 2-decimal money format for consistency
  const debtLifetimeEl = document.getElementById('debtLifetimeFees');
  if (debtLifetimeEl) debtLifetimeEl.textContent = moneyFmt.card(totals.fee);
  const debtAvgEl = document.getElementById('debtAvgFee');
  if (debtAvgEl) {
    const avg = completed.length > 0 ? totals.fee / completed.length : 0;
    debtAvgEl.textContent = moneyFmt.card(avg);
  }

  // Sparkline: last 7 days of completed earnings
  renderEarningsSparkline(completed);

  // Outstanding cash balance — 2-decimal format, currency rendered as suffix
  const liabilityAmountEl = document.getElementById('liabilityAmount');
  if (liabilityAmountEl) {
    const amt2 = outstandingAmount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    liabilityAmountEl.innerHTML = `${amt2} <span class="money-card__ccy-inline">EGP</span>`;
  }
  const liabilityCard = document.getElementById('liabilityCard');
  if (liabilityCard) liabilityCard.dataset.state = outstandingAmount > 0 ? 'owing' : 'settled';
  const payLiabBtn = document.getElementById('payLiabilityBtn');
  if (payLiabBtn) payLiabBtn.hidden = outstandingAmount <= 0;

  // Fetch real wallet balance + pending from backend (was: stale "0" placeholder).
  // Also enrich debt banner amount and pending-jobs count line.
  (async () => {
    try {
      const earn = await getWorkerEarnings();
      const bal = Number(earn?.wallet?.balance) || 0;
      const pending = Number(earn?.wallet?.pendingBalance) || 0;
      const pendingJobs = Number(earn?.wallet?.pendingJobs ?? earn?.pendingJobsCount) || 0;
      const fmt = n => n.toLocaleString('en-US', { minimumFractionDigits: bal % 1 === 0 ? 0 : 2, maximumFractionDigits: 2 });
      const wa = document.getElementById('walletAvailable');
      const wp = document.getElementById('walletPending');
      if (wa) wa.innerHTML = fmt(bal) + ' <span class="money-card__ccy-inline">EGP</span>';
      if (wp) wp.textContent = fmt(pending);
      // Net after debt (only when liability > 0)
      const netRow = document.getElementById('walletNetRow');
      const netEl = document.getElementById('walletNet');
      const owed = Number(outstandingAmount) || 0;
      if (netRow && netEl) {
        if (owed > 0) {
          const net = Math.max(0, bal - owed);
          netEl.textContent = net.toLocaleString('en-US', { minimumFractionDigits: net % 1 === 0 ? 0 : 2, maximumFractionDigits: 2 });
          netRow.hidden = false;
        } else {
          netRow.hidden = true;
        }
      }
      const pjc = document.getElementById('pendingJobsCount');
      if (pjc) {
        if (pendingJobs > 0) {
          pjc.hidden = false;
          pjc.textContent = pendingJobs === 1 ? 'from 1 job in hold' : `from ${pendingJobs} jobs in hold`;
        } else {
          pjc.hidden = true;
          pjc.textContent = '';
        }
      }
      // Hide whole "Coming soon" cell when nothing pending
      const pendingCell = document.getElementById('walletPending')?.closest('.money-card__foot-item');
      const pendingDivider = pendingCell?.nextElementSibling;
      if (pendingCell) {
        const empty = pending <= 0;
        pendingCell.hidden = empty;
        if (pendingDivider?.classList.contains('money-card__foot-divider')) pendingDivider.hidden = empty;
      }

      // Withdraw button enable + bank label (moved from renderMyPayoutsV2)
      const wBtn = document.getElementById('btnRequestPayout');
      if (wBtn) {
        const tooLow = bal < 50;
        wBtn.disabled = tooLow;
        wBtn.title = tooLow ? `Minimum 50 EGP needed (${bal.toLocaleString('en-US')} available)` : '';
      }
      const bankLabel = document.getElementById('withdrawBankLabel');
      const bankEdit = document.getElementById('withdrawBankEdit');
      if (bankLabel) {
        const m = (earn?.payoutMethod || earn?.preferredPayoutMethod || '').toLowerCase();
        const map = { bank: 'Bank transfer', instapay: 'InstaPay', vodafone: 'Vodafone Cash', wallet: 'E-wallet' };
        if (map[m]) {
          bankLabel.innerHTML = `Paying to <strong>${map[m]}</strong>`;
          if (bankEdit) bankEdit.textContent = 'Change';
        } else {
          bankLabel.textContent = 'No payout method set yet';
          if (bankEdit) bankEdit.textContent = 'Add now';
        }
      }
    } catch (e) {
      console.warn('[earnings wallet fetch]', e);
    }
  })();

  const debtDueTag = document.getElementById('debtDueTag');
  if (debtDueTag) {
    const settle = document.getElementById('liability-settlement-date')?.textContent?.trim();
    debtDueTag.textContent = settle && settle !== '—' ? `Due ${settle}` : 'Outstanding';
  }

  // Liability items — last 5 cash completed bookings
  const liabilityList = document.getElementById('liability-items-list');
  if (liabilityList) {
    if (cashCompleted.length === 0) {
      liabilityList.innerHTML = `
        <div class="liability-empty">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M20 6 9 17l-5-5"/></svg>
          <span>${_t('tech_no_outstanding') || 'All settled — no outstanding cash balance.'}</span>
        </div>`;
    } else {
      liabilityList.innerHTML = cashCompleted.slice(0, 5).map(b => {
        const shortId = b._id.slice(-6).toUpperCase();
        const snap = bookingFeeSnapshot(b);
        const feeStr = `${snap.fee.toLocaleString('en-US')} EGP`;
        const breakdown = `${snap.gross.toLocaleString('en-US')} EGP \u00D7 ${snap.feeRate}%`;
        return `
          <div class="jq-premium-liability-row">
            <div class="jq-premium-liability-info">
              <span class="jq-premium-liability-id">#${shortId}</span>
              <span class="jq-premium-liability-tag">${_t('tech_commission') || 'Commission'}</span>
              <span class="jq-premium-liability-breakdown">${breakdown}</span>
            </div>
            <span class="jq-premium-liability-val">${feeStr}</span>
          </div>`;
      }).join('');
    }
  }

  // Show warning if outstanding > 2000
  const liabilityWarning = document.getElementById('liabilityWarning');
  if (liabilityWarning) liabilityWarning.hidden = outstandingAmount < 2000;

  // Recent jobs list
  const recentList = document.getElementById('earnings-recent-list');
  if (recentList) {
    const recentCompleted = completed
      .sort((a, b) => new Date(b.scheduledDate || b.updatedAt) - new Date(a.scheduledDate || a.updatedAt))
      .slice(0, 3);

    if (recentCompleted.length === 0) {
      recentList.innerHTML = `
        <div class="recent-jobs__empty">
          <strong>No jobs yet.</strong>
          <span>Once you complete a job, it'll appear here with its settlement type.</span>
        </div>`;
    } else {
      recentList.innerHTML = recentCompleted.map(b => {
        const service = b.service?.title || b.service?.category || 'Service';
        const dateStr = b.scheduledDate
          ? new Date(b.scheduledDate).toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' })
          : '—';
        const isCash = b.paymentMethod === 'cash';
        const snap = bookingFeeSnapshot(b);
        const amountStr = `+${snap.net.toLocaleString('en-US')} EGP`;
        const customer = b.user?.name || 'Not listed';
        const feeStr = `${snap.fee.toLocaleString('en-US')} EGP`;
        const badgeCls = isCash ? 'jq-earn-row-tag--cash' : 'jq-earn-row-tag--online';
        const badgeLbl = isCash ? 'CASH' : 'ONLINE';
        return `
          <div class="jq-premium-earn-row" data-reveal>
            <div class="jq-earn-row-left">
              <div class="jq-earn-row-icon">
                <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
              </div>
              <div class="jq-earn-row-info">
                <div class="jq-earn-row-title">
                  <h4>${escapeHtml(service)}</h4>
                  <span class="jq-earn-row-date">${escapeHtml(dateStr)}</span>
                </div>
                <div class="jq-earn-row-customer">
                  <span class="jq-earn-row-customer__label">Customer</span>
                  <span class="jq-earn-row-customer__name">${escapeHtml(customer)}</span>
                </div>
              </div>
            </div>
            <div class="jq-earn-row-amount">
              <span class="jq-earn-row-amount__net">${amountStr}</span>
              <span class="jq-earn-row-tag ${badgeCls}">${badgeLbl}</span>
              <span class="jq-earn-row-fee"><span>Fee</span><strong>${feeStr}</strong></span>
            </div>
          </div>`;
      }).join('');
    }
  }

  // Next settlement date
  const settlementEl = document.getElementById('liability-settlement-date');
  if (settlementEl) {
    const now = new Date();
    const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    const settlementStr = lastDay.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });
    settlementEl.textContent = settlementStr;
  }

  renderEarningsOverviewExtras({ monthTakeHome: monthEarnings, completed });
}

// ── Load notifications from backend API ───────────────────────────────────────
async function loadNotifications() {
  const list = document.getElementById('notif-items-list');
  const emptyEl = document.getElementById('notif-empty');
  if (!list) return;

  try {
    const res = await apiGetTechNotifs(30);
    const notifs = res.notifications || [];
    const unread = res.unreadCount ?? notifs.filter(n => !n.isRead).length;
    updateTopbarBadge(unread > 0 ? unread : 0);

    if (!notifs.length) {
      list.innerHTML = '';
      if (emptyEl) emptyEl.hidden = false;
      return;
    }
    if (emptyEl) emptyEl.hidden = true;

    const typeIcon = {
      booking_created: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="3" y1="10" x2="21" y2="10"/></svg>`,
      booking_accepted: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>`,
      booking_cancelled: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`,
      booking_completed: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>`,
      booking_action_required: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`,
      review_received: `<svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" stroke="none"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`,
      payment_released: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>`,
      system: `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>`,
    };

    function timeAgo(dateStr) {
      const diff = Date.now() - new Date(dateStr).getTime();
      const m = Math.floor(diff / 60000);
      if (m < 1) return 'Just now';
      if (m < 60) return `${m}m ago`;
      const h = Math.floor(m / 60);
      if (h < 24) return `${h}h ago`;
      return `${Math.floor(h / 24)}d ago`;
    }

    function normalizeUrl(raw) {
      if (!raw) return null;
      let r = raw;
      // Rewrite legacy URLs that role-guard would block for technicians
      if (r.includes('booking-details.html')) r = './technician-dashboard.html#job-queue';
      else if (r.includes('customer-dashboard.html')) r = r.replace(/customer-dashboard\.html/, 'technician-dashboard.html');
      try {
        const u = new URL(r, window.location.href);
        return u.pathname + u.search + u.hash;
      } catch { return r; }
    }

    list.innerHTML = notifs.map(n => {
      const icon = typeIcon[n.type] || typeIcon.system;
      const url = normalizeUrl(n.referenceUrl);
      return `
        <div class="notif-item${!n.isRead ? ' is-unread' : ''}" data-notif-id="${n._id}"${url ? ` data-notif-url="${url}"` : ''}>
          <span class="notif-item__dot"></span>
          <span class="notif-item__icon notif-item__icon--job">${icon}</span>
          <div class="notif-item__body">
            <p class="notif-item__msg">${n.title}</p>
            <span class="notif-item__time">${timeAgo(n.createdAt)}</span>
          </div>
        </div>`;
    }).join('');
  } catch (_) {
    if (list) list.innerHTML = '<div style="padding:1rem;opacity:.6;font-size:.875rem;">Could not load notifications.</div>';
  }
}

/* ── Fix 6: Password show/hide toggles ─────────────────── */
function initPasswordToggles() {
  document.querySelectorAll('.btn-toggle-password').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset.target;
      const input = document.getElementById(targetId);
      if (!input) return;
      const isHidden = input.type === 'password';
      input.type = isHidden ? 'text' : 'password';
      const openIcon = btn.querySelector('.eye-icon--open');
      const closedIcon = btn.querySelector('.eye-icon--closed');
      if (openIcon) openIcon.style.display = isHidden ? 'none' : '';
      if (closedIcon) closedIcon.style.display = isHidden ? '' : 'none';
      const showLabel = typeof window.t === 'function' ? window.t('pw_show') : 'Show password';
      const hideLabel = typeof window.t === 'function' ? window.t('pw_hide') : 'Hide password';
      btn.setAttribute('aria-label', isHidden ? hideLabel : showLabel);
    });
  });
}

/* ── Fix 7: Settings validation ─────────────────────────── */
function initSettingsValidation() {
  const emailInput = document.getElementById('s-email');
  const newPasswordInput = document.getElementById('s-new-password');
  const confirmPasswordInput = document.getElementById('s-confirm-password');

  function getContainer(input) {
    const wrap = input.closest('.input-password-wrap');
    return wrap ? wrap.parentElement : input.parentElement;
  }

  function setFieldState(input, valid, message) {
    input.classList.toggle('is-valid', valid);
    input.classList.toggle('is-invalid', !valid);
    const container = getContainer(input);
    let errorEl = container.querySelector('.field-error');
    if (!valid && message) {
      if (!errorEl) {
        errorEl = document.createElement('span');
        errorEl.className = 'field-error';
        container.appendChild(errorEl);
      }
      errorEl.textContent = message;
    } else if (errorEl) {
      errorEl.remove();
    }
  }

  function clearFieldState(input) {
    input.classList.remove('is-valid', 'is-invalid');
    const errorEl = getContainer(input).querySelector('.field-error');
    if (errorEl) errorEl.remove();
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  if (emailInput) {
    emailInput.addEventListener('blur', () => {
      const val = emailInput.value.trim();
      if (!val) { clearFieldState(emailInput); return; }
      if (emailRegex.test(val)) {
        setFieldState(emailInput, true, '');
      } else {
        setFieldState(emailInput, false, typeof window.t === 'function' ? window.t('err_invalid_email') : 'Please enter a valid email address.');
      }
    });
    emailInput.addEventListener('input', () => {
      if (emailInput.classList.contains('is-invalid') && emailRegex.test(emailInput.value.trim())) {
        setFieldState(emailInput, true, '');
      }
    });
  }

  const mismatchMsg = () => typeof window.t === 'function' ? window.t('err_pw_mismatch') : 'Passwords do not match.';

  function validatePasswordMatch(showError = true) {
    if (!newPasswordInput || !confirmPasswordInput) return;
    const newVal = newPasswordInput.value;
    const confirmVal = confirmPasswordInput.value;
    if (!newVal && !confirmVal) {
      clearFieldState(confirmPasswordInput);
      return;
    }
    if (!confirmVal) { clearFieldState(confirmPasswordInput); return; }
    if (newVal === confirmVal) {
      setFieldState(confirmPasswordInput, true, '');
    } else if (showError) {
      setFieldState(confirmPasswordInput, false, mismatchMsg());
    } else {
      // While typing: clear the error if it was previously shown, don't add a new one
      clearFieldState(confirmPasswordInput);
    }
  }

  if (confirmPasswordInput) {
    // Show error only after the user leaves the field
    confirmPasswordInput.addEventListener('blur', () => validatePasswordMatch(true));
    // While typing: only clear the error when they've matched; never add new error mid-type
    confirmPasswordInput.addEventListener('input', () => validatePasswordMatch(false));
  }
  if (newPasswordInput) {
    newPasswordInput.addEventListener('input', () => {
      if (confirmPasswordInput?.value) validatePasswordMatch(false);
    });
  }
}

function initSettingsForm() {
  const form = document.querySelector('[data-settings-form]');
  if (!form) return;

  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const imgStyle = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';

  // ── Photo upload ──────────────────────────────────────────
  const changePhotoBtn = document.getElementById('btn-change-photo');
  const photoUploadInput = document.getElementById('photo-upload-input');
  const preview = document.querySelector('[data-avatar-preview]');

  if (changePhotoBtn && photoUploadInput) {
    changePhotoBtn.addEventListener('click', () => photoUploadInput.click());

    photoUploadInput.addEventListener('change', async () => {
      const file = photoUploadInput.files[0];
      if (!file) return;

      if (file.size > 2 * 1024 * 1024) {
        showToast(_t('toast_photo_error') || 'Image must be under 2 MB.', 'error');
        photoUploadInput.value = '';
        return;
      }

      // Instant local preview
      const reader = new FileReader();
      reader.onload = (e) => {
        if (preview) {
          preview.innerHTML = `<img src="${e.target.result}" alt="Profile photo" style="${imgStyle}" />`;
          preview.classList.remove('avatar-required');
          const hint = preview.closest('.settings-avatar-wrap')?.nextElementSibling;
          if (hint?.classList.contains('avatar-required-hint')) hint.remove();
        }
        const topbar = document.getElementById('topbar-avatar');
        if (topbar) topbar.innerHTML = `<img src="${e.target.result}" alt="Profile photo" style="${imgStyle}" />`;
        // Cache locally so photo persists across reloads before save
        try { localStorage.setItem('servio_avatar_cache', e.target.result); } catch (_) { }
      };
      reader.readAsDataURL(file);

      // Upload to server
      changePhotoBtn.disabled = true;
      changePhotoBtn.textContent = _t('toast_photo_uploading') || 'Uploading…';
      try {
        const result = await uploadPublicFile(file, 'avatar');
        _pendingPhotoUrl = result.url;
        showToast(_t('toast_photo_uploaded') || 'Photo uploaded.', 'success');
      } catch {
        showToast(_t('toast_photo_error') || 'Failed to upload photo.', 'error');
        _pendingPhotoUrl = null;
      } finally {
        changePhotoBtn.disabled = false;
        changePhotoBtn.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg><span data-i18n="cust_change_photo">${_t('cust_change_photo') || 'Change Photo'}</span>`;
      }
    });
  }

  // ── Save ──────────────────────────────────────────────────
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const currentSession = getSession();
    const photoUrl = _pendingPhotoUrl || currentSession?.profileImage || null;

    // Mandatory guard — technicians must have a profile photo
    if (!photoUrl) {
      showToast(_t('toast_photo_required') || 'Please add a profile photo before saving.', 'error');
      if (preview) preview.classList.add('avatar-required');
      return;
    }

    const account = getAccount() || {};
    const passwordFields = new Set(['newPassword', 'confirmPassword']);
    document.querySelectorAll('[data-settings-field]').forEach(f => {
      if (!passwordFields.has(f.dataset.settingsField)) account[f.dataset.settingsField] = f.value;
    });
    localStorage.setItem('servio_account', JSON.stringify(account));

    try {
      await updateMe({
        name: account.fullName || account.name || '',
        phone: account.phone || '',
        profileImage: photoUrl,
      });

      if (currentSession) {
        if (account.fullName) currentSession.name = account.fullName;
        currentSession.profileImage = photoUrl;
        localStorage.setItem('servio_session', JSON.stringify(currentSession));
      }
      if (_pendingPhotoUrl) _pendingPhotoUrl = null;
      // Keep servio_avatar_cache — server may return a local path that browsers can't load

      showToast(_t('toast_settings_saved') || 'Your changes have been saved.', 'success');
    } catch (err) {
      showToast(err.message || 'Failed to save settings.', 'error');
    }
  });

  // Delete account button — opens confirmation modal
  const deleteBtn = document.getElementById('btn-delete-account');
  if (deleteBtn) {
    deleteBtn.addEventListener('click', () => {
      const modal = document.getElementById('modal-delete-account');
      if (modal) modal.style.display = 'flex';
    });
  }

  const saveScheduleBtn = document.getElementById('save-schedule');
  const scheduleFeedback = document.getElementById('avail-schedule-feedback');
  if (saveScheduleBtn) {
    saveScheduleBtn.addEventListener('click', async () => {
      const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
      const slots = [];
      let hasTimeError = false;
      document.querySelectorAll('#avail-schedule .avail-day-row').forEach(row => {
        const dayKey = row.dataset.day;
        const isOff = row.classList.contains('is-off');
        if (isOff) return;
        const fromSel = row.querySelector(`#avail-from-${dayKey}`);
        const toSel = row.querySelector(`#avail-to-${dayKey}`);
        if (!fromSel || !toSel) return;
        const from = fromSel.value;
        const to = toSel.value;
        if (to <= from) {
          toSel.classList.add('is-error');
          hasTimeError = true;
          return;
        }
        toSel.classList.remove('is-error');
        slots.push({ day: dayKey, from, to });
      });

      if (hasTimeError) {
        showToast(_t('toast_avail_time_error') || 'End time must be after start time.', 'error');
        return;
      }

      const origLabel = saveScheduleBtn.querySelector('.avail-save-btn__label');
      if (origLabel) origLabel.textContent = _t('tech_saving') || 'Saving…';
      const iconSpan = saveScheduleBtn.querySelector('.avail-save-btn__icon');
      if (iconSpan) iconSpan.innerHTML = '<span class="spinner"></span>';
      saveScheduleBtn.disabled = true;
      if (scheduleFeedback) scheduleFeedback.hidden = true;

      try {
        await updateAvailability(slots);
        try {
          const acc = JSON.parse(localStorage.getItem('servio_account') || '{}');
          acc.availability = slots;
          localStorage.setItem('servio_account', JSON.stringify(acc));
        } catch (_) { }

        if (scheduleFeedback) { scheduleFeedback.hidden = false; setTimeout(() => { scheduleFeedback.hidden = true; }, 3500); }
        showToast(_t('tech_schedule_saved_msg') || 'Schedule saved successfully!', 'success');
      } catch (err) {
        showToast(err?.message || 'Failed to save schedule.', 'error');
      } finally {
        saveScheduleBtn.disabled = false;
        if (origLabel) origLabel.textContent = _t('tech_save_schedule') || 'Save Schedule';
        if (iconSpan) iconSpan.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>`;
      }
    });
  }

  const saveCoverageBtn = document.getElementById('save-coverage');
  const coverageFeedback = document.getElementById('avail-coverage-feedback');
  const coverageChipsRoot = document.getElementById('coverage-area-chips');
  const coverageSummary = document.getElementById('coverage-summary');
  const coverageCustomInput = document.getElementById('service-area');
  const clearCoverageBtn = document.getElementById('coverage-clear');
  const resetCoverageBtn = document.getElementById('coverage-reset');
  const modalResetCoverageBtn = document.getElementById('coverage-modal-reset');
  const cardClearCoverageBtn = document.getElementById('coverage-card-clear');
  const cardSaveCoverageBtn = document.getElementById('coverage-card-save');
  const openCoverageBtn = document.getElementById('coverage-open-modal');
  const closeCoverageBtn = document.getElementById('coverage-modal-close');
  const cancelCoverageBtn = document.getElementById('coverage-modal-cancel');
  const coverageModal = document.getElementById('coverage-modal');
  const coverageModalBackdrop = coverageModal?.querySelector('[data-coverage-modal-close]');
  if (clearCoverageBtn && !clearCoverageBtn.dataset.bound) {
    clearCoverageBtn.dataset.bound = 'true';
    clearCoverageBtn.addEventListener('click', () => {
      clearCoverageSelection(coverageChipsRoot, coverageSummary, coverageCustomInput);
    });
  }
  if (resetCoverageBtn && !resetCoverageBtn.dataset.bound) {
    resetCoverageBtn.dataset.bound = 'true';
    resetCoverageBtn.addEventListener('click', () => {
      resetCoverageToSaved(coverageChipsRoot, coverageSummary, coverageCustomInput);
    });
  }
  if (modalResetCoverageBtn && !modalResetCoverageBtn.dataset.bound) {
    modalResetCoverageBtn.dataset.bound = 'true';
    modalResetCoverageBtn.addEventListener('click', () => {
      resetCoverageToSaved(coverageChipsRoot, coverageSummary, coverageCustomInput);
    });
  }
  if (cardClearCoverageBtn && !cardClearCoverageBtn.dataset.bound) {
    cardClearCoverageBtn.dataset.bound = 'true';
    cardClearCoverageBtn.addEventListener('click', () => {
      clearCoverageSelection(coverageChipsRoot, coverageSummary, coverageCustomInput);
    });
  }
  if (cardSaveCoverageBtn && !cardSaveCoverageBtn.dataset.bound) {
    cardSaveCoverageBtn.dataset.bound = 'true';
    cardSaveCoverageBtn.addEventListener('click', () => saveCoverageBtn?.click());
  }
  if (openCoverageBtn && !openCoverageBtn.dataset.bound) {
    openCoverageBtn.dataset.bound = 'true';
    openCoverageBtn.addEventListener('click', openCoverageModal);
  }
  if (closeCoverageBtn && !closeCoverageBtn.dataset.bound) {
    closeCoverageBtn.dataset.bound = 'true';
    closeCoverageBtn.addEventListener('click', () => closeCoverageModal({ reset: true }));
  }
  if (cancelCoverageBtn && !cancelCoverageBtn.dataset.bound) {
    cancelCoverageBtn.dataset.bound = 'true';
    cancelCoverageBtn.addEventListener('click', () => closeCoverageModal({ reset: true }));
  }
  if (coverageModalBackdrop && !coverageModalBackdrop.dataset.bound) {
    coverageModalBackdrop.dataset.bound = 'true';
    coverageModalBackdrop.addEventListener('click', () => closeCoverageModal({ reset: true }));
  }
  if (coverageModal && !coverageModal.dataset.escapeBound) {
    coverageModal.dataset.escapeBound = 'true';
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && coverageModal.classList.contains('is-open')) {
        closeCoverageModal({ reset: true });
      }
    });
  }
  if (saveCoverageBtn) {
    if (saveCoverageBtn.dataset.bound) return;
    saveCoverageBtn.dataset.bound = 'true';
    saveCoverageBtn.addEventListener('click', async () => {
      const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
      const serviceAreaInput = document.getElementById('service-area');
      const coverageChips = document.getElementById('coverage-area-chips');
      const customAreas = normalizeAreaList(serviceAreaInput?.value || '');
      const coverageAreas = normalizeAreaList([
        ...getSelectedCoverageAreas(coverageChips),
        ...customAreas,
      ]);
      const serviceArea = coverageAreas.join(', ');
      const origLabel = saveCoverageBtn.querySelector('.avail-save-btn__label');
      if (origLabel) origLabel.textContent = _t('tech_saving') || 'Saving…';
      const iconSpan = saveCoverageBtn.querySelector('.avail-save-btn__icon');
      if (iconSpan) iconSpan.innerHTML = '<span class="spinner"></span>';
      saveCoverageBtn.disabled = true;
      if (coverageFeedback) coverageFeedback.hidden = true;

      try {
        const profileUpdate = {};
        profileUpdate.coverageAreas = coverageAreas; // allow empty to clear
        profileUpdate.serviceArea = serviceArea; // preserve legacy display behavior
        await updateMe(profileUpdate);

        try {
          const acc = JSON.parse(localStorage.getItem('servio_account') || '{}');
          acc.serviceArea = serviceArea;
          acc.coverageAreas = coverageAreas;
          localStorage.setItem('servio_account', JSON.stringify(acc));
        } catch (_) { }
        const savedCoverageSplit = splitCoverageAreasByTaxonomy(coverageAreas);
        if (serviceAreaInput) serviceAreaInput.value = savedCoverageSplit.custom.join(', ');
        renderCoverageEditor({
          container: coverageChips,
          searchInput: document.getElementById('coverage-search'),
          summaryEl: document.getElementById('coverage-summary'),
          selectedAreas: savedCoverageSplit.known,
          customInput: serviceAreaInput,
        });
        setCoverageSavedBaseline(coverageChips, serviceAreaInput);

        if (coverageFeedback) { coverageFeedback.hidden = false; setTimeout(() => { coverageFeedback.hidden = true; }, 3500); }
        showToast(_t('tech_coverage_saved_msg') || 'Coverage saved successfully!', 'success');
        if (document.getElementById('coverage-modal')?.classList.contains('is-open')) closeCoverageModal();
      } catch (err) {
        showToast(err?.message || 'Failed to save coverage.', 'error');
      } finally {
        saveCoverageBtn.disabled = false;
        if (origLabel) origLabel.textContent = _t('tech_save_coverage') || 'Save Coverage';
        if (iconSpan) iconSpan.innerHTML = `<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>`;
        syncCoverageControls(coverageChips, document.getElementById('coverage-summary'), serviceAreaInput);
      }
    });
  }
}

/* ── Settings horizontal tab switching ─────────────────── */
function initSettingsTabs() {
  const bar = document.getElementById('settings-tab-bar');
  if (!bar) return;
  bar.addEventListener('click', (e) => {
    const btn = e.target.closest('.stab-btn');
    if (!btn) return;
    const target = btn.dataset.stab;
    bar.querySelectorAll('.stab-btn').forEach(b => {
      b.classList.toggle('stab-btn--active', b === btn);
      b.setAttribute('aria-selected', b === btn ? 'true' : 'false');
    });
    document.querySelectorAll('.stab-pane').forEach(p => {
      const isTarget = p.id === 'stab-' + target;
      p.classList.toggle('stab-pane--active', isTarget);
      if (isTarget) p.removeAttribute('hidden');
      else p.setAttribute('hidden', '');
    });
    if (target === 'profile') updateProfileCompleteness();
  });
  updateProfileCompleteness();
}

/* ── Profile completeness bar ────────────────────────────── */
function updateProfileCompleteness() {
  const account = typeof getAccount === 'function' ? getAccount() : null;
  const fields = ['fullName', 'email', 'phone', 'specialty', 'hourlyRate', 'bio'];
  const coverageFilled = getCoverageAreasFromAccount(account || {}).length > 0;
  const availabilityFilled = Array.isArray(account?.availability) && account.availability.length > 0;
  const filled = fields.filter(f => account && account[f] && String(account[f]).trim()).length
    + (coverageFilled ? 1 : 0)
    + (availabilityFilled ? 1 : 0);
  const avatar = document.querySelector('.settings-avatar-preview img');
  const total = fields.length + 3;
  const score = Math.round(((filled + (avatar ? 1 : 0)) / total) * 100);
  const pct = document.getElementById('profile-complete-pct');
  const bar = document.getElementById('profile-complete-bar');
  const fill = document.getElementById('profile-complete-fill');
  if (pct) pct.textContent = score + '%';
  if (bar) bar.setAttribute('aria-valuenow', score);
  if (fill) fill.style.width = score + '%';
}

/* ── Security form (separate from profile form) ──────────── */
function initTechSecurityForm() {
  const form = document.getElementById('tech-security-form');
  if (!form) return;
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const currentPw = form.querySelector('#s-current-password');
    const newPw = form.querySelector('#s-new-password');
    const confirmPw = form.querySelector('#s-confirm-password');
    const submitBtn = form.querySelector('[type="submit"]');
    if (!currentPw.value.trim()) {
      showToast(_t('toast_enter_current_pw') || 'Enter your current password.', 'info');
      currentPw.focus(); return;
    }
    if (newPw.value.length < 8) {
      showToast(_t('toast_pw_min_length') || 'Password must be at least 8 characters.', 'info');
      newPw.focus(); return;
    }
    if (!/[0-9]/.test(newPw.value)) {
      showToast(_t('toast_pw_needs_number') || 'Password must contain at least one number.', 'info');
      newPw.focus(); return;
    }
    if (!/[^A-Za-z0-9]/.test(newPw.value)) {
      showToast(_t('toast_pw_needs_special') || 'Password must contain at least one special character.', 'info');
      newPw.focus(); return;
    }
    if (newPw.value === currentPw.value) {
      showToast(_t('toast_pw_same_as_current') || 'New password must be different from your current password.', 'info');
      newPw.focus(); return;
    }
    if (newPw.value !== confirmPw.value) {
      showToast(_t('toast_pw_mismatch') || 'Passwords do not match.', 'info');
      confirmPw.focus(); return;
    }
    if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = _t('tech_updating') || 'Updating…'; }
    try {
      await updatePassword({ currentPassword: currentPw.value, newPassword: newPw.value });
      currentPw.value = '';
      newPw.value = '';
      confirmPw.value = '';
      document.getElementById('pw-strength-wrap')?.setAttribute('hidden', '');
      document.querySelectorAll('.pw-check').forEach(c => c.classList.remove('is-met'));
      showToast(_t('toast_pw_updated') || 'Password updated. Please sign in again.', 'success');
      setTimeout(() => {
        localStorage.removeItem('servio_token');
        localStorage.removeItem('servio_session');
        window.location.href = './login.html';
      }, 1500);
    } catch (err) {
      showToast(err.message || 'Failed to update password.', 'error');
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = _t('tech_update_password') || 'Update Password'; }
    }
  });
}

/* ── Password strength meter + live checklist ────────────── */
function initPasswordStrengthMeter() {
  const newPw = document.getElementById('s-new-password');
  const confirmPw = document.getElementById('s-confirm-password');
  const wrap = document.getElementById('pw-strength-wrap');
  const fill = document.getElementById('pw-strength-fill');
  const label = document.getElementById('pw-strength-label');
  const matchHint = document.getElementById('pw-match-hint');
  if (!newPw || !wrap) return;

  const checks = {
    length: { el: document.getElementById('pwc-length'), test: v => v.length >= 8 },
    upper: { el: document.getElementById('pwc-upper'), test: v => /[A-Z]/.test(v) },
    number: { el: document.getElementById('pwc-number'), test: v => /\d/.test(v) },
    special: { el: document.getElementById('pwc-special'), test: v => /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(v) },
  };
  const strengthLabels = ['', 'tech_pw_strength_weak', 'tech_pw_strength_fair', 'tech_pw_strength_good', 'tech_pw_strength_strong'];

  newPw.addEventListener('input', () => {
    const v = newPw.value;
    if (!v) { wrap.setAttribute('hidden', ''); return; }
    wrap.removeAttribute('hidden');
    let met = 0;
    Object.values(checks).forEach(c => {
      const pass = c.test(v);
      c.el?.classList.toggle('is-met', pass);
      if (pass) met++;
    });
    fill.setAttribute('data-level', met);
    fill.style.width = (met * 25) + '%';
    const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
    label.textContent = _t(strengthLabels[met]);
    label.setAttribute('data-level', met);
    if (confirmPw.value) checkMatch();
  });

  function checkMatch() {
    if (!matchHint || !confirmPw.value) return;
    const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
    const match = newPw.value === confirmPw.value;
    matchHint.removeAttribute('hidden');
    matchHint.textContent = _t(match ? 'tech_pw_match' : 'tech_pw_no_match');
    matchHint.className = 'pw-match-hint ' + (match ? 'is-match' : 'is-mismatch');
  }
  confirmPw?.addEventListener('input', checkMatch);
}

/* ── Settings toggles (notifications, 2FA) ──────────────── */
function initSettingToggles() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  const prefs = JSON.parse(localStorage.getItem('servio_tech_notif_prefs') || '{}');
  document.querySelectorAll('.stab-toggle[data-pref]').forEach(btn => {
    const key = btn.dataset.pref;
    if (key in prefs) {
      const on = prefs[key];
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
    }
    btn.addEventListener('click', () => {
      const on = btn.getAttribute('aria-checked') !== 'true';
      btn.setAttribute('aria-checked', on ? 'true' : 'false');
      btn.classList.toggle('stab-toggle--on', on);
      prefs[key] = on;
      localStorage.setItem('servio_tech_notif_prefs', JSON.stringify(prefs));
      showToast(_t('toast_notif_saved'), 'success');
    });
  });
}

/* ── Language cards ─────────────────────────────────────── */
function initLanguageCards() {
  const cards = document.getElementById('lang-cards');
  if (!cards) return;
  function syncCards() {
    const current = localStorage.getItem('servio_lang') || 'en';
    cards.querySelectorAll('.lang-card').forEach(c => {
      c.setAttribute('aria-checked', c.dataset.lang === current ? 'true' : 'false');
    });
  }
  syncCards();
  cards.addEventListener('click', (e) => {
    const card = e.target.closest('.lang-card');
    if (!card) return;
    const lang = card.dataset.lang;
    const switcher = document.querySelector('[data-lang-switcher], [data-lang-switch]');
    if (switcher) {
      switcher.value = lang;
      switcher.dispatchEvent(new Event('change'));
    } else if (typeof window.setLang === 'function') {
      window.setLang(lang);
    } else {
      localStorage.setItem('servio_lang', lang);
      location.reload();
    }
    syncCards();
  });
  document.addEventListener('langchange', syncCards);
}

/* ── Theme cards ─────────────────────────────────────────── */
function initThemeCards() {
  const cards = document.getElementById('theme-cards');
  if (!cards) return;
  function syncCards() {
    const current = localStorage.getItem('servio_theme') || 'system';
    cards.querySelectorAll('.theme-card').forEach(c => {
      c.setAttribute('aria-checked', c.dataset.themeChoice === current ? 'true' : 'false');
    });
  }
  syncCards();
  cards.addEventListener('click', (e) => {
    const card = e.target.closest('.theme-card');
    if (!card) return;
    const choice = card.dataset.themeChoice;
    localStorage.setItem('servio_theme', choice);
    let apply = choice;
    if (choice === 'system') {
      apply = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    document.documentElement.setAttribute('data-theme', apply);
    const toggle = document.querySelector('[data-theme-toggle]');
    if (toggle) toggle.checked = apply === 'dark';
    syncCards();
  });
}

/* ── Export / Deactivate account buttons ────────────────── */
function initAccountTab() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  document.getElementById('btn-export-data')?.addEventListener('click', () => {
    showToast(_t('toast_export_requested') || 'Data export requested. You will receive an email shortly.', 'success');
  });
  document.getElementById('btn-deactivate-account')?.addEventListener('click', () => {
    const msg = _t('confirm_deactivate') || 'Deactivate your account? You can log back in to reactivate.';
    if (confirm(msg)) showToast(_t('toast_account_deactivated') || 'Account deactivated.', 'info');
  });
}

function initDashLogout() {
  const btn = document.querySelector('[data-dash-logout]');
  if (!btn) return;
  btn.addEventListener('click', () => {
    try {
      localStorage.removeItem('servio_session');
    } catch (_) { /* ignore */ }
    window.location.href = './login.html?redirect=' + encodeURIComponent(window.location.pathname + window.location.search);
  });
}

/* ── Profile completion banner ──────────────────────────────
   Shows a dismissible banner for approved techs who have
   incomplete profile fields. Shown once per user per browser.
─────────────────────────────────────────────────────────── */
function initProfileCompletionBanner() {
  const account = getAccount();
  const status = account?.status || account?.verificationStatus || '';
  if (status !== 'approved' && status !== 'verified') return;

  const userId = account?._id || account?.id || 'anon';
  const storageKey = `servio_pcb_dismissed_${userId}`;
  if (localStorage.getItem(storageKey)) return;

  const missing = [];
  if (!account?.bio?.trim())
    missing.push({ label: 'Profile bio', tab: 'profile', stab: null });
  if (!account?.photoUrl && !account?.profilePhoto && !account?.avatar)
    missing.push({ label: 'Profile photo', tab: 'profile', stab: null });
  if (!account?.services?.length && !account?.skills?.length)
    missing.push({ label: 'Services offered', tab: 'settings', stab: 'stab-btn-services' });
  if (!account?.serviceArea && !account?.coverageAreas?.length)
    missing.push({ label: 'Service coverage', tab: 'availability', stab: null });
  if (!account?.hourlyRate && !account?.startingRate && !account?.minFee)
    missing.push({ label: 'Pricing rules', tab: 'settings', stab: 'stab-btn-services' });

  if (!missing.length) return;
  const primaryMissing = missing[0];

  const banner = document.createElement('div');
  banner.className = 'pcb';
  banner.id = 'profileCompletionBanner';
  banner.setAttribute('role', 'alert');
  banner.innerHTML = `
    <div class="pcb__inner">
      <span class="pcb__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
        </svg>
      </span>
      <div class="pcb__body">
        <p class="pcb__title">Your account is approved — complete your profile to start receiving bookings</p>
        <div class="pcb__chips">
          ${missing.map(m => `<button type="button" class="pcb__chip" data-goto-tab="${m.tab}" data-goto-stab="${m.stab || ''}">${m.label}</button>`).join('')}
        </div>
      </div>
      <button class="pcb__cta btn btn--sm" type="button" data-goto-tab="${primaryMissing.tab}" data-goto-stab="${primaryMissing.stab || ''}">Complete Setup</button>
      <button class="pcb__close" type="button" aria-label="Dismiss">
        <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
      </button>
    </div>`;

  const dashContent = document.querySelector('.dash-content');
  if (dashContent) dashContent.prepend(banner); else document.querySelector('#main')?.prepend(banner);

  const dismiss = () => {
    banner.classList.add('pcb--out');
    setTimeout(() => banner.remove(), 320);
    localStorage.setItem(storageKey, '1');
  };

  const navigate = (tab, stab) => {
    document.querySelector(`[data-tab="${tab}"]`)?.click();
    if (stab) setTimeout(() => document.getElementById(stab)?.click(), 120);
    dismiss();
  };

  banner.querySelector('.pcb__close').addEventListener('click', dismiss);
  banner.querySelector('.pcb__cta').addEventListener('click', e => {
    navigate(e.currentTarget.dataset.gotoTab, e.currentTarget.dataset.gotoStab);
  });
  banner.querySelectorAll('.pcb__chip').forEach(chip =>
    chip.addEventListener('click', () => navigate(chip.dataset.gotoTab, chip.dataset.gotoStab))
  );
}

/* ── Pending account guard ──────────────────────────────────
   Blocks all dashboard tabs except Verification and Settings
   while the account is pending admin approval.
─────────────────────────────────────────────────────────── */
function initPendingGuard() {
  const account = getAccount();
  const isPending =
    account?.status === 'pending' ||
    account?.verificationStatus === 'pending';
  if (!isPending) return;

  // Build inline doc status rows
  const docs = account?.uploadedDocs || {};
  const DOC_LABELS = {
    idFront: 'National ID — Front',
    idBack: 'National ID — Back',
    idSelfie: 'Selfie with ID',
    cvFile: 'CV / Resume',
    portfolio: 'Portfolio',
  };
  const docRows = Object.entries(DOC_LABELS).map(([key, label]) => {
    const doc = docs[key];
    const uploaded = key === 'portfolio' ? !!(doc?.count) : !!(doc?.uploaded);
    const badge = uploaded
      ? '<span style="color:#065f46;font-weight:600;font-size:0.75rem;">&#10003; Uploaded</span>'
      : '<span style="color:#92400e;font-size:0.75rem;">Pending</span>';
    return `<div style="display:flex;justify-content:space-between;align-items:center;padding:6px 0;border-bottom:1px solid var(--color-border,#e5e7eb);">
      <span style="font-size:0.82rem;">${label}</span>${badge}</div>`;
  }).join('');

  const overlay = document.createElement('div');
  overlay.id = 'pending-overlay';
  overlay.setAttribute('role', 'alert');
  overlay.setAttribute('aria-live', 'polite');
  overlay.innerHTML = `
    <div class="pending-overlay__card">
      <div class="pending-overlay__icon" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="52" height="52" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
        </svg>
      </div>
      <h2 class="pending-overlay__title">Application Under Review</h2>
      <p class="pending-overlay__desc">Your documents are being reviewed by our team. This typically takes 1–2 business days. You'll have full access once your account is approved.</p>
      <div style="width:100%;margin-top:12px;margin-bottom:4px;">${docRows}</div>
      <p style="font-size:0.78rem;color:var(--color-text-light,#6b7280);margin-top:12px;">Questions? Contact us at <strong>support@servio.com</strong></p>
      <div style="width:100%;height:1px;background:var(--color-border,#e5e7eb);margin:20px 0 16px;"></div>
      <button type="button" id="pending-overlay-logout" style="display:inline-flex;align-items:center;gap:7px;padding:9px 20px;border:none;border-radius:10px;background:#f3f4f6;color:#6b7280;font-size:0.82rem;font-weight:500;cursor:pointer;letter-spacing:0.01em;transition:background 0.18s,color 0.18s;" onmouseover="this.style.background='#fee2e2';this.style.color='#dc2626';" onmouseout="this.style.background='#f3f4f6';this.style.color='#6b7280';">
        <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
        Sign Out
      </button>
    </div>
  `;
  document.body.appendChild(overlay);

  // Overlay is permanent — never hidden while account is pending
  overlay.removeAttribute('hidden');

  document.getElementById('pending-overlay-logout')?.addEventListener('click', () => {
    localStorage.removeItem('servio_session');
    window.location.href = './login.html';
  });

  // Swallow ALL tab navigation so sidebar clicks do nothing while pending
  document.querySelectorAll('[data-tab]').forEach(tab => {
    tab.addEventListener('click', e => e.stopImmediatePropagation(), true);
  });
}

/* ── Verification tab: sync document statuses from signup data ──
   Reads account.uploadedDocs written by signup.js and updates
   each document row's badge and shows uploaded filenames.
─────────────────────────────────────────────────────────── */
function updateVerifStatusBanner(status) {
  const banner = document.getElementById('verif-status-banner');
  const textEl = document.getElementById('verif-status-text');
  const hintEl = document.getElementById('verif-status-hint');
  if (!banner || !textEl) return;

  banner.className = 'verif-status';
  if (status === 'verified' || status === 'approved') {
    banner.classList.add('verif-status--verified');
    textEl.textContent = 'Status: Verified ✓';
    if (hintEl) hintEl.textContent = 'Your identity has been verified. You are now a trusted professional on SERVIO.';
  } else if (status === 'rejected') {
    banner.classList.add('verif-status--rejected');
    textEl.textContent = 'Status: Rejected';
    if (hintEl) hintEl.textContent = 'Your verification was rejected. Please re-upload your documents and try again.';
  } else if (status === 'pending' || status === 'not_submitted') {
    banner.classList.add('verif-status--review');
    textEl.textContent = 'Status: Pending Submission';
    if (hintEl) hintEl.textContent = 'Please upload your identity documents to start the verification process.';
  } else {
    banner.classList.add('verif-status--review');
    textEl.textContent = 'Status: Under Review';
    if (hintEl) hintEl.textContent = 'Your documents are being verified. This typically takes 1–2 business days.';
  }
}

function toAbsUrl(url) {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  const base = (window.SERVIO_CONFIG?.API_BASE || 'http://127.0.0.1:5000/api/v1').replace('/api/v1', '');
  return base + url;
}

function initVerificationTab() {
  const panel = document.getElementById('panel-verification');
  if (!panel) return;

  const account = getAccount();
  const docs = account?.uploadedDocs || {};

  // Show status from localStorage first, then refresh from API
  updateVerifStatusBanner(account?.verificationStatus || 'pending');

  panel.querySelectorAll('[data-verif-doc]').forEach(row => {
    const key = row.dataset.verifDoc;
    const doc = docs[key];
    const badge = row.querySelector('[data-verif-badge]');
    const viewBtn = row.querySelector('[data-verif-view]');
    const labelSpan = row.querySelector('[data-verif-upload-label]');
    const fileInput = row.querySelector('input[type="file"]');
    const body = row.querySelector('.verif-doc-row-v2__body');

    // Determine upload state
    const isPortfolio = key === 'portfolio';
    const uploaded = isPortfolio ? !!(doc?.count) : !!(doc?.uploaded);
    const url = isPortfolio ? doc?.files?.[0]?.url : doc?.url;
    const name = isPortfolio
      ? (doc?.count ? doc.count + ' file' + (doc.count > 1 ? 's' : '') + ' uploaded' : '')
      : (doc?.name || '');

    // Update badge
    if (badge) {
      if (uploaded) {
        badge.className = 'badge badge--confirmed';
        badge.textContent = 'Uploaded';
      } else {
        badge.className = 'badge badge--pending';
        badge.textContent = 'Pending';
      }
    }

    // Show/wire View button
    if (viewBtn) {
      const absUrl = toAbsUrl(url);
      if (uploaded && absUrl) {
        viewBtn.hidden = false;
        viewBtn.onclick = () => window.open(absUrl, '_blank');
      } else {
        viewBtn.hidden = true;
      }
    }

    // Update upload label
    if (labelSpan) labelSpan.textContent = uploaded ? 'Replace' : 'Upload';

    // Show filename hint
    if (name && body && !body.querySelector('.verif-doc-filename')) {
      const hint = document.createElement('p');
      hint.className = 'verif-doc-filename';
      hint.textContent = name;
      body.appendChild(hint);
    }

    // Wire re-upload
    if (fileInput) {
      fileInput.addEventListener('change', async () => {
        const files = isPortfolio ? [...fileInput.files] : [fileInput.files[0]];
        if (!files.length || !files[0]) return;

        if (labelSpan) labelSpan.textContent = 'Uploading…';
        try {
          const uploads = await Promise.all(files.map(f => uploadPublicFile(f, key)));
          const firstUrl = toAbsUrl(uploads[0]?.url || '');

          // Update badge
          if (badge) { badge.className = 'badge badge--confirmed'; badge.textContent = 'Uploaded'; }
          // Update view button
          if (viewBtn && firstUrl) { viewBtn.hidden = false; viewBtn.onclick = () => window.open(firstUrl, '_blank'); }
          // Update label
          if (labelSpan) labelSpan.textContent = 'Replace';
          // Update filename hint
          const existingHint = body?.querySelector('.verif-doc-filename');
          const newName = isPortfolio
            ? files.length + ' file' + (files.length > 1 ? 's' : '') + ' uploaded'
            : (files[0].name || '');
          if (existingHint) {
            existingHint.textContent = newName;
          } else if (body && newName) {
            const hint = document.createElement('p');
            hint.className = 'verif-doc-filename';
            hint.textContent = newName;
            body.appendChild(hint);
          }

          // Persist to account
          const acc = getAccount() || {};
          if (!acc.uploadedDocs) acc.uploadedDocs = {};
          if (isPortfolio) {
            acc.uploadedDocs.portfolio = { uploaded: true, count: uploads.length, files: uploads.map(u => ({ url: u.url, name: u.name || '' })) };
          } else {
            acc.uploadedDocs[key] = { uploaded: true, url: firstUrl, name: files[0].name || '' };
          }
          localStorage.setItem('servio_account', JSON.stringify(acc));

          showToast('Document uploaded successfully.', 'success');
        } catch {
          if (labelSpan) labelSpan.textContent = uploaded ? 'Replace' : 'Upload';
          showToast('Upload failed. Please try again.', 'error');
        }
      });
    }
  });

  // Sync fresh data from API — updates status + view button URLs
  getMe().then(user => {
    if (!user) return;
    updateVerifStatusBanner(user.verificationStatus || 'pending');

    // Update account cache
    const acc = getAccount() || {};
    acc.verificationStatus = user.verificationStatus;
    if (!acc.uploadedDocs) acc.uploadedDocs = {};

    const apiDocMap = {
      idFront: { url: user.idFrontUrl, name: user.idFrontName },
      idBack: { url: user.idBackUrl, name: user.idBackName },
      idSelfie: { url: user.idSelfieUrl, name: user.idSelfieName },
      cvFile: { url: user.cvUrl, name: user.cvName },
    };

    Object.entries(apiDocMap).forEach(([key, { url, name }]) => {
      if (!url) return;
      const absUrl = toAbsUrl(url);
      acc.uploadedDocs[key] = { uploaded: true, url: absUrl, name: name || '' };

      // Update view button in DOM
      const row = panel.querySelector(`[data-verif-doc="${key}"]`);
      if (!row) return;
      const vBtn = row.querySelector('[data-verif-view]');
      const badge = row.querySelector('[data-verif-badge]');
      if (vBtn) { vBtn.hidden = false; vBtn.onclick = () => window.open(absUrl, '_blank'); }
      if (badge) { badge.className = 'badge badge--confirmed'; badge.textContent = 'Uploaded'; }
    });

    // Portfolio
    if (user.portfolioFiles?.length) {
      const absFirst = toAbsUrl(user.portfolioFiles[0]?.url || '');
      acc.uploadedDocs.portfolio = { uploaded: true, count: user.portfolioFiles.length, files: user.portfolioFiles.map(f => ({ url: toAbsUrl(f.url), name: f.name || '' })) };
      const row = panel.querySelector('[data-verif-doc="portfolio"]');
      if (row) {
        const vBtn = row.querySelector('[data-verif-view]');
        const badge = row.querySelector('[data-verif-badge]');
        if (vBtn && absFirst) { vBtn.hidden = false; vBtn.onclick = () => window.open(absFirst, '_blank'); }
        if (badge) { badge.className = 'badge badge--confirmed'; badge.textContent = 'Uploaded'; }
      }
    }

    localStorage.setItem('servio_account', JSON.stringify(acc));
  }).catch(() => { });
}

/* ── Notification panel ─────────────────────────────────── */
function initNotifPanel() {
  const btn = document.getElementById('topbar-notif-btn');
  const panel = document.getElementById('notif-panel');
  const markAllBtn = document.getElementById('notif-mark-all');
  const emptyEl = document.getElementById('notif-empty');
  if (!btn || !panel) return;

  function countUnread() {
    return panel.querySelectorAll('.notif-item.is-unread').length;
  }

  function refreshBadgeAndEmpty() {
    const n = countUnread();
    updateTopbarBadge(n);
    const items = panel.querySelectorAll('.notif-item');
    if (emptyEl) emptyEl.hidden = items.length > 0;
  }

  function openPanel() {
    const rect = btn.getBoundingClientRect();
    const panelW = 340;
    const isRTL = document.documentElement.dir === 'rtl';

    panel.style.top = (rect.bottom + 8) + 'px';

    if (isRTL) {
      // RTL: anchor panel's left edge near the button's left edge
      let left = rect.left;
      if (left + panelW > window.innerWidth - 8) left = window.innerWidth - panelW - 8;
      if (left < 8) left = 8;
      panel.style.left = left + 'px';
      panel.style.right = 'auto';
    } else {
      // LTR: anchor panel's right edge to the button's right edge
      let right = window.innerWidth - rect.right;
      if (right < 8) right = 8;
      panel.style.right = right + 'px';
      panel.style.left = 'auto';
    }

    panel.classList.add('is-open');
    btn.setAttribute('aria-expanded', 'true');
  }

  function closePanel() {
    panel.classList.remove('is-open');
    btn.setAttribute('aria-expanded', 'false');
  }

  btn.addEventListener('click', e => {
    e.stopPropagation();
    panel.classList.contains('is-open') ? closePanel() : openPanel();
  });

  // Mark individual item as read on click
  panel.addEventListener('click', async e => {
    const item = e.target.closest('.notif-item');
    if (item) {
      if (item.classList.contains('is-unread')) {
        item.classList.remove('is-unread');
        const id = item.dataset.notifId;
        if (id) apiMarkTechNotifRead(id).catch(() => { });
        refreshBadgeAndEmpty();
      }
      const url = item.dataset.notifUrl;
      if (url) {
        try {
          const target = new URL(url, window.location.href);
          if (target.pathname === window.location.pathname && target.hash) {
            if (window.location.hash === target.hash) {
              window.dispatchEvent(new HashChangeEvent('hashchange'));
            } else {
              window.location.hash = target.hash;
            }
          } else {
            window.location.href = url;
          }
        } catch { window.location.href = url; }
      }
      e.stopPropagation();
    }
  });

  // Mark all read
  markAllBtn?.addEventListener('click', e => {
    panel.querySelectorAll('.notif-item.is-unread').forEach(el => el.classList.remove('is-unread'));
    apiMarkTechAllRead().catch(() => { });
    refreshBadgeAndEmpty();
    e.stopPropagation();
  });

  // Click outside → close
  document.addEventListener('click', () => {
    if (panel.classList.contains('is-open')) closePanel();
  });

  // Escape → close
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape' && panel.classList.contains('is-open')) {
      closePanel();
      btn.focus();
    }
  });
}

// ── Top-level async initialization ───────────────────────────────────────────────
// Fetches live user data first, then seeds the availability UI with real data
function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

async function initReviewsTab(workerId) {
  const summaryEl = document.getElementById('tech-dash-reviews-summary');
  const listEl = document.getElementById('tech-dash-reviews-list');
  if (!summaryEl || !listEl) return;

  listEl.innerHTML = skList(4);

  let reviews = [];
  try {
    reviews = await getWorkerReviews(workerId);
  } catch (_) {
    listEl.innerHTML = `<p style="padding:1rem;opacity:0.6">Could not load reviews.</p>`;
    return;
  }
  updateReviewIndicator(reviews);

  if (!reviews.length) {
    summaryEl.hidden = true;
    listEl.innerHTML = `<p style="padding:1rem;opacity:0.6">No reviews yet.</p>`;
    return;
  }

  const avg = (reviews.reduce((s, r) => s + (r.rating || 0), 0) / reviews.length).toFixed(1);
  const fullStars = Math.round(avg);
  const stars = Array.from({ length: 5 }, (_, i) => i < fullStars ? '★' : '☆').join('');
  summaryEl.hidden = false;
  summaryEl.innerHTML = `
    <div class="reviews-summary__rating">${avg}</div>
    <div>
      <div class="reviews-summary__stars">${stars}</div>
      <div class="reviews-summary__count">Based on ${reviews.length} review${reviews.length !== 1 ? 's' : ''}</div>
    </div>`;

  listEl.innerHTML = reviews.map(r => {
    const name = escapeHtml(r.user?.name || 'Customer');
    const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
    const comment = escapeHtml(r.comment || '');
    const date = r.createdAt
      ? new Date(r.createdAt).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
      : '';
    const starCount = Math.round(r.rating || 0);
    const starHtml = Array.from({ length: 5 }, (_, i) =>
      i < starCount ? '★' : '☆'
    ).join('');
    return `
      <div class="review-card" data-reveal>
        <div class="review-card__header">
          <div class="review-card__avatar">${initials}</div>
          <div class="review-card__meta">
            <p class="review-card__name">${name}</p>
            <p class="review-card__date">${date}</p>
          </div>
        </div>
        <div class="review-card__stars">${starHtml}</div>
        ${comment ? `<p class="review-card__text">"${comment}"</p>` : ''}
      </div>`;
  }).join('');
}

async function renderDebtSection() {
  const section = document.getElementById('techDebtSection');
  if (!section) return;

  try {
    const { items, summary } = await getMyDebts();

    const { totalOutstanding, totalPartiallyPaid, autoDeductedTotal, blockThreshold, remainingBeforeBlock } = summary;
    const totalOwed = totalOutstanding + totalPartiallyPaid;

    section.hidden = totalOwed === 0 && items.every(d => d.status === 'paid');

    const t = window.t || (k => k);

    section.innerHTML = `
      <div class="tech-debt-header">
        <h3>${t('admin_outstanding_debt')}</h3>
        ${totalOwed > 0 ? `<span class="tech-debt-badge">${totalOwed} EGP</span>` : ''}
      </div>
      <div class="tech-debt-stats">
        <div class="tech-debt-stat">
          <span class="label">${t('tech_debt_remaining_before_block')}</span>
          <span class="value ${remainingBeforeBlock < 500 ? 'text-danger' : ''}">${remainingBeforeBlock} EGP</span>
        </div>
        <div class="tech-debt-stat">
          <span class="label">${t('tech_debt_auto_deducted')}</span>
          <span class="value">${autoDeductedTotal} EGP</span>
        </div>
      </div>
      <ul class="tech-debt-list">
        ${items.map(d => `
          <li class="tech-debt-item tech-debt-item--${d.status}">
            <span class="tech-debt-item__amount">${d.amount} EGP</span>
            <span class="tech-debt-item__paid">${d.paidAmount} EGP paid</span>
            <span class="tech-debt-item__status">${d.status.replace('_', ' ')}</span>
          </li>
        `).join('')}
      </ul>
    `;
  } catch (_) {
    if (section) section.hidden = true;
  }
}

function renderCashBlockBanner(worker) {
  const banner = document.getElementById('techCashBlockBanner');
  if (!banner) return;
  const blocked = worker?.restrictions?.cashBookingsBlocked === true;
  banner.hidden = !blocked;
  if (blocked) {
    const t = window.t || (k => k);
    banner.textContent = t('tech_debt_blocked');
  }
}

async function initDashboard() {
  populateProfile();
  updateWelcomeText();
  initTabs();
  initTopbarAvatar();
  initSettingsForm();
  initPasswordToggles();
  initSettingsValidation();
  initSettingsTabs();
  initTechSecurityForm();
  initPasswordStrengthMeter();
  initSettingToggles();
  initLanguageCards();
  initThemeCards();
  initAccountTab();
  initDashLogout();
  initNotifPanel();
  initPhase2();
  initVerificationTab();
  initPendingGuard();
  initProfileCompletionBanner();

  // Fetch live availability data and seed the panel
  let liveAvailability = null;
  let liveIsAvailable = false;
  let liveServiceArea = '';
  let liveCoverageAreas = [];
  let liveBlockedDates = [];
  try {
    const res = await getMe();
    const user = res?.user || res?.data?.user || res?.data || res;
    liveAvailability = user?.availability || null;
    liveIsAvailable = user?.isAvailable || false;
    liveServiceArea = user?.serviceArea || '';
    liveCoverageAreas = getCoverageAreasFromAccount(user || {});
    liveBlockedDates = user?.blockedDates || [];
    // Populate service area input
    const saInput = document.getElementById('service-area');
    const liveCoverageSplit = splitCoverageAreasByTaxonomy(liveCoverageAreas);
    if (saInput) saInput.value = liveCoverageSplit.custom.join(', ');
    renderCoverageEditor({
      container: document.getElementById('coverage-area-chips'),
      searchInput: document.getElementById('coverage-search'),
      summaryEl: document.getElementById('coverage-summary'),
      selectedAreas: liveCoverageSplit.known,
      customInput: saInput,
    });
    setCoverageSavedBaseline(document.getElementById('coverage-area-chips'), saInput);
    if (user?._id) initReviewsTab(user._id);
    await renderDebtSection();
    renderCashBlockBanner(user);
  } catch (_) {
    // Fall back to cached data
    const acc = getAccount();
    liveAvailability = acc?.availability || null;
    liveIsAvailable = acc?.isAvailable || false;
    liveServiceArea = acc?.serviceArea || '';
    liveCoverageAreas = getCoverageAreasFromAccount(acc || {});
    liveBlockedDates = acc?.blockedDates || [];
  }

  initAvailableNowToggle(liveIsAvailable);
  initAvailabilitySchedule(liveAvailability);
  initBlockedDatesCalendar(liveAvailability || [], liveBlockedDates);

  // Fire data fetches in parallel — stats/queue/earnings all come from bookings API
  await Promise.allSettled([
    populateStats(),
    initJobQueue(),
  ]);

  // Poll every 15s — sidebar indicators + job queue if currently visible.
  // Polite poller: skips while user types / modal open / tab hidden,
  // skips DOM rebuild when payload hash unchanged, preserves focus.
  let _jqPolling = false;
  const techPoller = createPoller({
    name: 'tech-dashboard',
    intervalMs: 15_000,
    tick: async () => {
      let bookings = [];
      try {
        const res = await getWorkerBookings({ limit: 200 });
        bookings = res?.bookings || (Array.isArray(res) ? res : []);
      } catch (_) { return; }

      // Sidebar badges — surgical textContent update, always safe to run
      updateSidebarIndicators(bookings);

      const activePanel = document.querySelector('[data-panel].is-active');
      if (activePanel?.dataset.panel !== 'job-queue') return;
      if (_jqPolling) return;

      // Skip rebuild when bookings unchanged → no flicker, no caret loss
      const summary = bookings.map(b => `${b._id}:${b.status}:${b.updatedAt || ''}`);
      if (!hasChanged('tech:jobQueue', summary)) return;

      _jqPolling = true;
      const jqRoot = document.querySelector('[data-panel="job-queue"]') || document;
      const snap = snapshotFocus(jqRoot);
      try {
        const activeStab = document.querySelector('#jq-tab-bar .stab-btn--active')?.dataset.stab;
        const restoreTab = activeStab?.replace('jq-', '') || null;
        await initJobQueue(restoreTab);
        restoreFocus(snap, jqRoot);
      } catch (_) { }
      finally { _jqPolling = false; }
    }
  });
  techPoller.start();
}

/* Re-render dynamic grids and welcome text on language change */
document.addEventListener('langchange', () => {
  updateWelcomeText();
  const acc = getAccount();
  const scheduleContainer = document.getElementById('avail-schedule');
  if (scheduleContainer) { scheduleContainer.innerHTML = ''; initAvailabilitySchedule(acc?.availability || null); }
  // Re-render data-driven sections with new language
  populateStats().catch(() => { });
  initJobQueue().catch(() => { });
});

/* ── Phase 2: Job Board, Proposals, Arrival Flow ── */
function initPhase2() {
  // Quick action buttons (overview)
  document.querySelectorAll('[data-goto-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelector(`[data-tab="${btn.dataset.gotoTab}"]`)?.click();
    });
  });

  // My Proposals: Withdraw
  document.querySelectorAll('[data-withdraw-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      const msg = typeof window.t === 'function' ? window.t('confirm_withdraw') : 'Withdraw this proposal?';
      if (confirm(msg)) {
        btn.closest('.my-proposal-card').remove();
        showToast(typeof window.t === 'function' ? window.t('toast_request_withdrawn') : 'Proposal withdrawn', 'info');
      }
    });
  });

  // My Proposals: View Booking → Job Queue
  document.querySelectorAll('[data-goto-job-queue]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelector('[data-tab="job-queue"]')?.click();
    });
  });

  // Job Board: Send Proposal toggle
  document.querySelectorAll('[data-send-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.sendProposal;
      const area = document.getElementById(`proposal-area-${id}`);
      if (area) area.hidden = false;
      btn.hidden = true;
    });
  });

  // Job Board: Cancel Proposal
  document.querySelectorAll('[data-cancel-proposal]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.dataset.cancelProposal;
      const area = document.getElementById(`proposal-area-${id}`);
      if (area) area.hidden = true;
      const sendBtn = document.querySelector(`[data-send-proposal="${id}"]`);
      if (sendBtn) sendBtn.hidden = false;
    });
  });

  // Job Board: Submit Proposal form
  document.querySelectorAll('.proposal-form').forEach(form => {
    form.addEventListener('submit', e => {
      e.preventDefault();
      const jobId = form.dataset.for;
      const fd = new FormData(form);
      const proposal = {
        jobId, price: fd.get('price'), message: fd.get('message'),
        startDate: fd.get('startDate'), submittedAt: new Date().toISOString(),
      };
      const proposals = JSON.parse(localStorage.getItem('servio_my_proposals') || '[]');
      proposals.push(proposal);
      localStorage.setItem('servio_my_proposals', JSON.stringify(proposals));
      const area = document.getElementById(`proposal-area-${jobId}`);
      if (area) {
        area.innerHTML = '<span style="color:#065f46;font-weight:600">✓ ' + (typeof window.t === 'function' ? window.t('tech_submit_proposal') : 'Proposal Sent') + '</span>';
        area.hidden = false;
      }
      showToast(typeof window.t === 'function' ? window.t('toast_saved') : 'Proposal sent!', 'success');
    });
  });

  // Job Board: Filter
  document.getElementById('jbCategoryFilter')?.addEventListener('change', applyJbFilters);
  document.getElementById('jbAreaFilter')?.addEventListener('change', applyJbFilters);
  function applyJbFilters() {
    const cat = document.getElementById('jbCategoryFilter')?.value;
    const area = document.getElementById('jbAreaFilter')?.value;
    document.querySelectorAll('.jb-card').forEach(card => {
      card.classList.toggle('is-hidden',
        !!(cat && card.dataset.category !== cat) ||
        !!(area && card.dataset.area !== area));
    });
  }

  // GPS banner dismiss
  document.querySelectorAll('[data-dismissible] .banner-dismiss').forEach(btn => {
    btn.addEventListener('click', () => btn.closest('[data-dismissible]').remove());
  });

  // Liability: Pay Now — event delegation so it works even if button is
  // re-rendered, re-mounted, or attached after init. Survives DOM rewrites.
  const onPayLiabilityClick = (e) => {
    const btn = e.target.closest('#payLiabilityBtn, [data-pay-liability]');
    if (!btn) return;
    e.preventDefault();
    openSettleDebtModal({
      onSuccess: () => {
        _availableBalanceCache = { value: null, ts: 0 };
        populateStats();
        renderMyDebtsV2();
      },
      onError: (msg) => {
        try { showToast(msg, 'error'); } catch (_) { alert(msg); }
      },
    });
  };
  if (!document.__payLiabilityWired) {
    document.addEventListener('click', onPayLiabilityClick);
    document.__payLiabilityWired = true;
  }

  initBioSection();
  initSocialLinks();
  initServicesCatalog();
  initPricingForm();
  initPayoutSection();
}

/* ─────────────────────────────────────────────────────────────
   BIO / ABOUT ME
───────────────────────────────────────────────────────────── */
function initBioSection() {
  const textarea = document.getElementById('s-bio');
  const counter = document.getElementById('bio-char-count');
  const saveBtn = document.getElementById('btn-save-bio');
  const saveMsg = document.getElementById('bio-save-msg');
  if (!textarea) return;

  // Restore saved bio
  const account = getAccount() || {};
  if (account.bio) textarea.value = account.bio;
  if (counter) counter.textContent = textarea.value.length;

  textarea.addEventListener('input', () => {
    if (counter) counter.textContent = textarea.value.length;
  });

  saveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    acc.bio = textarea.value.trim();
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
  });
}

/* ─────────────────────────────────────────────────────────────
   SOCIAL & PORTFOLIO LINKS
───────────────────────────────────────────────────────────── */
function initSocialLinks() {
  const form = document.getElementById('social-links-form');
  if (!form) return;

  // Restore saved values (data-settings-field already handled in populateDashboard,
  // but social fields may not be wired there yet — handle explicitly)
  const account = getAccount() || {};
  ['facebook', 'instagram', 'portfolio'].forEach(key => {
    const el = document.getElementById('s-' + key);
    if (el && account[key]) el.value = account[key];
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const acc = getAccount() || {};
    ['facebook', 'instagram', 'portfolio'].forEach(key => {
      const el = document.getElementById('s-' + key);
      if (el) acc[key] = el.value.trim();
    });
    localStorage.setItem('servio_account', JSON.stringify(acc));
    const msg = document.getElementById('social-save-msg');
    if (msg) { msg.hidden = false; setTimeout(() => { msg.hidden = true; }, 2500); }
  });
}

/* ─────────────────────────────────────────────────────────────
   SERVICES CATALOG
───────────────────────────────────────────────────────────── */
const CATEGORY_LABELS = {
  plumbing: 'Plumbing',
  electrical: 'Electrical',
  hvac: 'A/C & HVAC',
  carpentry: 'Carpentry',
  appliance: 'Appliances',
  handyman: 'Handyman',
  renovation: 'Renovation',
  painting: 'Painting',
  flooring: 'Flooring',
  drywall: 'Drywall',
  roofing: 'Roofing',
  cleaning: 'Cleaning',
  'pest-control': 'Pest Control',
  landscaping: 'Landscaping',
  installation: 'Installation',
  other: 'Other',
};

const CATEGORY_ICONS = {
  plumbing: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 16.3c2.2 0 4-1.83 4-4.05 0-1.16-.57-2.26-1.71-3.19S7.29 6.75 7 5.3c-.29 1.45-1.14 2.84-2.29 3.76S3 11.1 3 12.25c0 2.22 1.8 4.05 4 4.05z"/><path d="M12.56 6.6A10.97 10.97 0 0 0 14 3.02c.5 2.5 2 4.9 4 6.5s3 3.5 3 5.5a6.98 6.98 0 0 1-11.91 4.97"/></svg>',
  electrical: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/></svg>',
  hvac: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 12h20"/><path d="M12 2v20"/><path d="m20 16-4-4 4-4"/><path d="m4 8 4 4-4 4"/><path d="m16 4-4 4-4-4"/><path d="m8 20 4-4 4 4"/></svg>',
  carpentry: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m15 12-8.373 8.373a1 1 0 1 1-3-3L12 9"/><path d="m18 15 4-4"/><path d="m21.5 11.5-1.914-1.914A2 2 0 0 1 19 8.172V7l-2.26-2.26a6 6 0 0 0-4.202-1.756L9 2.96l.92.82A6.18 6.18 0 0 1 12 8.4V10l2 2h1.172a2 2 0 0 1 1.414.586L18 14"/></svg>',
  appliance: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect width="20" height="15" x="2" y="4" rx="2"/><path d="M8 4v15M16 4v15M2 9h20M2 14h20"/></svg>',
  handyman: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>',
  renovation: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
  painting: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>',
  flooring: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/></svg>',
  drywall: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="2" y="3" width="20" height="18" rx="2"/><path d="M2 9h20M2 15h20M8 3v6M16 3v6M8 15v6M16 15v6"/></svg>',
  roofing: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 9l9-7 9 7"/><path d="M3 9v13h18V9"/><path d="M9 22V12h6v10"/></svg>',
  cleaning: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4.5 8-11.8A8 8 0 0 0 12 2a8 8 0 0 0-8 8.2c0 7.3 8 11.8 8 11.8z"/><circle cx="12" cy="10" r="3"/></svg>',
  'pest-control': '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 12h8M12 8v8"/><circle cx="12" cy="12" r="9"/><path d="M4.93 4.93l14.14 14.14"/></svg>',
  landscaping: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22v-7l-2-2"/><path d="M17 8v.8A6 6 0 0 1 13.8 20v0H10v0A6.5 6.5 0 0 1 7 8h0a5 5 0 0 1 10 0z"/><path d="m14 14-2 2-2-2"/></svg>',
  installation: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/></svg>',
  other: '<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>',
};

async function initServicesCatalog() {
  const catalog = document.getElementById('services-catalog');
  const saveBtn = document.getElementById('btn-save-skills');
  const saveMsg = document.getElementById('skills-save-msg');
  if (!catalog) return;

  let allServices = [];
  let selectedIds = new Set();
  let verifiedCats = [];
  let pendingCats = [];

  try {
    const [svcRes, meRes] = await Promise.all([
      getServices({ limit: 200 }),
      getMe(),
    ]);
    allServices = svcRes.data?.services || svcRes.services || svcRes.data || [];
    const me = meRes.data || meRes;
    verifiedCats = me.categories || [];
    pendingCats = me.pendingCategories || [];

    const workerServices = me.services || [];
    workerServices.forEach(s => selectedIds.add((s._id || s).toString()));

    const skills = me.skills || [];
    const certEl = document.getElementById('s-certifications');
    if (certEl && skills.length) certEl.value = skills.join('\n');
  } catch (e) {
    catalog.innerHTML = '<p style="color:#e74c3c;font-size:0.875rem;">Failed to load services. Please refresh.</p>';
    return;
  }

  if (!allServices.length) {
    catalog.innerHTML = '<p style="color:var(--color-secondary,#9A8C73);font-size:0.875rem;">No services found. Ask an admin to seed the service catalog.</p>';
    return;
  }

  const grouped = {};
  allServices.forEach(svc => {
    const cat = svc.category || 'other';
    if (!grouped[cat]) grouped[cat] = [];
    grouped[cat].push(svc);
  });

  const formatPrice = svc => {
    if (svc.priceUnit === 'per_hour') return `${svc.basePrice} EGP/hr`;
    if (svc.priceUnit === 'per_sqm') return `${svc.basePrice} EGP/m²`;
    return `${svc.basePrice} EGP`;
  };

  const catBadge = cat => {
    if (verifiedCats.includes(cat)) return '<span class="svc-cat-badge svc-cat-badge--verified">Verified</span>';
    if (pendingCats.includes(cat)) return '<span class="svc-cat-badge svc-cat-badge--pending">Pending</span>';
    return '<span class="svc-cat-badge svc-cat-badge--new">Re-verify</span>';
  };

  const entries = Object.entries(grouped);
  catalog.innerHTML = `<div class="svc-accordion">${entries.map(([cat, services], idx) => {
    const selCount = services.filter(s => selectedIds.has((s._id || s.id || '').toString())).length;
    const open = selCount > 0;
    const isLastOdd = idx === entries.length - 1 && entries.length % 2 !== 0;
    const icon = CATEGORY_ICONS[cat] || '';
    return `<div class="svc-acc-item${open ? ' is-open' : ''}${isLastOdd ? ' svc-acc-item--full' : ''}" data-cat="${cat}">
      <button class="svc-acc-toggle" type="button" aria-expanded="${open}">
        <span class="svc-acc-toggle__name">${icon}${CATEGORY_LABELS[cat] || cat}${catBadge(cat)}</span>
        <span class="svc-acc-toggle__meta">
          <span class="svc-sel-count"${selCount === 0 ? ' hidden' : ''}>${selCount} selected</span>
          <svg class="svc-acc-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>
        </span>
      </button>
      <div class="svc-acc-body"${open ? '' : ' hidden'}>
        <div class="svc-pill-grid">${services.map(svc => {
      const id = (svc._id || svc.id || '').toString();
      const chk = selectedIds.has(id);
      return `<label class="svc-pill${chk ? ' is-checked' : ''}">
            <input type="checkbox" class="svc-checkbox" value="${id}" data-category="${svc.category || ''}" ${chk ? 'checked' : ''} />
            <svg class="svc-pill__check-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>
            <span class="svc-pill__name">${svc.title}</span>
            <span class="svc-pill__price">${formatPrice(svc)}</span>
          </label>`;
    }).join('')}</div>
      </div>
    </div>`;
  }).join('')}</div>`;

  catalog.querySelectorAll('.svc-acc-toggle').forEach(btn => {
    btn.addEventListener('click', () => {
      const item = btn.closest('.svc-acc-item');
      const body = item.querySelector('.svc-acc-body');
      const open = item.classList.toggle('is-open');
      btn.setAttribute('aria-expanded', String(open));
      body.hidden = !open;
    });
  });

  catalog.querySelectorAll('.svc-pill').forEach(pill => {
    const cb = pill.querySelector('.svc-checkbox');
    cb.addEventListener('change', () => {
      pill.classList.toggle('is-checked', cb.checked);
      const item = pill.closest('.svc-acc-item');
      const countEl = item.querySelector('.svc-sel-count');
      const n = item.querySelectorAll('.svc-checkbox:checked').length;
      if (countEl) { countEl.textContent = n + ' selected'; countEl.hidden = n === 0; }
    });
  });

  saveBtn?.addEventListener('click', async () => {
    const checkedIds = [...catalog.querySelectorAll('.svc-checkbox:checked')].map(cb => cb.value);
    const checkedCats = [...new Set([...catalog.querySelectorAll('.svc-checkbox:checked')].map(cb => cb.dataset.category).filter(Boolean))];
    const certEl = document.getElementById('s-certifications');
    const skills = certEl ? certEl.value.trim().split('\n').map(s => s.trim()).filter(Boolean) : [];

    try {
      await updateMe({ services: checkedIds, skills });
      const newCats = checkedCats.filter(c => !verifiedCats.includes(c));
      if (newCats.length) {
        const labels = newCats.map(c => CATEGORY_LABELS[c] || c).join(', ');
        showToast(`Services saved. ${labels}: pending admin review before appearing live.`, 'info');
        pendingCats = [...new Set([...pendingCats, ...newCats])];
        catalog.querySelectorAll('.svc-cat-header').forEach(h => {
          const cat = Object.keys(CATEGORY_LABELS).find(k => h.textContent.includes(CATEGORY_LABELS[k]));
          if (cat && newCats.includes(cat)) {
            const badge = h.querySelector('.svc-cat-badge');
            if (badge) { badge.textContent = 'Pending Admin Approval'; badge.className = 'svc-cat-badge svc-cat-badge--pending'; }
          }
        });
      } else if (saveMsg) {
        saveMsg.hidden = false;
        setTimeout(() => { saveMsg.hidden = true; }, 2500);
      }
    } catch (e) {
      showToast('Failed to save services. Please try again.', 'error');
    }
  });
}

/* ─────────────────────────────────────────────────────────────
   SERVICE PRICING FORM
───────────────────────────────────────────────────────────── */
function initPricingForm() {
  const form = document.getElementById('pricing-form');
  const saveMsg = document.getElementById('pricing-save-msg');
  if (!form) return;

  const account = getAccount() || {};
  // Restore numeric fields
  ['minFee', 'travelFee', 'emergencyMultiplier'].forEach(key => {
    const el = document.getElementById('s-' + key.replace(/([A-Z])/g, c => '-' + c.toLowerCase()));
    if (el && account[key] != null) el.value = account[key];
  });
  // Restore checkboxes
  ['acceptCash', 'acceptCard', 'acceptInstapay', 'acceptWallet'].forEach(key => {
    const el = form.querySelector(`[name="${key}"]`);
    if (el) el.checked = !!account[key];
  });

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const acc = getAccount() || {};
    acc.minFee = parseFloat(document.getElementById('s-min-fee')?.value) || 0;
    acc.travelFee = parseFloat(document.getElementById('s-travel-fee')?.value) || 0;
    acc.emergencyMultiplier = parseFloat(document.getElementById('s-emergency-mult')?.value) || 1;
    ['acceptCash', 'acceptCard', 'acceptInstapay', 'acceptWallet'].forEach(key => {
      const el = form.querySelector(`[name="${key}"]`);
      if (el) acc[key] = el.checked;
    });
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
  });
}

/* ─────────────────────────────────────────────────────────────
   PAYOUT SECTION
───────────────────────────────────────────────────────────── */
function initPayoutSection() {
  const methodCards = document.getElementById('payout-method-cards');
  const bankFields = document.getElementById('payout-fields-bank');
  const walletFields = document.getElementById('payout-fields-wallet');
  const saveBtn = document.getElementById('btn-save-payout');
  const saveMsg = document.getElementById('payout-save-msg');
  const scheduleOpts = document.getElementById('payout-schedule-options');
  const schedSaveBtn = document.getElementById('btn-save-schedule');
  const schedSaveMsg = document.getElementById('schedule-save-msg');

  if (!methodCards) return;

  const account = getAccount() || {};

  // Restore saved method
  const currentMethod = account.payoutMethod || 'bank';
  setPayoutMethod(currentMethod);

  // Restore bank / wallet field values
  if (account.bankName) {
    const sel = document.getElementById('s-bank-name');
    if (sel) sel.value = account.bankName;
  }
  if (account.accountHolder) {
    const el = document.getElementById('s-account-holder');
    if (el) el.value = account.accountHolder;
  }
  if (account.accountNumber) {
    const el = document.getElementById('s-account-number');
    if (el) el.value = account.accountNumber;
  }
  if (account.walletNumber) {
    const el = document.getElementById('s-wallet-number');
    if (el) el.value = account.walletNumber;
  }

  // Restore schedule
  if (account.payoutSchedule && scheduleOpts) {
    const radio = scheduleOpts.querySelector(`[value="${account.payoutSchedule}"]`);
    if (radio) radio.checked = true;
  }

  methodCards.addEventListener('click', (e) => {
    const card = e.target.closest('.payout-method-card');
    if (!card) return;
    setPayoutMethod(card.dataset.payoutMethod);
  });

  function setPayoutMethod(method) {
    methodCards.querySelectorAll('.payout-method-card').forEach(c => {
      const active = c.dataset.payoutMethod === method;
      c.classList.toggle('payout-method-card--active', active);
      c.setAttribute('aria-checked', String(active));
    });
    const isBank = method === 'bank';
    if (bankFields) bankFields.hidden = !isBank;
    if (walletFields) walletFields.hidden = isBank;
  }

  saveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    const activeCard = methodCards.querySelector('.payout-method-card--active');
    acc.payoutMethod = activeCard?.dataset.payoutMethod || 'bank';
    acc.bankName = document.getElementById('s-bank-name')?.value || '';
    acc.accountHolder = document.getElementById('s-account-holder')?.value.trim() || '';
    acc.accountNumber = document.getElementById('s-account-number')?.value.trim() || '';
    acc.walletNumber = document.getElementById('s-wallet-number')?.value.trim() || '';
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (saveMsg) { saveMsg.hidden = false; setTimeout(() => { saveMsg.hidden = true; }, 2500); }
  });

  schedSaveBtn?.addEventListener('click', () => {
    const acc = getAccount() || {};
    const checked = scheduleOpts?.querySelector('[name="payoutSchedule"]:checked');
    if (checked) acc.payoutSchedule = checked.value;
    localStorage.setItem('servio_account', JSON.stringify(acc));
    if (schedSaveMsg) { schedSaveMsg.hidden = false; setTimeout(() => { schedSaveMsg.hidden = true; }, 2500); }
  });
}

function updateActionNeededDates() {
  const _t = k => (typeof window.t === 'function' ? window.t(k) : k);
  document.querySelectorAll('.dash-action-card').forEach(card => {
    const statusEl = card.querySelector('.dash-action-card__status');
    const dateEl = card.querySelector('.dash-action-card__date');
    if (statusEl && statusEl.textContent.trim() === 'Action needed') {
      statusEl.textContent = _t('tech_action_needed');
    }
    if (statusEl && statusEl.textContent.trim() === 'Awaiting review') {
      statusEl.textContent = _t('tech_stat_awaiting_review');
    }
    if (dateEl && dateEl.textContent.includes('Due')) {
      const dateStr = dateEl.textContent.replace('Due ', '').trim();
      dateEl.textContent = _t('tech_stat_due_date').replace('{date}', dateStr);
    }
  });
}

/* ── Profile read-only / edit mode ────────────────────────── */
function initProfileReadOnly() {
  const form = document.querySelector('[data-readonly-form]');
  const editBtn = document.getElementById('btn-edit-profile');
  const cancelBtn = document.getElementById('btn-cancel-profile');
  const actionsRow = document.getElementById('profile-edit-actions');
  if (!form || !editBtn) return;

  // Snapshot values so Cancel can restore them
  let _snapshot = {};

  function getEditableInputs() {
    return [...form.querySelectorAll('input:not([type="file"]):not([id="s-email"]), textarea')];
  }

  function enableEdit() {
    _snapshot = {};
    getEditableInputs().forEach(el => {
      _snapshot[el.id || el.name] = el.value;
      el.removeAttribute('readonly');
    });
    if (actionsRow) actionsRow.style.display = 'flex';
    editBtn.style.display = 'none';
  }

  function disableEdit() {
    getEditableInputs().forEach(el => el.setAttribute('readonly', ''));
    if (actionsRow) actionsRow.style.display = 'none';
    editBtn.style.display = '';
  }

  editBtn.addEventListener('click', enableEdit);

  cancelBtn?.addEventListener('click', () => {
    getEditableInputs().forEach(el => {
      const key = el.id || el.name;
      if (key in _snapshot) el.value = _snapshot[key];
    });
    disableEdit();
  });

  // After a successful save, return to read-only
  form.addEventListener('submit', async () => {
    // Small delay so the submit handler runs first
    setTimeout(disableEdit, 100);
  }, { capture: true });
}

/* ── Email change modal ────────────────────────────────────── */
function initEmailChange() {
  const modal = document.getElementById('modal-change-email-tech');
  const openBtn = document.getElementById('btn-change-email-tech');
  const closeBtn = document.getElementById('btn-close-change-email-tech');
  const cancelBtn = document.getElementById('btn-change-email-tech-cancel');
  const form = document.getElementById('change-email-tech-form');
  const newEmailEl = document.getElementById('change-email-tech-new');
  const pwEl = document.getElementById('change-email-tech-password');
  const errorEl = document.getElementById('change-email-tech-error');
  const submitBtn = document.getElementById('btn-change-email-tech-confirm');
  if (!modal || !openBtn || !form) return;

  function openModal() { modal.removeAttribute('hidden'); newEmailEl?.focus(); }
  function closeModal() { modal.setAttribute('hidden', ''); form.reset(); if (errorEl) errorEl.hidden = true; }

  openBtn.addEventListener('click', openModal);
  closeBtn?.addEventListener('click', closeModal);
  cancelBtn?.addEventListener('click', closeModal);
  modal.addEventListener('click', e => { if (e.target === modal) closeModal(); });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (errorEl) errorEl.hidden = true;
    const newEmail = newEmailEl?.value?.trim();
    const currentPassword = pwEl?.value;
    if (!newEmail) { if (errorEl) { errorEl.textContent = 'Please enter a new email address.'; errorEl.hidden = false; } return; }
    if (!currentPassword) { if (errorEl) { errorEl.textContent = 'Please enter your current password.'; errorEl.hidden = false; } return; }
    if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = 'Updating…'; }
    try {
      await updateEmail({ newEmail, currentPassword });
      const sess = getSession();
      if (sess) { sess.email = newEmail; localStorage.setItem('servio_session', JSON.stringify(sess)); }
      const acc = getAccount() || {};
      acc.email = newEmail;
      localStorage.setItem('servio_account', JSON.stringify(acc));
      const emailInput = document.getElementById('s-email');
      if (emailInput) emailInput.value = newEmail;
      closeModal();
      showToast('Email updated successfully. Please log in again.', 'success');
      setTimeout(() => { localStorage.removeItem('servio_session'); window.location.href = './login.html'; }, 2000);
    } catch (err) {
      if (errorEl) { errorEl.textContent = err.message || 'Failed to update email.'; errorEl.hidden = false; }
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = 'Update Email'; }
    }
  });
}

/* ── Delete Account Modal ──────────────────────────────────── */
function initDeleteAccount() {
  const modal = document.getElementById('modal-delete-account');
  const cancelBtn = document.getElementById('btn-delete-account-cancel');
  const confirmBtn = document.getElementById('btn-delete-account-confirm');
  const inputEl = document.getElementById('delete-account-confirm-input');
  const errorEl = document.getElementById('delete-account-error');
  if (!modal || !confirmBtn) return;

  function closeModal() {
    modal.style.display = 'none';
    if (inputEl) inputEl.value = '';
    if (errorEl) { errorEl.textContent = ''; errorEl.hidden = true; }
    if (confirmBtn) { confirmBtn.disabled = true; confirmBtn.textContent = 'Delete My Account'; }
  }

  cancelBtn?.addEventListener('click', closeModal);
  document.getElementById('btn-delete-account-cancel-footer')?.addEventListener('click', closeModal);
  modal.addEventListener('click', e => { if (e.target === modal) closeModal(); });

  // Enable confirm button only when user types DELETE
  if (inputEl) {
    inputEl.addEventListener('input', () => {
      confirmBtn.disabled = inputEl.value.trim() !== 'DELETE';
    });
  }

  confirmBtn.addEventListener('click', async () => {
    if (inputEl && inputEl.value.trim() !== 'DELETE') return;
    confirmBtn.disabled = true;
    confirmBtn.textContent = 'Deleting…';
    if (errorEl) { errorEl.hidden = true; }
    try {
      await deleteMe();
      // Wipe all local data and redirect to home
      localStorage.clear();
      window.location.href = './index.html';
    } catch (err) {
      if (errorEl) {
        errorEl.textContent = err.message || 'Failed to delete account. Please try again.';
        errorEl.hidden = false;
      }
      confirmBtn.disabled = false;
      confirmBtn.textContent = 'Delete My Account';
    }
  });
}

// Initial update for dates
updateActionNeededDates();
initProfileReadOnly();
initEmailChange();
initDeleteAccount();

// Re-run on language change
document.addEventListener('langchange', updateActionNeededDates);


/* ═══════════════════════════════════════════════════════════
   Disputes panel
   ═══════════════════════════════════════════════════════════ */

const TECH_DISP_STATE = {
  filter: 'all',
  disputes: [],
  loading: false,
  currentId: null,
};

function escapeHtmlDisp(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function fmtDateTimeDisp(value) {
  if (!value) return '—';
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
}

function fmtMoneyDisp(amount, currency = 'EGP') {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '—';
  const cur = String(currency || 'EGP').toUpperCase();
  return `${n.toLocaleString(undefined, { maximumFractionDigits: 2 })}\u00A0${cur}`;
}

function categoryIconDisp(cat) {
  const c = String(cat || '').toLowerCase();
  if (c.includes('plumb')) return '<path d="M3 8h6a2 2 0 0 1 2 2v4a2 2 0 0 0 2 2h8"/><path d="M9 3v5"/><path d="M19 12v9"/>';
  if (c.includes('electric')) return '<polyline points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>';
  if (c.includes('ac') || c.includes('hvac') || c.includes('cool')) return '<circle cx="12" cy="12" r="3"/><line x1="12" y1="2" x2="12" y2="9"/><line x1="12" y1="15" x2="12" y2="22"/><line x1="2" y1="12" x2="9" y2="12"/><line x1="15" y1="12" x2="22" y2="12"/>';
  if (c.includes('paint')) return '<path d="M19 11h2v2a2 2 0 0 1-2 2h-1l-1 7H7l-1-7H3v-2h2V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v6z"/>';
  if (c.includes('carpent')) return '<path d="M14 3l7 7-3 3-7-7 3-3z"/><path d="M11 6l-8 8v7h7l8-8"/>';
  if (c.includes('clean')) return '<path d="M9 3h6v4H9z"/><path d="M5 7h14l-1 14H6L5 7z"/>';
  return '<path d="M12 2 2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/>';
}

function svgIconDisp(paths, size = 16) {
  return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;
}

function getCustomerInitial(d) {
  const name = getCustomerName(d) || '?';
  return String(name).trim().charAt(0).toUpperCase() || '?';
}

function statusLabelDisp(s) {
  return ({
    open: 'Open',
    reviewing: 'Reviewing',
    awaiting_evidence: 'Awaiting Evidence',
    resolved_refund: 'Refunded',
    resolved_release: 'Payment Released',
    resolved_partial: 'Partial Refund',
    resolved_redo: 'Redo Required',
    appealed: 'Appealed',
    closed: 'Closed',
  })[s] || (s || '').replace(/_/g, ' ');
}

function statusClassDisp(s) {
  if (s === 'open') return 'is-open';
  if (s === 'reviewing') return 'is-reviewing';
  if (s === 'awaiting_evidence') return 'is-action';
  if (s === 'appealed') return 'is-appealed';
  if (s && s.startsWith('resolved')) return 'is-resolved';
  return '';
}

function decisionLabelDisp(d) {
  return ({
    refund: 'Full refund to customer',
    release: 'Payment released to you',
    partial_refund: 'Partial refund issued',
    redo: 'You must redo the job',
  })[d] || (d || '—');
}

function isActionableForTech(d) {
  if (!d) return false;
  if (d.status === 'awaiting_evidence' && (d.evidenceRequestedFrom === 'worker' || d.evidenceRequestedFrom === 'both')) return true;
  return false;
}

function recalcTechDispStats() {
  const list = TECH_DISP_STATE.disputes;
  const counts = { open: 0, action: 0, resolved: 0, total: list.length };
  list.forEach(d => {
    if (['open', 'reviewing', 'awaiting_evidence'].includes(d.status)) counts.open += 1;
    if (isActionableForTech(d)) counts.action += 1;
    if (String(d.status || '').startsWith('resolved') || d.status === 'closed') counts.resolved += 1;
  });
  document.querySelectorAll('[data-disp-stat]').forEach(el => {
    const k = el.dataset.dispStat;
    if (counts[k] != null) el.textContent = String(counts[k]);
  });
  setNavBadge('disputes', counts.action);
}

function getCustomerName(d) {
  return d?.booking?.user?.name || d?.booking?.user?.fullName || 'Customer';
}

function getServiceName(d) {
  return d?.booking?.service?.title || d?.booking?.serviceCategory || 'Service';
}

function renderTechDisputeCard(d) {
  const status = d.status || 'open';
  const sClass = statusClassDisp(status);
  const customerName = escapeHtmlDisp(getCustomerName(d));
  const customerInitial = escapeHtmlDisp(getCustomerInitial(d));
  const service = escapeHtmlDisp(getServiceName(d));
  const opened = fmtDateTimeDisp(d.createdAt);
  const amt = d.payment?.amount ?? d.booking?.estimatedTotal ?? d.booking?.totalPrice;
  const actionable = isActionableForTech(d);
  const isResolved = String(status).startsWith('resolved') || status === 'closed';
  const decision = (isResolved && d.decision)
    ? `<div class="tdisp-card__decision"><span class="tdisp-card__decision-label">Decision</span><span class="tdisp-card__decision-value">${escapeHtmlDisp(decisionLabelDisp(d.decision))}${d.refundAmount ? ` · ${fmtMoneyDisp(d.refundAmount, d.payment?.currency)}` : ''}</span></div>`
    : '';
  const reason = d.reason
    ? `<div class="tdisp-card__quote">${svgIconDisp('<path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V20c0 1 0 1 1 1z"/><path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z"/>', 14)}<p>${escapeHtmlDisp(d.reason).slice(0, 200)}${d.reason.length > 200 ? '…' : ''}</p></div>`
    : '';
  const sevClass = ['low', 'medium', 'high', 'critical'].includes(d.severity) ? `is-sev-${d.severity}` : '';

  return `
    <article class="tdisp-card ${actionable ? 'is-actionable' : ''} ${sClass} ${sevClass}" data-disp-card="${escapeHtmlDisp(d._id)}" tabindex="0" role="button" data-disp-open="${escapeHtmlDisp(d._id)}">
      <div class="tdisp-card__stripe" aria-hidden="true"></div>
      <header class="tdisp-card__head">
        <div class="tdisp-card__avatar" aria-hidden="true">${customerInitial}</div>
        <div class="tdisp-card__head-text">
          <h3 class="tdisp-card__title">${service}</h3>
          <p class="tdisp-card__customer"><span class="tdisp-card__customer-name">${customerName}</span> <span class="tdisp-card__dot">·</span> <span class="tdisp-card__when">${escapeHtmlDisp(opened)}</span></p>
        </div>
        ${amt != null ? `<div class="tdisp-card__amount" title="Job total"><span class="tdisp-card__amount-label">Job total</span><span class="tdisp-card__amount-value">${fmtMoneyDisp(amt, d.payment?.currency)}</span></div>` : ''}
      </header>
      <div class="tdisp-card__body">
        <div class="tdisp-card__badges">
          <span class="tdisp-status ${sClass}">${escapeHtmlDisp(statusLabelDisp(status))}</span>
          ${actionable ? `<span class="tdisp-action-pill">${svgIconDisp('<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>', 12)} Action required</span>` : ''}
          ${d.category ? `<span class="tdisp-category">${escapeHtmlDisp(String(d.category).replace(/_/g, ' '))}</span>` : ''}
        </div>
        ${reason}
        ${decision}
      </div>
      <footer class="tdisp-card__foot">
        <span class="tdisp-card__id">#${escapeHtmlDisp(String(d._id || '').slice(-6))}</span>
        <button type="button" class="tdisp-card__cta" data-disp-open="${escapeHtmlDisp(d._id)}">
          <span>${actionable ? 'Respond now' : 'View details'}</span>
          ${svgIconDisp('<polyline points="9 18 15 12 9 6"/>', 14)}
        </button>
      </footer>
    </article>
  `;
}

function renderTechDisputesList() {
  const root = document.getElementById('techDisputesList');
  if (!root) return;
  const filter = TECH_DISP_STATE.filter;
  const list = TECH_DISP_STATE.disputes.filter(d => {
    if (filter === 'all') return true;
    if (filter === 'resolved') return String(d.status || '').startsWith('resolved') || d.status === 'closed';
    return d.status === filter;
  });

  if (!list.length) {
    root.innerHTML = `
      <div class="tdisp-empty">
        <div class="tdisp-empty__icon">
          <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="10"/>
          </svg>
        </div>
        <h3 class="tdisp-empty__title">${filter === 'all' ? 'No disputes yet' : 'Nothing to show here'}</h3>
        <p class="tdisp-empty__desc">${filter === 'all' ? 'When a customer disputes one of your jobs, it will show up here.' : 'Try a different filter to see more disputes.'}</p>
      </div>`;
    return;
  }
  root.innerHTML = list.map(renderTechDisputeCard).join('');
  root.querySelectorAll('[data-disp-open]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      openTechDisputeModal(btn.dataset.dispOpen);
    });
  });
  root.querySelectorAll('.tdisp-card').forEach(card => {
    card.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        openTechDisputeModal(card.dataset.dispCard);
      }
    });
  });
}

async function loadTechDisputes() {
  const root = document.getElementById('techDisputesList');
  if (!root) return;
  if (TECH_DISP_STATE.loading) return;
  TECH_DISP_STATE.loading = true;
  root.innerHTML = `<div aria-busy="true">${skCardGrid(3, { wide: true })}</div>`;
  try {
    const res = await getWorkerDisputes({ limit: 100 });
    const payload = res?.data || res;
    TECH_DISP_STATE.disputes = Array.isArray(payload?.disputes) ? payload.disputes : [];
    recalcTechDispStats();
    renderTechDisputesList();
  } catch (err) {
    root.innerHTML = `
      <div class="tdisp-empty tdisp-empty--error">
        <div class="tdisp-empty__icon">
          <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
        </div>
        <h3 class="tdisp-empty__title">Failed to load disputes</h3>
        <p class="tdisp-empty__desc">${escapeHtmlDisp(err?.message || 'Network error')}</p>
      </div>`;
  } finally {
    TECH_DISP_STATE.loading = false;
  }
}

function initTechDisputesFilters() {
  const filterRoot = document.querySelector('[data-disp-filter]')?.parentElement;
  if (filterRoot) {
    filterRoot.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-disp-filter]');
      if (!btn) return;
      filterRoot.querySelectorAll('[data-disp-filter]').forEach(b => b.classList.toggle('is-active', b === btn));
      TECH_DISP_STATE.filter = btn.dataset.dispFilter;
      renderTechDisputesList();
    });
  }
  document.getElementById('techDispRefresh')?.addEventListener('click', () => loadTechDisputes());
  document.querySelectorAll('#techDisputeModal [data-tdisp-close]').forEach(el => {
    el.addEventListener('click', closeTechDisputeModal);
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const m = document.getElementById('techDisputeModal');
      if (m && !m.hidden) closeTechDisputeModal();
    }
  });
}

function closeTechDisputeModal() {
  const m = document.getElementById('techDisputeModal');
  if (!m) return;
  m.hidden = true;
  m.setAttribute('aria-hidden', 'true');
  TECH_DISP_STATE.currentId = null;
}

async function openTechDisputeModal(disputeId) {
  if (!disputeId) return;
  const m = document.getElementById('techDisputeModal');
  const body = document.getElementById('techDisputeModalBody');
  const sub = document.getElementById('techDisputeModalSub');
  if (!m || !body) return;
  TECH_DISP_STATE.currentId = disputeId;
  m.hidden = false;
  m.setAttribute('aria-hidden', 'false');
  body.innerHTML = '<div class="tech-disp-empty">Loading…</div>';
  if (sub) sub.textContent = `#${String(disputeId).slice(-8)}`;

  try {
    const res = await getPartyDisputeById(disputeId);
    const dispute = res?.data || res;
    renderTechDisputeModal(dispute);
  } catch (err) {
    body.innerHTML = `<div class="tech-disp-empty tech-disp-empty--error">Failed to load dispute: ${escapeHtmlDisp(err?.message || 'Error')}</div>`;
  }
}

function renderEvidenceCardDisp(item) {
  const url = item?.url || '';
  if (!url) return '';
  const role = item?.uploadedByRole || 'unknown';
  const name = escapeHtmlDisp(item?.uploadedBy?.name || role);
  const when = fmtDateTimeDisp(item?.uploadedAt);
  const mime = String(item?.mime || '').toLowerCase();
  const isImg = mime.startsWith('image/') || /\.(png|jpe?g|gif|webp|svg)$/i.test(url);
  const preview = isImg
    ? `<img src="${escapeHtmlDisp(url)}" alt="evidence" onerror="this.replaceWith(Object.assign(document.createElement('div'),{className:'tech-disp-evidence-fallback',textContent:'File'}))" />`
    : `<div class="tech-disp-evidence-fallback">File</div>`;
  return `
    <a class="tech-disp-evidence-item" href="${escapeHtmlDisp(url)}" target="_blank" rel="noopener">
      ${preview}
      <div class="tech-disp-evidence-meta">
        <span class="tech-disp-evidence-role tech-disp-evidence-role--${escapeHtmlDisp(role)}">${escapeHtmlDisp(role)}</span>
        <span class="tech-disp-evidence-by">${name}</span>
        <span class="tech-disp-evidence-at">${escapeHtmlDisp(when)}</span>
      </div>
    </a>
  `;
}

function renderHistoryItemDisp(h) {
  const statusRaw = h?.status || '';
  const status = escapeHtmlDisp(statusLabelDisp(statusRaw));
  const roleRaw = escapeHtmlDisp(h?.byRole || 'system');

  let roleFriendly = 'System';
  if (roleRaw === 'user') roleFriendly = 'Customer';
  else if (roleRaw === 'worker') roleFriendly = 'Technician (You)';
  else if (roleRaw === 'admin') roleFriendly = 'Support Admin';

  const who = h?.by?.name ? escapeHtmlDisp(h.by.name) : roleFriendly;
  const when = fmtDateTimeDisp(h?.at);
  const note = h?.note ? `<p class="tech-disp-hist__note">"${escapeHtmlDisp(h.note)}"</p>` : '';

  let actionDesc = `Status updated to ${status}`;
  if (statusRaw === 'open') actionDesc = 'Dispute opened';
  else if (statusRaw === 'reviewing') actionDesc = 'Review started';
  else if (statusRaw === 'awaiting_evidence') actionDesc = 'Requested evidence';
  else if (statusRaw === 'appealed') actionDesc = 'Decision appealed';
  else if (statusRaw.startsWith('resolved')) actionDesc = `Dispute resolved: ${status}`;
  else if (statusRaw === 'closed') actionDesc = 'Dispute closed';

  return `
    <li class="tech-disp-hist__item">
      <div class="tech-disp-hist__dot tech-disp-hist__dot--${roleRaw}"></div>
      <div class="tech-disp-hist__body">
        <div class="tech-disp-hist__row">
          <span class="tech-disp-hist__status">${actionDesc}</span>
          <span class="tech-disp-hist__when">${escapeHtmlDisp(when)}</span>
        </div>
        <div class="tech-disp-hist__by">By: <strong>${who}</strong> <span class="tech-disp-hist__role">(${roleFriendly})</span></div>
        ${note}
      </div>
    </li>
  `;
}

function renderTechDisputeModal(dispute) {
  const body = document.getElementById('techDisputeModalBody');
  const sub = document.getElementById('techDisputeModalSub');
  if (!body || !dispute) return;
  const status = dispute.status || 'open';
  const actionable = isActionableForTech(dispute);
  const customerName = escapeHtmlDisp(getCustomerName(dispute));
  const service = escapeHtmlDisp(getServiceName(dispute));
  const opened = fmtDateTimeDisp(dispute.createdAt);
  const amt = dispute.payment?.amount ?? dispute.booking?.estimatedTotal ?? dispute.booking?.totalPrice;
  const currency = dispute.payment?.currency || 'EGP';
  const decision = dispute.decision ? decisionLabelDisp(dispute.decision) : null;
  const customerEvidence = (dispute.evidence || []).filter(e => (e?.uploadedByRole || 'user') === 'user');
  const workerEvidence = (dispute.evidence || []).filter(e => e?.uploadedByRole === 'worker');
  const adminEvidence = (dispute.evidence || []).filter(e => e?.uploadedByRole === 'admin');
  const requestMsg = (dispute.status === 'awaiting_evidence' && (dispute.evidenceRequestedFrom === 'worker' || dispute.evidenceRequestedFrom === 'both'))
    ? `<div class="tech-disp-callout tech-disp-callout--warn">
         <strong>Admin requested more evidence from you.</strong>
         <p>Upload photos, receipts, or any proof that supports your work. Be specific — quality evidence helps your case.</p>
       </div>`
    : '';
  const appealBlock = dispute.appealStatus
    ? `<section class="tech-disp-section">
         <h4 class="tech-disp-section__title">Appeal</h4>
         <div class="tech-disp-appeal tech-disp-appeal--${escapeHtmlDisp(dispute.appealStatus)}">
           <div><strong>Status:</strong> ${escapeHtmlDisp(dispute.appealStatus)}</div>
           ${dispute.appealReason ? `<p>${escapeHtmlDisp(dispute.appealReason)}</p>` : ''}
           ${dispute.appealedAt ? `<small>Filed ${escapeHtmlDisp(fmtDateTimeDisp(dispute.appealedAt))}</small>` : ''}
         </div>
       </section>`
    : '';
  const canAppeal = ['resolved_refund', 'resolved_partial', 'resolved_redo'].includes(status) && !dispute.appealStatus;

  if (sub) sub.textContent = `${service} · #${String(dispute._id || '').slice(-8)}`;

  body.innerHTML = `
    <div class="tech-disp-detail">
      <header class="tech-disp-detail__head">
        <div>
          <div class="tech-disp-detail__head-row">
            <span class="tech-disp-status ${statusClassDisp(status)}">${escapeHtmlDisp(statusLabelDisp(status))}</span>
            ${actionable ? '<span class="tech-disp-action-pill">Action required</span>' : ''}
          </div>
          <h3 class="tech-disp-detail__service">${service}</h3>
          <div class="tech-disp-detail__meta">
            Filed by <strong>${customerName}</strong> · ${escapeHtmlDisp(opened)}
          </div>
        </div>
        <div class="tech-disp-detail__amount">
          <span class="tech-disp-detail__amount-label">Job total</span>
          <span class="tech-disp-detail__amount-value">${amt != null ? fmtMoneyDisp(amt, currency) : '—'}</span>
        </div>
      </header>

      ${requestMsg}

      <section class="tech-disp-section">
        <h4 class="tech-disp-section__title">Customer's complaint</h4>
        <div class="tech-disp-quote">
          ${dispute.category ? `<span class="tech-disp-category">${escapeHtmlDisp(dispute.category.replace(/_/g, ' '))}</span>` : ''}
          <p>${escapeHtmlDisp(dispute.reason || '—')}</p>
        </div>
      </section>

      ${decision ? `
        <section class="tech-disp-section">
          <h4 class="tech-disp-section__title">Admin Decision</h4>
          <div class="tech-disp-callout tech-disp-callout--${status.startsWith('resolved') ? 'ok' : 'warn'}">
            <strong>${escapeHtmlDisp(decision)}</strong>
            ${dispute.refundAmount ? `<div>Refund amount: ${fmtMoneyDisp(dispute.refundAmount, currency)}</div>` : ''}
            ${dispute.resolution ? `<p>${escapeHtmlDisp(dispute.resolution)}</p>` : ''}
            ${dispute.resolvedAt ? `<small>Resolved ${escapeHtmlDisp(fmtDateTimeDisp(dispute.resolvedAt))}</small>` : ''}
          </div>
        </section>
      ` : ''}

      ${appealBlock}

      <section class="tech-disp-section">
        <h4 class="tech-disp-section__title">Customer Evidence ${customerEvidence.length ? `(${customerEvidence.length})` : ''}</h4>
        ${customerEvidence.length
      ? `<div class="tech-disp-evidence-grid">${customerEvidence.map(renderEvidenceCardDisp).join('')}</div>`
      : '<p class="tech-disp-empty tech-disp-empty--inline">No customer evidence uploaded.</p>'}
      </section>

      <section class="tech-disp-section">
        <h4 class="tech-disp-section__title">Your Evidence ${workerEvidence.length ? `(${workerEvidence.length})` : ''}</h4>
        ${workerEvidence.length
      ? `<div class="tech-disp-evidence-grid">${workerEvidence.map(renderEvidenceCardDisp).join('')}</div>`
      : '<p class="tech-disp-empty tech-disp-empty--inline">You have not uploaded evidence yet.</p>'}

        ${!String(status || '').startsWith('resolved') && status !== 'closed' ? `
          <div class="tech-disp-upload">
            <input type="file" id="techDispEvidenceInput" multiple accept="image/jpeg,image/png,image/webp" hidden />
            <button type="button" class="btn btn--primary btn--sm" id="techDispUploadBtn">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
              Upload Evidence
            </button>
            <p class="tech-disp-upload__hint">JPG / PNG / WebP · up to 12 files total · 15 MB each</p>
            <div class="tech-disp-upload__status" id="techDispUploadStatus" hidden></div>
          </div>
        ` : ''}
      </section>

      ${adminEvidence.length ? `
        <section class="tech-disp-section">
          <h4 class="tech-disp-section__title">Admin Evidence (${adminEvidence.length})</h4>
          <div class="tech-disp-evidence-grid">${adminEvidence.map(renderEvidenceCardDisp).join('')}</div>
        </section>
      ` : ''}

      <section class="tech-disp-section">
        <h4 class="tech-disp-section__title">Timeline</h4>
        <ul class="tech-disp-hist">
          ${(dispute.history || []).slice().sort((a, b) => new Date(a.at) - new Date(b.at)).map(renderHistoryItemDisp).join('') || '<li class="tech-disp-empty tech-disp-empty--inline">No activity yet.</li>'}
        </ul>
      </section>

      ${canAppeal ? `
        <section class="tech-disp-section tech-disp-section--appeal">
          <h4 class="tech-disp-section__title">File an Appeal</h4>
          <p class="tech-disp-section__desc">If you believe the decision was wrong, you have 48 hours from resolution to appeal. Be specific — admins will re-review.</p>
          <textarea id="techDispAppealReason" class="tech-disp-textarea" rows="4" placeholder="Explain why this decision should be reconsidered (minimum 20 characters)…"></textarea>
          <button type="button" class="btn btn--danger-outline btn--sm" id="techDispAppealBtn">Submit Appeal</button>
        </section>
      ` : ''}
    </div>
  `;

  wireTechDisputeModalActions(dispute);
}

function wireTechDisputeModalActions(dispute) {
  const disputeId = dispute._id;
  const uploadBtn = document.getElementById('techDispUploadBtn');
  const fileInput = document.getElementById('techDispEvidenceInput');
  const statusEl = document.getElementById('techDispUploadStatus');

  if (uploadBtn && fileInput) {
    uploadBtn.addEventListener('click', () => fileInput.click());
    fileInput.addEventListener('change', async () => {
      const files = Array.from(fileInput.files || []);
      if (!files.length) return;
      uploadBtn.disabled = true;
      if (statusEl) {
        statusEl.hidden = false;
        statusEl.textContent = `Uploading ${files.length} file(s)…`;
        statusEl.classList.remove('is-error');
      }
      try {
        const uploaded = [];
        for (const f of files) {
          const meta = await uploadPublicFile(f, 'dispute');
          uploaded.push({
            url: meta?.url || meta?.secureUrl || meta?.publicUrl || meta,
            name: f.name,
            mime: f.type,
            size: f.size,
          });
        }
        await addDisputeEvidence(disputeId, uploaded);
        if (statusEl) { statusEl.textContent = 'Evidence uploaded successfully.'; statusEl.classList.remove('is-error'); }
        showToast?.('Evidence uploaded.', 'success');
        await refreshTechDisputeModal();
        loadTechDisputes().catch(() => { });
      } catch (err) {
        if (statusEl) { statusEl.textContent = `Upload failed: ${err?.message || 'Error'}`; statusEl.classList.add('is-error'); }
        showToast?.(err?.message || 'Upload failed.', 'error');
      } finally {
        uploadBtn.disabled = false;
        fileInput.value = '';
      }
    });
  }

  const appealBtn = document.getElementById('techDispAppealBtn');
  const reasonEl = document.getElementById('techDispAppealReason');
  if (appealBtn && reasonEl) {
    appealBtn.addEventListener('click', async () => {
      const reason = (reasonEl.value || '').trim();
      if (reason.length < 20) {
        showToast?.('Appeal reason must be at least 20 characters.', 'error');
        reasonEl.focus();
        return;
      }
      appealBtn.disabled = true;
      try {
        await appealDispute(disputeId, reason);
        showToast?.('Appeal submitted.', 'success');
        await refreshTechDisputeModal();
        loadTechDisputes().catch(() => { });
      } catch (err) {
        showToast?.(err?.message || 'Failed to submit appeal.', 'error');
      } finally {
        appealBtn.disabled = false;
      }
    });
  }
}

async function refreshTechDisputeModal() {
  const id = TECH_DISP_STATE.currentId;
  if (!id) return;
  try {
    const res = await getPartyDisputeById(id);
    const dispute = res?.data || res;
    renderTechDisputeModal(dispute);
  } catch { }
}

initTechDisputesFilters();

renderCachedTechStats();
initDashboard().catch(err => console.error('[Dashboard init error]', err));


/* ── Plan 2: earnings split + debt panel + payouts ──────────────────── */

const fmtMoney2 = (n) => moneyFmt.text(n);

function ageOf2(d) {
  if (!d) return '—';
  const h = Math.floor((Date.now() - new Date(d).getTime()) / 3600000);
  if (h < 1) return 'now';
  if (h < 24) return `${h}h`;
  return `${Math.floor(h / 24)}d`;
}

function relativeTime2(d) {
  if (!d) return '—';
  try { return new Date(d).toLocaleString(); } catch (_) { return '—'; }
}

function showEarningsError(message = "Couldn't load your earnings.") {
  const banner = document.getElementById('earnErrorBanner');
  const msg = document.getElementById('earnErrorBannerMsg');
  if (!banner) return;
  if (msg) msg.textContent = message;
  banner.hidden = false;
}
function hideEarningsError() {
  const banner = document.getElementById('earnErrorBanner');
  if (banner) banner.hidden = true;
}

async function renderMyDebtsV2() {
  const panel = document.getElementById('debtPanel');
  if (!panel) return;

  if (_debtsAbortController) _debtsAbortController.abort();
  _debtsAbortController = new AbortController();
  const signal = _debtsAbortController.signal;

  let r;
  try { r = await getMyDebtsV2({ signal }); }
  catch (e) {
    if (e.name === 'AbortError') return;
    console.error('[debts]', e);
    showEarningsError("Couldn't load your debt info. Check your connection.");
    return;
  }
  hideEarningsError();
  const { summary = {}, debts = [], submittedSettlements = [] } = r?.data || {};
  const total = Number(summary.totalOutstanding);
  const activeDebts = debts.filter(debt => ['outstanding', 'partially_paid'].includes(debt.status));
  const debtTab = document.getElementById('earnSubnavDebts');
  const debtBadge = document.getElementById('earnSubnavDebtsBadge');
  if (!Number.isFinite(total) || total <= 0) {
    panel.hidden = true;
    if (debtTab) debtTab.hidden = true;
    if (debtBadge) debtBadge.hidden = true;
    if (debtTab?.getAttribute('aria-selected') === 'true') activateEarnSubTab('overview');
    return;
  }
  panel.hidden = false;
  if (debtTab) debtTab.hidden = false;
  if (debtBadge) { debtBadge.hidden = false; debtBadge.textContent = String(activeDebts.length || 1); }
  const pct = Math.min(100, Math.round((total / 300) * 100));
  const labelEl = document.getElementById('debtProgressLabel');
  if (labelEl) labelEl.textContent = `${fmtMoney2(total)} owed — ${pct}% of cash-block threshold`;
  const bar = document.getElementById('debtProgressBar');
  if (bar) {
    bar.style.width = pct + '%';
    const sev = pct >= 100 ? 'blocked' : pct >= 80 ? 'warn' : '';
    bar.className = 'debt-progress__bar debt-meter__fill' + (sev ? ` debt-progress__bar--${sev} debt-meter__fill--${sev}` : '');
  }
  const tbody = document.getElementById('debtsTbody');
  if (tbody) {
    tbody.innerHTML = activeDebts.map(d => `
      <tr>
        <td>#${String(d.booking || '').toString().slice(-4)}</td>
        <td>${fmtMoney2(d.remaining ?? d.amount)}/${fmtMoney2(d.amount)}</td>
        <td>${ageOf2(d.createdAt)}</td>
        <td><span class="status-chip status-chip--${d.status}">${d.status}</span></td>
        <td>${d.settlementMethod || '—'}</td>
      </tr>`).join('') || '<tr><td colspan="5">No debts</td></tr>';
  }
  const stb = document.getElementById('settlementsTbody');
  if (stb) {
    stb.innerHTML = (submittedSettlements || []).map(s => `
      <tr>
        <td>${s.reference || '—'}</td>
        <td>${fmtMoney2(s.totalAmount)}</td>
        <td>${s.method}</td>
        <td><span class="status-chip status-chip--${s.status}">${s.status}</span></td>
        <td>${relativeTime2(s.createdAt)}</td>
      </tr>`).join('') || '<tr><td colspan="5">No settlements yet</td></tr>';
  }
}

let _allPayouts = [];
let _debtsAbortController = null;
let _payoutsAbortController = null;
let _availableBalanceCache = { value: null, ts: 0 };
const AVAILABLE_BALANCE_TTL_MS = 30_000;

async function getAvailableBalanceCached() {
  const now = Date.now();
  if (_availableBalanceCache.value !== null && now - _availableBalanceCache.ts < AVAILABLE_BALANCE_TTL_MS) {
    return _availableBalanceCache.value;
  }
  const r = await getWorkerEarnings();
  const value = Number(r?.breakdown?.availableToWithdraw ?? r?.wallet?.balance) || 0;
  _availableBalanceCache = { value, ts: now };
  return value;
}

const PAYOUT_METHOD_ICONS = {
  bank: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 21h18M5 21V10M19 21V10M3 10h18L12 3 3 10z"/><path d="M9 21v-6M15 21v-6"/></svg>',
  instapay: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2.5"/><path d="M11 18h2"/></svg>',
  vodafone: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></svg>',
  wallet: '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="6" width="20" height="14" rx="2.5"/><path d="M2 10h20M18 15h.01"/></svg>'
};

const PAYOUT_STATUS_GROUP = {
  pending: 'warn', processing: 'warn',
  paid: 'ok', completed: 'ok', approved: 'ok',
  rejected: 'bad', failed: 'bad', cancelled: 'bad'
};

function _methodLabel(m) {
  const map = { bank: 'Bank transfer', instapay: 'InstaPay', vodafone: 'Vodafone Cash', wallet: 'E-wallet' };
  return map[m] || (m ? m.charAt(0).toUpperCase() + m.slice(1) : '—');
}

function _renderPayoutRows(items) {
  const tbody = document.getElementById('payoutsTbody');
  if (!tbody) return;
  if (!items.length) {
    tbody.innerHTML = `
      <tr class="payouts-empty-row">
        <td colspan="5">
          <div class="payouts-empty">
            <div class="payouts-empty__icon">
              <svg viewBox="0 0 24 24" width="34" height="34" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h3"/></svg>
            </div>
            <h4 class="payouts-empty__title">No payouts yet</h4>
            <p class="payouts-empty__desc">When you request a withdrawal, every transfer will appear here with its reference and status.</p>
            <button type="button" class="atelier-link" id="payoutsEmptyCta">
              <span>Request your first payout</span>
              <span aria-hidden="true">&rarr;</span>
            </button>
          </div>
        </td>
      </tr>`;
    document.getElementById('payoutsEmptyCta')?.addEventListener('click', async () => {
      let availableBalance = 0;
      try {
        availableBalance = await getAvailableBalanceCached();
      } catch (_) { /* fall through with 0 */ }
      openPayoutRequestModal({
        availableBalance,
        onSuccess: () => {
          _availableBalanceCache = { value: null, ts: 0 };
          renderMyPayoutsV2();
        },
      });
    });
    return;
  }
  tbody.innerHTML = items.map(p => {
    const method = (p.payoutMethod || '').toLowerCase();
    const icon = PAYOUT_METHOD_ICONS[method] || PAYOUT_METHOD_ICONS.wallet;
    const status = (p.status || '').toLowerCase();
    const group = PAYOUT_STATUS_GROUP[status] || 'neutral';
    const dateStr = p.createdAt ? new Date(p.createdAt).toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
    const timeStr = p.createdAt ? new Date(p.createdAt).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : '';
    const ref = p.transactionRef || p.reference || '—';
    return `
      <tr>
        <td>
          <div class="payouts-cell-date">
            <strong>${dateStr}</strong>
            <span>${timeStr}</span>
          </div>
        </td>
        <td>
          <span class="payouts-method-badge">
            <span class="payouts-method-badge__icon">${icon}</span>
            <span>${_methodLabel(method)}</span>
          </span>
        </td>
        <td class="payouts-table__num"><strong>${fmtMoney2(p.amount)}</strong></td>
        <td><span class="payouts-status payouts-status--${group}">${status || '—'}</span></td>
        <td><code class="payouts-ref">${ref}</code></td>
      </tr>`;
  }).join('');
}

function _applyPayoutFilters() {
  const status = document.getElementById('payoutFilterStatus')?.value || '';
  const from = document.getElementById('payoutFilterFrom')?.value;
  const to = document.getElementById('payoutFilterTo')?.value;
  const fromTs = from ? new Date(from).getTime() : -Infinity;
  const toTs = to ? new Date(to).getTime() + 86400000 : Infinity;
  const filtered = _allPayouts.filter(p => {
    if (status && (p.status || '').toLowerCase() !== status) return false;
    const ts = new Date(p.createdAt).getTime();
    if (Number.isFinite(ts) && (ts < fromTs || ts > toTs)) return false;
    return true;
  });
  _renderPayoutRows(filtered);
}

function _renderPayoutsSummary() {
  const total = _allPayouts
    .filter(p => ['paid', 'completed', 'approved'].includes((p.status || '').toLowerCase()))
    .reduce((s, p) => s + (Number(p.amount) || 0), 0);
  const pending = _allPayouts.filter(p => ['pending', 'processing'].includes((p.status || '').toLowerCase())).length;
  const totalEl = document.getElementById('payoutsTotalAmount');
  const countEl = document.getElementById('payoutsTotalCount');
  const pendingEl = document.getElementById('payoutsPendingCount');
  if (totalEl) totalEl.textContent = total.toLocaleString('en-US', { maximumFractionDigits: 2 });
  if (countEl) countEl.textContent = _allPayouts.length;
  if (pendingEl) pendingEl.textContent = pending;
}

async function renderLegacyPayoutsV2() {
  const tbody = document.getElementById('payoutsTbody');
  if (!tbody) return;

  if (_payoutsAbortController) _payoutsAbortController.abort();
  _payoutsAbortController = new AbortController();
  const signal = _payoutsAbortController.signal;

  try {
    const r = await getMyPayouts({ signal });
    _allPayouts = r?.data || [];
    hideEarningsError();
  } catch (e) {
    if (e.name === 'AbortError') return;
    console.error('[payouts]', e);
    _allPayouts = [];
    showEarningsError("Couldn't load your payout history. Check your connection.");
    return;
  }
  _renderPayoutsSummary();
  _applyPayoutFilters();

  // Hide filters + summary chips when there is nothing to filter
  const hasItems = _allPayouts.length > 0;
  const filtersEl = document.getElementById('payoutsFilters');
  const summaryEl = document.getElementById('payoutsSummary');
  if (filtersEl) filtersEl.hidden = !hasItems;
  if (summaryEl) summaryEl.hidden = !hasItems;
}

const WALLET_HISTORY_PAGE_SIZE = 10;
const _walletHistoryState = { category: 'withdrawals', page: 1, total: 0 };
let _walletHistoryAbortController = null;

const WALLET_HISTORY_CONFIG = {
  withdrawals: {
    hint: 'Track every transfer requested from your Servio wallet.',
    columns: ['Date', 'Bank method', 'Amount', 'Status', 'Receipt'],
    statuses: [['', 'All statuses'], ['pending', 'Pending'], ['approved', 'Approved'], ['paid', 'Paid'], ['rejected', 'Rejected']],
    emptyTitle: 'No withdrawals yet',
    emptyDescription: 'When you request a bank transfer, its status and receipt will appear here.',
  },
  releases: {
    hint: 'See which online job payments are waiting and which reached your wallet.',
    columns: ['Job', 'Amount', 'Status', 'Waiting since', 'Released on'],
    statuses: [['', 'All statuses'], ['waiting_for_release', 'Waiting for release'], ['released', 'Released'], ['needs_review', 'Needs review'], ['reversed', 'Reversed (refund)']],
    emptyTitle: 'No release history yet',
    emptyDescription: 'Online job payments will appear here while they wait for release and after they reach your wallet.',
  },
  fees: {
    hint: 'Review platform fees already settled from completed cash jobs.',
    columns: ['Job', 'Fee amount', 'Payment method', 'Paid on'],
    statuses: [['paid', 'Paid']],
    emptyTitle: 'No paid fees yet',
    emptyDescription: 'Platform fees you settle from cash jobs will appear here.',
  },
};

function _walletHistoryDate(value) {
  if (!value) return 'â€”';
  return new Date(value).toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' });
}

function _walletHistoryStatusLabel(status) {
  const labels = {
    waiting_for_release: 'Waiting for release',
    needs_review: 'Needs review',
    approved: 'Approved',
    pending: 'Pending',
    paid: 'Paid',
    rejected: 'Rejected',
    released: 'Released',
    reversed: 'Reversed',
  };
  return labels[status] || String(status || 'â€”').replace(/_/g, ' ');
}

function _walletHistoryStatus(status) {
  const groups = {
    pending: 'warn',
    approved: 'warn',
    waiting_for_release: 'warn',
    paid: 'ok',
    released: 'ok',
    rejected: 'bad',
    needs_review: 'bad',
    reversed: 'bad',
  };
  return `<span class="payouts-status payouts-status--${groups[status] || 'neutral'}">${escapeHtml(_walletHistoryStatusLabel(status))}</span>`;
}

function _walletHistoryMethod(method) {
  const labels = {
    bank: 'Bank transfer',
    bank_transfer: 'Bank transfer',
    instapay: 'InstaPay',
    vodafone_cash: 'Vodafone Cash',
    orange_cash: 'Orange Cash',
    wallet_balance: 'Wallet balance',
    auto_offset: 'Automatic wallet offset',
    admin_override: 'Recorded by Servio',
  };
  return labels[method] || String(method || 'Recorded payment').replace(/_/g, ' ');
}

function _walletHistoryJob(item) {
  const id = escapeHtml(String(item.bookingId || '').slice(-6).toUpperCase());
  return `<div class="wallet-history__job"><strong>${escapeHtml(item.job || 'Service job')}</strong><span>#${id || 'â€”'}</span></div>`;
}

function _renderWalletHistoryHead() {
  const head = document.getElementById('walletHistoryHead');
  if (!head) return;
  const config = WALLET_HISTORY_CONFIG[_walletHistoryState.category];
  head.innerHTML = `<tr>${config.columns.map(column => `<th>${column}</th>`).join('')}</tr>`;
}

function _renderWalletHistoryLoading() {
  const tbody = document.getElementById('walletHistoryTbody');
  if (!tbody) return;
  _renderWalletHistoryHead();
  const summary = document.getElementById('walletHistorySummary');
  if (summary) { summary.hidden = true; summary.textContent = ''; }
  tbody.innerHTML = Array.from({ length: 4 }, () => `
    <tr class="wallet-history__skeleton" aria-hidden="true">
      <td colspan="5"><span class="skel-bar"></span></td>
    </tr>`).join('');
}

function _renderWalletHistoryEmpty() {
  const tbody = document.getElementById('walletHistoryTbody');
  if (!tbody) return;
  const config = WALLET_HISTORY_CONFIG[_walletHistoryState.category];
  const cta = _walletHistoryState.category === 'withdrawals'
    ? '<button type="button" class="atelier-link" id="payoutsEmptyCta"><span>Request a withdrawal</span><span aria-hidden="true">&rarr;</span></button>'
    : '';
  tbody.innerHTML = `
    <tr class="payouts-empty-row">
      <td colspan="5">
        <div class="payouts-empty">
          <div class="payouts-empty__icon">
            <svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M4 6h16M4 12h16M4 18h10"/></svg>
          </div>
          <h4 class="payouts-empty__title">${config.emptyTitle}</h4>
          <p class="payouts-empty__desc">${config.emptyDescription}</p>
          ${cta}
        </div>
      </td>
    </tr>`;
  document.getElementById('payoutsEmptyCta')?.addEventListener('click', async () => {
    let availableBalance = 0;
    try {
      availableBalance = await getAvailableBalanceCached();
    } catch (_) { /* fall through with 0 */ }
    openPayoutRequestModal({
      availableBalance,
      onSuccess: () => {
        _availableBalanceCache = { value: null, ts: 0 };
        renderWalletHistory({ resetPage: true });
      },
    });
  });
}

function _renderWalletHistoryRows(items) {
  const tbody = document.getElementById('walletHistoryTbody');
  if (!tbody) return;
  _renderWalletHistoryHead();
  if (!items.length) {
    _renderWalletHistoryEmpty();
    return;
  }

  if (_walletHistoryState.category === 'withdrawals') {
    tbody.innerHTML = items.map(item => `
      <tr>
        <td data-label="Date">${_walletHistoryDate(item.requestedAt)}</td>
        <td data-label="Bank method">${escapeHtml(_walletHistoryMethod(item.method))}</td>
        <td data-label="Amount" class="payouts-table__num"><strong>${fmtMoney2(item.amount)}</strong></td>
        <td data-label="Status">${_walletHistoryStatus(item.status)}</td>
        <td data-label="Receipt">${item.receipt ? `<code class="payouts-ref">${escapeHtml(item.receipt)}</code>` : '<span class="wallet-history__muted">Not issued yet</span>'}</td>
      </tr>`).join('');
    return;
  }

  if (_walletHistoryState.category === 'releases') {
    tbody.innerHTML = items.map(item => {
      const reversed = item.status === 'reversed';
      const amountValue = reversed ? -Math.abs(Number(item.amount) || 0) : Number(item.amount) || 0;
      const amountClass = reversed ? ' wallet-history__amount--neg' : '';
      const amountStr = reversed ? `−${fmtMoney2(Math.abs(amountValue))}` : fmtMoney2(amountValue);
      return `
      <tr>
        <td data-label="Job">${_walletHistoryJob(item)}</td>
        <td data-label="Amount"><strong class="wallet-history__amount${amountClass}">${amountStr}</strong></td>
        <td data-label="Status">${_walletHistoryStatus(item.status)}</td>
        <td data-label="Waiting since">${_walletHistoryDate(item.waitingSince)}</td>
        <td data-label="Released on">${_walletHistoryDate(item.releasedAt)}</td>
      </tr>`;
    }).join('');
    return;
  }

  tbody.innerHTML = items.map(item => `
    <tr>
      <td data-label="Job">${_walletHistoryJob(item)}</td>
      <td data-label="Fee amount"><strong>${fmtMoney2(item.amount)}</strong></td>
      <td data-label="Payment method">${escapeHtml(_walletHistoryMethod(item.method))}</td>
      <td data-label="Paid on">${_walletHistoryDate(item.paidAt)}</td>
    </tr>`).join('');
}

function _renderWalletHistorySummary(items, meta) {
  const el = document.getElementById('walletHistorySummary');
  if (!el) return;
  const total = Number(meta?.total) || 0;
  if (!total) {
    el.hidden = true;
    el.textContent = '';
    return;
  }
  const cat = _walletHistoryState.category;
  const list = Array.isArray(items) ? items : [];
  const parts = [];

  if (cat === 'withdrawals') {
    const inProgress = list.filter(i => i.status === 'pending' || i.status === 'approved').length;
    const paid = list.filter(i => i.status === 'paid').length;
    parts.push(['Total', String(total)]);
    parts.push(['In progress', String(inProgress)]);
    parts.push(['Paid', String(paid)]);
  } else if (cat === 'releases') {
    const waiting = list.filter(i => i.status === 'waiting_for_release').length;
    const released = list.filter(i => i.status === 'released').length;
    const reversed = list.filter(i => i.status === 'reversed').length;
    parts.push(['Total', String(total)]);
    parts.push(['Waiting', String(waiting)]);
    parts.push(['Released', String(released)]);
    if (reversed) parts.push(['Reversed', String(reversed), 'warn']);
  } else if (cat === 'fees') {
    const sum = list.reduce((acc, i) => acc + (Number(i.amount) || 0), 0);
    parts.push(['Total entries', String(total)]);
    parts.push(['Sum on page', `${fmtMoney2(sum)} EGP`]);
  }

  el.innerHTML = parts.map(([label, value, tone]) => {
    const cls = tone ? ` wallet-history__summary-item--${escapeHtml(tone)}` : '';
    return `<span class="wallet-history__summary-item${cls}"><span class="wallet-history__summary-label">${escapeHtml(label)}</span><strong class="wallet-history__summary-value">${escapeHtml(value)}</strong></span>`;
  }).join('');
  el.hidden = false;
}

function _renderWalletHistoryPagination() {
  const pagination = document.getElementById('walletHistoryPagination');
  const label = document.getElementById('walletHistoryPageLabel');
  const prev = document.getElementById('walletHistoryPrev');
  const next = document.getElementById('walletHistoryNext');
  const totalPages = Math.max(1, Math.ceil(_walletHistoryState.total / WALLET_HISTORY_PAGE_SIZE));
  if (pagination) pagination.hidden = _walletHistoryState.total <= WALLET_HISTORY_PAGE_SIZE;
  if (label) label.textContent = `Page ${_walletHistoryState.page} of ${totalPages}`;
  if (prev) prev.disabled = _walletHistoryState.page <= 1;
  if (next) next.disabled = _walletHistoryState.page >= totalPages;
}

function _setWalletHistoryStatusOptions() {
  const select = document.getElementById('payoutFilterStatus');
  if (!select) return;
  select.innerHTML = WALLET_HISTORY_CONFIG[_walletHistoryState.category].statuses
    .map(([value, label]) => `<option value="${value}">${label}</option>`)
    .join('');
}

async function renderWalletHistory({ resetPage = false } = {}) {
  const tbody = document.getElementById('walletHistoryTbody');
  if (!tbody) return;
  if (resetPage) _walletHistoryState.page = 1;
  if (_walletHistoryAbortController) _walletHistoryAbortController.abort();
  _walletHistoryAbortController = new AbortController();
  const error = document.getElementById('walletHistoryError');
  if (error) error.hidden = true;
  _renderWalletHistoryLoading();

  const params = {
    category: _walletHistoryState.category,
    page: _walletHistoryState.page,
    limit: WALLET_HISTORY_PAGE_SIZE,
    status: document.getElementById('payoutFilterStatus')?.value || '',
    from: document.getElementById('payoutFilterFrom')?.value || '',
    to: document.getElementById('payoutFilterTo')?.value || '',
  };

  try {
    const result = await getWorkerEarningsHistory(params, { signal: _walletHistoryAbortController.signal });
    _walletHistoryState.total = Number(result?.meta?.total) || 0;
    _renderWalletHistoryRows(result?.items || []);
    _renderWalletHistorySummary(result?.items || [], result?.meta || {});
    _renderWalletHistoryPagination();
  } catch (e) {
    if (e.name === 'AbortError') return;
    console.error('[wallet history]', e);
    _walletHistoryState.total = 0;
    if (error) error.hidden = false;
    tbody.innerHTML = '<tr><td colspan="5" class="wallet-history__load-error">Wallet history could not be loaded.</td></tr>';
    _renderWalletHistorySummary([], {});
    _renderWalletHistoryPagination();
  }
}

function renderMyPayoutsV2() {
  return renderWalletHistory();
}

function _wireWithdrawJump() {
  document.querySelector('[data-jump-payout-settings]')?.addEventListener('click', (e) => {
    e.preventDefault();
    document.querySelector('[data-tab="settings"]')?.click();
    setTimeout(() => {
      document.getElementById('stab-btn-payout')?.click();
      document.getElementById('stab-payout')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 150);
  });
}

function _wirePayoutFilters() {
  ['payoutFilterStatus', 'payoutFilterFrom', 'payoutFilterTo'].forEach(id => {
    document.getElementById(id)?.addEventListener('change', () => renderWalletHistory({ resetPage: true }));
  });
  document.getElementById('payoutFiltersClear')?.addEventListener('click', () => {
    const status = document.getElementById('payoutFilterStatus');
    const from = document.getElementById('payoutFilterFrom');
    const to = document.getElementById('payoutFilterTo');
    if (status) status.value = WALLET_HISTORY_CONFIG[_walletHistoryState.category].statuses[0][0];
    if (from) from.value = '';
    if (to) to.value = '';
    renderWalletHistory({ resetPage: true });
  });
}

function _wireWalletHistory() {
  _setWalletHistoryStatusOptions();
  const hint = document.getElementById('walletHistoryHint');
  if (hint) hint.textContent = WALLET_HISTORY_CONFIG[_walletHistoryState.category].hint;
  document.querySelectorAll('[data-wallet-history-category]').forEach(btn => {
    btn.addEventListener('click', () => {
      const category = btn.dataset.walletHistoryCategory;
      _walletHistoryState.category = category;
      _walletHistoryState.page = 1;
      document.querySelectorAll('[data-wallet-history-category]').forEach(tab => {
        const on = tab === btn;
        tab.classList.toggle('is-active', on);
        tab.setAttribute('aria-selected', String(on));
        tab.tabIndex = on ? 0 : -1;
      });
      _setWalletHistoryStatusOptions();
      if (hint) hint.textContent = WALLET_HISTORY_CONFIG[category].hint;
      renderWalletHistory({ resetPage: true });
    });
    btn.addEventListener('keydown', event => {
      const tabs = [...document.querySelectorAll('[data-wallet-history-category]')];
      const current = tabs.indexOf(btn);
      let next = null;
      if (event.key === 'ArrowRight') next = tabs[(current + 1) % tabs.length];
      if (event.key === 'ArrowLeft') next = tabs[(current - 1 + tabs.length) % tabs.length];
      if (event.key === 'Home') next = tabs[0];
      if (event.key === 'End') next = tabs[tabs.length - 1];
      if (!next) return;
      event.preventDefault();
      next.focus();
      next.click();
    });
  });
  document.getElementById('walletHistoryPrev')?.addEventListener('click', () => {
    if (_walletHistoryState.page <= 1) return;
    _walletHistoryState.page -= 1;
    renderWalletHistory();
  });
  document.getElementById('walletHistoryNext')?.addEventListener('click', () => {
    if (_walletHistoryState.page * WALLET_HISTORY_PAGE_SIZE >= _walletHistoryState.total) return;
    _walletHistoryState.page += 1;
    renderWalletHistory();
  });
  document.getElementById('walletHistoryRetry')?.addEventListener('click', () => renderWalletHistory());
}

function _wirePendingReleaseHelp() {
  const button = document.querySelector('.money-card__info[data-tooltip]');
  if (!button) return;
  button.addEventListener('click', event => {
    event.stopPropagation();
    const open = !button.classList.contains('is-open');
    button.classList.toggle('is-open', open);
    button.setAttribute('aria-expanded', String(open));
  });
  document.addEventListener('click', () => {
    button.classList.remove('is-open');
    button.setAttribute('aria-expanded', 'false');
  });
}

function wireEarnErrorBanner() {
  document.getElementById('earnErrorBannerRetry')?.addEventListener('click', () => {
    hideEarningsError();
    renderMyDebtsV2().catch(() => {});
    renderMyPayoutsV2().catch(() => {});
  });
}

function wireDebtActionsV2() {
  document.getElementById('btnSettleDebt')?.addEventListener('click', () => {
    openSettleDebtModal({
      onSuccess: () => {
        _availableBalanceCache = { value: null, ts: 0 };
        populateStats();
        renderMyDebtsV2();
      },
    });
  });
  const payoutHandler = async () => {
    let availableBalance = 0;
    try {
      availableBalance = await getAvailableBalanceCached();
    } catch (_) { /* fall through with 0 */ }
    openPayoutRequestModal({
      availableBalance,
      onSuccess: () => {
        _availableBalanceCache = { value: null, ts: 0 };
        renderMyPayoutsV2();
      },
    });
  };
  document.getElementById('btnRequestPayout')?.addEventListener('click', payoutHandler);
}

/* Earnings sub-nav (Overview / Payouts / Debts) */
function activateEarnSubTab(name) {
  const panel = document.getElementById('panel-earnings');
  if (!panel) return;
  panel.querySelectorAll('.earn-subnav__tab').forEach(btn => {
    const on = btn.dataset.earnTab === name;
    btn.classList.toggle('is-active', on);
    btn.setAttribute('aria-selected', on ? 'true' : 'false');
    btn.tabIndex = on ? 0 : -1;
  });
  panel.querySelectorAll('.earn-view').forEach(view => {
    const on = view.dataset.earnView === name;
    view.classList.toggle('is-active', on);
    view.hidden = !on;
  });
}

function wireEarnSubnav() {
  document.querySelectorAll('#panel-earnings .earn-subnav__tab').forEach(btn => {
    btn.addEventListener('click', () => {
      const target = btn.dataset.earnTab;
      activateEarnSubTab(target);
      if (target === 'payouts') renderMyPayoutsV2().catch(() => { });
    });
    btn.addEventListener('keydown', event => {
      const tabs = [...document.querySelectorAll('#panel-earnings .earn-subnav__tab:not([hidden])')];
      const current = tabs.indexOf(btn);
      let next = null;
      if (event.key === 'ArrowRight') next = tabs[(current + 1) % tabs.length];
      if (event.key === 'ArrowLeft') next = tabs[(current - 1 + tabs.length) % tabs.length];
      if (event.key === 'Home') next = tabs[0];
      if (event.key === 'End') next = tabs[tabs.length - 1];
      if (!next) return;
      event.preventDefault();
      next.focus();
      next.click();
    });
  });
  document.querySelectorAll('#panel-earnings [data-earn-view-jump]').forEach(btn => {
    btn.addEventListener('click', () => {
      const target = btn.dataset.earnViewJump;
      activateEarnSubTab(target);
      if (target === 'payouts') renderMyPayoutsV2().catch(() => { });
      document.getElementById('panel-earnings')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  });
}

function _jumpToWalletHistory(category) {
  activateEarnSubTab('payouts');
  const btn = document.querySelector(`[data-wallet-history-category="${category}"]`);
  if (btn && !btn.classList.contains('is-active')) {
    btn.click();
  } else {
    renderWalletHistory({ resetPage: true }).catch(() => {});
  }
  document.getElementById('panel-earnings')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function _wireTileDeepLinks() {
  const pendingTile = document.getElementById('pendingCard');
  if (pendingTile) {
    pendingTile.classList.add('eog-tile--clickable');
    pendingTile.setAttribute('role', 'button');
    pendingTile.setAttribute('tabindex', '0');
    const handler = (e) => {
      if (e.target.closest('.money-card__info, button, a')) return;
      _jumpToWalletHistory('releases');
    };
    pendingTile.addEventListener('click', handler);
    pendingTile.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); _jumpToWalletHistory('releases'); }
    });
  }

  const liabilityTile = document.getElementById('liabilityCard');
  if (liabilityTile) {
    liabilityTile.classList.add('eog-tile--clickable');
    liabilityTile.setAttribute('role', 'button');
    liabilityTile.setAttribute('tabindex', '0');
    liabilityTile.addEventListener('click', (e) => {
      if (e.target.closest('button, a, summary, details')) return;
      _jumpToWalletHistory('fees');
    });
    liabilityTile.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); _jumpToWalletHistory('fees'); }
    });
  }

  const heldTile = document.getElementById('heldCard');
  if (heldTile) {
    heldTile.classList.add('eog-tile--clickable');
    heldTile.setAttribute('role', 'button');
    heldTile.setAttribute('tabindex', '0');
    const goDisputes = () => {
      document.querySelector('[data-tab="disputes"]')?.click();
    };
    heldTile.addEventListener('click', goDisputes);
    heldTile.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goDisputes(); }
    });
  }
}

async function initPlan2EarningsTab() {
  const panel = document.getElementById('panel-earnings');
  if (!panel) return;

  // Debts must load eagerly: they gate the subnav badge visibility on the
  // Overview view. Payouts load lazily (only when the Withdrawals subtab
  // opens) — fetching them on Overview can fire the error banner for data
  // the user can't even see yet.
  const renderEarningsViews = () => {
    renderMyDebtsV2().catch(err => console.error('[debts]', err));
  };

  if (!panel.hidden) renderEarningsViews();

  const observer = new MutationObserver(mutations => {
    for (const m of mutations) {
      if (m.attributeName === 'hidden' && !panel.hidden) {
        renderEarningsViews();
        break;
      }
    }
  });
  observer.observe(panel, { attributes: true, attributeFilter: ['hidden'] });

  wireDebtActionsV2();
  wireEarnSubnav();
  _wirePayoutFilters();
  _wireWalletHistory();
  _wirePendingReleaseHelp();
  _wireWithdrawJump();
  _wireTileDeepLinks();
  wireEarnErrorBanner();
}

document.addEventListener('DOMContentLoaded', () => {
  initPlan2EarningsTab().catch(err => console.error('[plan2 earnings]', err));
});

document.addEventListener('DOMContentLoaded', () => {
  try { bindTechNotifChannelPrefs(); } catch (err) { console.error('[tech notif prefs]', err); }
});

async function bindTechNotifChannelPrefs() {
  const toggles = document.querySelectorAll('.stab-toggle[data-notif-channel]');
  if (!toggles.length) return;
  try {
    const data = await getNotificationPreferences();
    const channels = data?.channels || {};
    toggles.forEach((btn) => {
      const k = btn.dataset.notifChannel;
      const isOn = channels[k] !== false;
      btn.classList.toggle('stab-toggle--on', isOn);
      btn.setAttribute('aria-checked', isOn ? 'true' : 'false');
    });
  } catch (_) { }

  toggles.forEach((btn) => {
    btn.addEventListener('click', async () => {
      const k = btn.dataset.notifChannel;
      const isCurrentlyOn = btn.getAttribute('aria-checked') === 'true';
      const newState = !isCurrentlyOn;

      btn.classList.toggle('stab-toggle--on', newState);
      btn.setAttribute('aria-checked', newState ? 'true' : 'false');

      try {
        await updateNotificationPreferences({ [k]: newState });
        showToast('Saved', 'success');
      } catch (e) {
        btn.classList.toggle('stab-toggle--on', isCurrentlyOn);
        btn.setAttribute('aria-checked', isCurrentlyOn ? 'true' : 'false');
        showToast(e?.message || 'Failed to save', 'error');
      }
    });
  });

  const pushBtn = document.getElementById('enable-browser-push-btn');
  if (pushBtn) {
    pushBtn.addEventListener('click', async () => {
      if (!('Notification' in window)) {
        showToast('Browser does not support notifications', 'error');
        return;
      }
      try {
        const perm = await Notification.requestPermission();
        if (perm === 'granted') showToast('Browser notifications enabled', 'success');
        else showToast('Permission denied', 'error');
      } catch (_) {
        showToast('Could not request permission', 'error');
      }
    });
  }
}
