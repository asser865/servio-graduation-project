import { adminPaymentDetail, getDisputeById } from '../api/payments.js';
import { escapeHtml } from '../utils/string.js';
import { bindPhotoGallery, renderPhotoGallery } from './photo-gallery.js';

const DRAWER_EVENT = 'finance-drawer:action';
const TYPE_CONFIG = Object.freeze({
  card_release: {
    label: 'Card release',
    modifier: 'release',
    loadDetail: adminPaymentDetail,
    detailId: (id, context) => context?.paymentId || id,
    actions: [
      { action: 'release', label: 'Release Funds', tone: 'primary' },
      { action: 'refund', label: 'Refund Customer', tone: 'warning' },
    ],
  },
  payout_verify: {
    label: 'Payout verification',
    modifier: 'payout',
    actions: [
      { action: 'approve_payout', label: 'Approve Settlement', tone: 'primary' },
      { action: 'reject_payout', label: 'Reject Settlement', tone: 'danger' },
    ],
  },
  dispute: {
    label: 'Dispute',
    modifier: 'dispute',
    loadDetail: getDisputeById,
    actions: [
      { action: 'tech_at_fault', label: 'Find Tech at Fault', tone: 'danger' },
      { action: 'customer_at_fault', label: 'Find Customer at Fault', tone: 'primary' },
      { action: 'order_revisit', label: 'Order Revisit', tone: 'warning' },
      { action: 'split_50_50', label: 'Split 50/50', tone: 'secondary' },
    ],
  },
  refusal_verify: {
    label: 'Payment refusal',
    modifier: 'refusal',
    actions: [
      { action: 'confirm_refusal', label: 'Customer Confirms Refusal', tone: 'primary' },
      { action: 'dispute_refusal', label: 'Customer Disputes Refusal', tone: 'warning' },
    ],
  },
  refund: {
    label: 'Refund',
    modifier: 'refund',
    loadDetail: adminPaymentDetail,
    detailId: (id, context) => context?.paymentId || id,
    actions: [
      { action: 'approve_refund', label: 'Approve Refund', tone: 'primary' },
      { action: 'reject_refund', label: 'Deny Refund', tone: 'danger' },
    ],
  },
});

const TABS = Object.freeze([
  { id: 'overview', label: 'Overview' },
  { id: 'evidence', label: 'Evidence' },
  { id: 'timeline', label: 'Timeline' },
  { id: 'activity', label: 'Activity' },
]);

let activeDrawer = null;
let previousFocus = null;
let previousBodyOverflow = '';
let openSequence = 0;

function record(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function list(value) {
  return Array.isArray(value) ? value : [];
}

function hasContext(value) {
  return Object.keys(record(value)).length > 0;
}

function first(...values) {
  return values.find(value => value !== undefined && value !== null && value !== '');
}

function valueAt(source, ...paths) {
  for (const path of paths) {
    const value = path.split('.').reduce((current, part) => current?.[part], source);
    if (value !== undefined && value !== null && value !== '') return value;
  }
  return '';
}

function labelize(value) {
  return String(value || '')
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, char => char.toUpperCase());
}

function formatDateTime(value) {
  if (!value) return '-';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '-' : date.toLocaleString();
}

function formatMoney(value, currency = 'EGP') {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return '-';
  const safeCurrency = /^[A-Z]{3}$/.test(String(currency || '').toUpperCase())
    ? String(currency).toUpperCase()
    : 'EGP';
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: safeCurrency,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch {
    return `${amount.toLocaleString()} ${safeCurrency}`;
  }
}

function entityLabel(value) {
  if (!value) return '-';
  if (typeof value !== 'object') return String(value);
  return String(first(value.name, value.email, value._id, value.id, '-'));
}

function shortId(value) {
  const text = String(value || '');
  return text.length > 14 ? `${text.slice(0, 6)}...${text.slice(-6)}` : text || '-';
}

function renderDefinitionList(rows) {
  return `<dl class="finance-review-drawer__meta">
    ${rows.map(([label, value]) => `
      <div>
        <dt>${escapeHtml(label)}</dt>
        <dd>${escapeHtml(value === undefined || value === null || value === '' ? '-' : value)}</dd>
      </div>
    `).join('')}
  </dl>`;
}

function renderNotice(message, tone = 'info') {
  return `<p class="finance-review-drawer__notice finance-review-drawer__notice--${tone}">${escapeHtml(message)}</p>`;
}

function paymentOverview(detail, context, type) {
  const source = record(detail);
  const payment = record(source.payment);
  const booking = record(source.booking);
  const parties = record(source.parties);
  const breakdown = record(source.paymentBreakdown);
  const packet = record(source.decisionPacket);
  const fallback = record(context);
  const currency = first(payment.currency, fallback.currency, 'EGP');
  const rows = [
    ['Payment', shortId(first(payment.id, fallback.paymentId, fallback.id))],
    ['Booking', shortId(first(booking.id, fallback.bookingId, fallback.sourceId))],
    ['Payment status', labelize(first(payment.status, fallback.status))],
    ['Booking status', labelize(first(booking.status, fallback.bookingStatus))],
    ['Service', first(booking.service, fallback.service, fallback.serviceName, '-')],
    ['Customer', entityLabel(first(parties.customer, fallback.customer))],
    ['Technician', entityLabel(first(parties.worker, fallback.worker))],
    ['Amount', formatMoney(first(breakdown.amount, fallback.amount), currency)],
    ['Refundable', formatMoney(first(breakdown.remainingRefundable, fallback.remainingRefundable), currency)],
  ];
  const flags = list(packet.policyFlags);
  const recommendation = first(packet.recommendedAction, fallback.recommendedAction);
  const summary = recommendation
    ? `<div class="finance-review-drawer__summary">
        <span>Recommended decision</span>
        <strong>${escapeHtml(labelize(recommendation))}</strong>
        <small>${escapeHtml(labelize(first(packet.riskLevel, fallback.riskLevel, 'unrated')))} risk</small>
      </div>`
    : '';
  const flagMarkup = flags.length
    ? `<div class="finance-review-drawer__chips">${flags.map(flag => `<span>${escapeHtml(labelize(flag))}</span>`).join('')}</div>`
    : '';
  return `${summary}${renderDefinitionList(rows)}${flagMarkup}${
    type === 'refund'
      ? renderNotice('Refund decisions are emitted for controller handling; no refund mutation runs inside this drawer.')
      : ''
  }`;
}

function disputeOverview(detail, context) {
  const dispute = record(detail);
  const fallback = record(context);
  const booking = record(first(dispute.booking, fallback.booking));
  const payment = record(first(dispute.payment, fallback.payment));
  const rows = [
    ['Dispute', shortId(first(dispute._id, dispute.id, fallback.id))],
    ['Booking', shortId(first(booking._id, booking.id, fallback.bookingId))],
    ['Status', labelize(first(dispute.status, fallback.status))],
    ['Category', labelize(first(dispute.category, fallback.category))],
    ['Severity', labelize(first(dispute.severity, fallback.severity))],
    ['Raised by', entityLabel(first(dispute.raisedBy, fallback.customer))],
    ['Technician', entityLabel(first(booking.worker, fallback.worker))],
    ['Payment', formatMoney(first(payment.amount, fallback.amount), first(payment.currency, fallback.currency, 'EGP'))],
  ];
  const reason = first(dispute.reason, fallback.reason, fallback.basis);
  return `${renderDefinitionList(rows)}${
    reason
      ? `<section class="finance-review-drawer__text-block"><h3>Reported reason</h3><p>${escapeHtml(reason)}</p></section>`
      : ''
  }`;
}

function payoutOverview(context) {
  const item = record(context);
  const rows = [
    ['Payout', shortId(first(item._id, item.id))],
    ['Technician', entityLabel(item.worker)],
    ['Status', labelize(item.status)],
    ['Amount', formatMoney(item.amount, item.currency)],
    ['Method', labelize(first(item.payoutMethod, item.method))],
    ['Requested', formatDateTime(first(item.requestedAt, item.createdAt))],
    ['Processed', formatDateTime(item.processedAt)],
    ['Transaction reference', first(item.transactionRef, '-')],
  ];
  return `${renderDefinitionList(rows)}${renderNotice('This is a bounded queue-context packet. The payout API does not expose a standalone admin detail endpoint.')}`;
}

function refusalOverview(context) {
  const item = record(context);
  const booking = record(first(item.booking, item));
  const outcome = record(first(booking.completionOutcome, item.completionOutcome));
  const verification = record(first(booking.refusalVerification, item.refusalVerification));
  const rows = [
    ['Booking', shortId(first(booking._id, booking.id, item.bookingId, item.id))],
    ['Booking status', labelize(first(booking.status, item.status))],
    ['Customer', entityLabel(first(booking.user, item.customer))],
    ['Technician', entityLabel(first(booking.worker, item.worker))],
    ['Verification', labelize(first(verification.status, item.verificationStatus, 'pending'))],
    ['Submitted', formatDateTime(first(outcome.submittedAt, item.createdAt))],
    ['Customer response', first(verification.customerResponse, '-')],
  ];
  const reason = first(outcome.refusalReason, item.refusalReason, item.basis);
  return `${renderDefinitionList(rows)}${
    reason
      ? `<section class="finance-review-drawer__text-block"><h3>Refusal reason</h3><p>${escapeHtml(reason)}</p></section>`
      : ''
  }${renderNotice('This is a bounded queue-context packet. Refusal verification does not expose a standalone detail endpoint.')}`;
}

function genericOverview(context, id) {
  const item = record(context);
  return `${renderDefinitionList([
    ['Reference', shortId(first(item._id, item.id, id))],
    ['Status', labelize(item.status)],
    ['Amount', formatMoney(first(item.amount, item.totalPaid), item.currency)],
    ['Method', labelize(first(item.method, item.paymentMethod))],
    ['Created', formatDateTime(first(item.createdAt, item.when))],
  ])}${renderNotice('Only a bounded queue-context overview is available for this review type.')}`;
}

function renderOverview(type, detail, context, id) {
  if (type === 'card_release' || type === 'refund') return paymentOverview(detail, context, type);
  if (type === 'dispute') return disputeOverview(detail, context);
  if (type === 'payout_verify') return payoutOverview(context);
  if (type === 'refusal_verify') return refusalOverview(context);
  return genericOverview(context, id);
}

function imageUrls(values) {
  return list(values).map(value => typeof value === 'string' ? value : value?.url).filter(Boolean);
}

function safeGalleryUrls(values) {
  return imageUrls(values).flatMap(value => {
    try {
      const url = new URL(value, window.location.href);
      return ['http:', 'https:'].includes(url.protocol) ? [url.href] : [];
    } catch {
      return [];
    }
  });
}

function renderGallerySection(title, values, emptyLabel) {
  return `<section class="finance-review-drawer__gallery-section">
    <h3>${escapeHtml(title)}</h3>
    ${renderPhotoGallery(safeGalleryUrls(values), { emptyLabel })}
  </section>`;
}

function evidenceMeta(values) {
  const evidence = list(values).filter(value => value && typeof value === 'object');
  if (!evidence.length) return '';
  return `<ul class="finance-review-drawer__compact-list">
    ${evidence.slice(0, 12).map(value => `
      <li>
        <strong>${escapeHtml(first(value.name, 'Evidence file'))}</strong>
        <span>${escapeHtml(labelize(first(value.uploadedByRole, 'unknown')))} - ${escapeHtml(formatDateTime(value.uploadedAt))}</span>
      </li>
    `).join('')}
  </ul>`;
}

function renderEvidence(type, detail, context) {
  if (type === 'dispute') {
    const evidence = list(first(detail?.evidence, context?.evidence));
    return `${renderGallerySection('Dispute evidence', evidence, 'No dispute evidence photos uploaded.')}${evidenceMeta(evidence)}`;
  }
  if (type === 'card_release' || type === 'refund') {
    const evidence = record(detail?.evidence);
    const booking = record(detail?.booking);
    const outcome = record(booking.completionOutcome);
    const feedback = record(booking.customerFeedback);
    return `
      ${renderGallerySection('Technician completion photos', first(outcome.afterPhotos, booking.workerCompletionImages, evidence.workerCompletionImages, context?.workerCompletionImages), 'No technician completion photos.')}
      ${renderGallerySection('Booking photos', first(evidence.bookingImages, context?.bookingImages), 'No booking photos.')}
      ${renderGallerySection('Customer evidence', feedback.evidenceImages, 'No customer evidence photos.')}
      ${first(outcome.workerNotes, booking.workerNotes, evidence.workerNotes) ? `<section class="finance-review-drawer__text-block"><h3>Technician notes</h3><p>${escapeHtml(first(outcome.workerNotes, booking.workerNotes, evidence.workerNotes))}</p></section>` : ''}
    `;
  }
  if (type === 'refusal_verify') {
    const booking = record(first(context?.booking, context));
    const outcome = record(first(booking.completionOutcome, context?.completionOutcome));
    const feedback = record(first(booking.customerFeedback, context?.customerFeedback));
    return `
      ${renderGallerySection('Before photos', outcome.beforePhotos, 'No before photos uploaded.')}
      ${renderGallerySection('After photos', outcome.afterPhotos, 'No after photos uploaded.')}
      ${renderGallerySection('Customer evidence', feedback.evidenceImages, 'No customer evidence photos.')}
    `;
  }
  return renderNotice('No photo evidence is attached to this bounded review packet.');
}

function timelineEntries(type, detail, context) {
  if (type === 'dispute') {
    return list(first(detail?.history, context?.history)).map(entry => ({
      label: labelize(first(entry.status, 'Update')),
      at: entry.at,
      note: entry.note,
    }));
  }
  if (type === 'card_release' || type === 'refund') {
    const timeline = record(detail?.timeline);
    return [
      ['Booked', timeline.bookedAt],
      ['Paid', timeline.paidAt],
      ['Technician started', timeline.workerStartedAt],
      ['Completed', timeline.completedAt],
      ['Customer confirmed', timeline.customerConfirmedAt],
      ['Review started', timeline.reviewStartedAt],
      ['Release eligible', timeline.releaseEligibleAt],
    ].filter(([, at]) => at).map(([label, at]) => ({ label, at }));
  }
  if (type === 'payout_verify') {
    return [
      ['Requested', first(context?.requestedAt, context?.createdAt)],
      ['Processed', context?.processedAt],
      ['Updated', context?.updatedAt],
    ].filter(([, at]) => at).map(([label, at]) => ({ label, at }));
  }
  if (type === 'refusal_verify') {
    const booking = record(first(context?.booking, context));
    const outcome = record(first(booking.completionOutcome, context?.completionOutcome));
    const verification = record(first(booking.refusalVerification, context?.refusalVerification));
    return [
      ['Outcome submitted', outcome.submittedAt],
      ['Customer notified', verification.notifiedAt],
      ['Customer responded', verification.respondedAt],
      ['Updated', booking.updatedAt],
    ].filter(([, at]) => at).map(([label, at]) => ({ label, at }));
  }
  return [];
}

function renderTimeline(type, detail, context) {
  const entries = timelineEntries(type, detail, context);
  if (!entries.length) return renderNotice('No timeline entries are available for this review packet.');
  return `<ol class="finance-review-drawer__timeline">
    ${entries.map(entry => `
      <li>
        <span>${escapeHtml(entry.label)}</span>
        <strong>${escapeHtml(formatDateTime(entry.at))}</strong>
        ${entry.note ? `<p>${escapeHtml(entry.note)}</p>` : ''}
      </li>
    `).join('')}
  </ol>`;
}

function activityEntries(type, detail, context) {
  if (type === 'card_release' || type === 'refund') {
    return list(detail?.auditTrail).map(entry => ({
      label: labelize(first(entry.actionType, 'Finance update')),
      at: entry.createdAt,
      actor: entityLabel(entry.admin),
    }));
  }
  if (type === 'dispute') {
    return list(detail?.internalNotes).map(entry => ({
      label: first(entry.note, 'Internal note'),
      at: entry.at,
      actor: entityLabel(entry.by),
    }));
  }
  return list(context?.activity).slice(0, 12).map(entry => ({
    label: first(entry.label, entry.text, entry.note, entry.status, 'Finance update'),
    at: first(entry.at, entry.createdAt, entry.updatedAt),
    actor: entityLabel(first(entry.actor, entry.by, entry.admin)),
  }));
}

function renderActivity(type, detail, context) {
  const entries = activityEntries(type, detail, context);
  if (!entries.length) return renderNotice('No activity entries are available for this review packet.');
  return `<ul class="finance-review-drawer__activity">
    ${entries.map(entry => `
      <li>
        <strong>${escapeHtml(entry.label)}</strong>
        <span>${escapeHtml(entry.actor)} - ${escapeHtml(formatDateTime(entry.at))}</span>
      </li>
    `).join('')}
  </ul>`;
}

function tabButton(tab, index) {
  return `<button
    class="finance-review-drawer__tab${index === 0 ? ' is-active' : ''}"
    id="financeDrawerTab-${tab.id}"
    type="button"
    role="tab"
    aria-selected="${index === 0 ? 'true' : 'false'}"
    aria-controls="financeDrawerPanel-${tab.id}"
    tabindex="${index === 0 ? '0' : '-1'}"
    data-finance-drawer-tab="${tab.id}"
  >${escapeHtml(tab.label)}</button>`;
}

function renderShell(config, id) {
  return `
    <aside
      class="finance-review-drawer finance-review-drawer--${config.modifier}"
      role="dialog"
      aria-modal="true"
      aria-labelledby="financeDrawerTitle"
      aria-describedby="financeDrawerDescription"
    >
      <header class="finance-review-drawer__header">
        <div>
          <p class="finance-review-drawer__eyebrow" id="financeDrawerDescription">Finance decision packet</p>
          <h2 id="financeDrawerTitle">${escapeHtml(config.label)}</h2>
          <div class="finance-review-drawer__chips">
            <span class="finance-review-drawer__type finance-review-drawer__type--${config.modifier}">${escapeHtml(config.label)}</span>
            <span class="finance-review-drawer__id">#${escapeHtml(shortId(id))}</span>
          </div>
        </div>
        <button class="finance-review-drawer__close" type="button" aria-label="Close finance drawer" data-finance-drawer-close>
          <svg aria-hidden="true" viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>
        </button>
      </header>
      <div class="finance-review-drawer__tabs" role="tablist" aria-label="Finance review sections">
        ${TABS.map(tabButton).join('')}
      </div>
      <div class="finance-review-drawer__content">
        ${TABS.map((tab, index) => `
          <section
            class="finance-review-drawer__panel finance-review-drawer__panel--${tab.id}"
            id="financeDrawerPanel-${tab.id}"
            role="tabpanel"
            aria-labelledby="financeDrawerTab-${tab.id}"
            data-finance-drawer-panel="${tab.id}"
            ${index === 0 ? '' : 'hidden'}
          >
            ${index === 0 ? '<p class="finance-review-drawer__loading">Loading review packet...</p>' : ''}
          </section>
        `).join('')}
      </div>
      <footer class="finance-review-drawer__footer" data-finance-drawer-footer></footer>
    </aside>
  `;
}

function renderFooter(drawer, config, enabled) {
  const footer = drawer.querySelector('[data-finance-drawer-footer]');
  if (!footer) return;
  footer.innerHTML = `
    <div class="finance-review-drawer__decision-actions">
      ${config.actions.map(item => `
        <button
          class="finance-review-drawer__action finance-review-drawer__action--${item.tone}"
          type="button"
          data-finance-drawer-action="${item.action}"
          ${enabled ? '' : 'disabled'}
        >${escapeHtml(item.label)}</button>
      `).join('')}
    </div>
    <button class="finance-review-drawer__cancel" type="button" data-finance-drawer-close>Close</button>
  `;
}

function setPanel(drawer, name, markup) {
  const panel = drawer.querySelector(`[data-finance-drawer-panel="${name}"]`);
  if (panel) panel.innerHTML = markup;
}

function renderPacket(drawer, type, id, detail, context, notice = '') {
  setPanel(drawer, 'overview', `${notice}${renderOverview(type, detail, context, id)}`);
  setPanel(drawer, 'evidence', renderEvidence(type, detail, context));
  setPanel(drawer, 'timeline', renderTimeline(type, detail, context));
  setPanel(drawer, 'activity', renderActivity(type, detail, context));
  bindPhotoGallery(drawer);
}

function bindTabs(drawer) {
  const tabs = [...drawer.querySelectorAll('[role="tab"]')];
  function activate(tab) {
    tabs.forEach(candidate => {
      const selected = candidate === tab;
      candidate.classList.toggle('is-active', selected);
      candidate.setAttribute('aria-selected', String(selected));
      candidate.tabIndex = selected ? 0 : -1;
      const panel = drawer.querySelector(`#${candidate.getAttribute('aria-controls')}`);
      if (panel) panel.hidden = !selected;
    });
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => activate(tab));
    tab.addEventListener('keydown', event => {
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      const nextIndex = event.key === 'Home'
        ? 0
        : event.key === 'End'
          ? tabs.length - 1
          : (index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
      activate(tabs[nextIndex]);
      tabs[nextIndex].focus();
    });
  });
}

function focusableElements(drawer) {
  return [...drawer.querySelectorAll('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])')]
    .filter(element => !element.hidden && element.offsetParent !== null);
}

function handleDocumentKeydown(event) {
  if (!activeDrawer) return;
  if (event.key === 'Escape') {
    event.preventDefault();
    closeFinanceDrawer();
    return;
  }
  if (event.key !== 'Tab') return;
  const drawer = activeDrawer.querySelector('.finance-review-drawer');
  const focusable = drawer ? focusableElements(drawer) : [];
  if (!focusable.length) return;
  const firstFocusable = focusable[0];
  const lastFocusable = focusable[focusable.length - 1];
  if (event.shiftKey && document.activeElement === firstFocusable) {
    event.preventDefault();
    lastFocusable.focus();
  } else if (!event.shiftKey && document.activeElement === lastFocusable) {
    event.preventDefault();
    firstFocusable.focus();
  }
}

function emitDrawerAction(action) {
  if (!activeDrawer) return;
  document.dispatchEvent(new CustomEvent(DRAWER_EVENT, {
    detail: {
      action,
      id: activeDrawer.dataset.financeDrawerId,
      item: activeDrawer.financeDrawerItem,
    },
  }));
}

function bindDrawer(drawer) {
  drawer.addEventListener('click', event => {
    if (event.target === drawer || event.target.closest('[data-finance-drawer-close]')) {
      closeFinanceDrawer();
      return;
    }
    const actionButton = event.target.closest('[data-finance-drawer-action]');
    if (actionButton && !actionButton.disabled) emitDrawerAction(actionButton.dataset.financeDrawerAction);
  });
  bindTabs(drawer);
}

async function hydrateDrawer(drawer, sequence, type, id, itemContext, config) {
  if (!config.loadDetail) {
    renderPacket(drawer, type, id, null, itemContext);
    renderFooter(drawer, config, hasContext(itemContext));
    return;
  }

  try {
    const detail = await config.loadDetail(config.detailId ? config.detailId(id, itemContext) : id);
    if (sequence !== openSequence || drawer !== activeDrawer) return;
    drawer.financeDrawerItem = hasContext(itemContext) ? itemContext : detail;
    renderPacket(drawer, type, id, detail, itemContext);
    renderFooter(drawer, config, true);
  } catch (error) {
    if (sequence !== openSequence || drawer !== activeDrawer) return;
    const message = error?.message || 'Unable to load finance detail.';
    if (hasContext(itemContext)) {
      renderPacket(
        drawer,
        type,
        id,
        null,
        itemContext,
        renderNotice(`Live detail is unavailable. Showing bounded queue context: ${message}`, 'warning'),
      );
      renderFooter(drawer, config, true);
      return;
    }
    setPanel(drawer, 'overview', renderNotice(`Unable to load finance detail: ${message}`, 'danger'));
    setPanel(drawer, 'evidence', renderNotice('Evidence could not be loaded.', 'danger'));
    setPanel(drawer, 'timeline', renderNotice('Timeline could not be loaded.', 'danger'));
    setPanel(drawer, 'activity', renderNotice('Activity could not be loaded.', 'danger'));
    renderFooter(drawer, config, false);
  }
}

export function openFinanceDrawer(action, id, itemContext = null) {
  const type = String(action || '');
  const config = TYPE_CONFIG[type];
  if (!config) throw new TypeError(`Unsupported finance drawer type: ${type || '(empty)'}`);
  if (id === undefined || id === null || id === '') throw new TypeError('Finance drawer id is required.');

  closeFinanceDrawer();
  const sequence = ++openSequence;
  const drawer = document.createElement('div');
  drawer.className = 'finance-review-drawer-backdrop';
  drawer.dataset.financeDrawerId = String(id);
  drawer.dataset.financeDrawerType = type;
  drawer.financeDrawerItem = hasContext(itemContext) ? itemContext : null;
  drawer.innerHTML = renderShell(config, id);

  previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
  previousBodyOverflow = document.body.style.overflow;
  document.body.appendChild(drawer);
  document.body.style.overflow = 'hidden';
  document.body.classList.add('finance-review-drawer-open');
  activeDrawer = drawer;

  renderFooter(drawer, config, !config.loadDetail && hasContext(itemContext));
  bindDrawer(drawer);
  document.addEventListener('keydown', handleDocumentKeydown);
  drawer.querySelector('[data-finance-drawer-close]')?.focus();
  hydrateDrawer(drawer, sequence, type, String(id), itemContext, config);
  return drawer;
}

export function closeFinanceDrawer() {
  if (!activeDrawer) return;
  const drawer = activeDrawer;
  activeDrawer = null;
  openSequence += 1;
  document.removeEventListener('keydown', handleDocumentKeydown);
  drawer.remove();
  document.body.style.overflow = previousBodyOverflow;
  document.body.classList.remove('finance-review-drawer-open');
  if (previousFocus?.isConnected) previousFocus.focus();
  previousFocus = null;
  previousBodyOverflow = '';
}
