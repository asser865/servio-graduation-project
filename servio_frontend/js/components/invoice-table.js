/* ============================================================
   SERVIO — Itemized customer invoice (Task 20 / Phase 3 §9)
   Net-new component, built from design tokens.

   States: loading | empty | error | success | success+over-band
   ------------------------------------------------------------
   SECURITY (Stored-XSS guard, I-A): material `name`, `reason`, and
   `photo` are technician-supplied free text/URL rendered to the
   CUSTOMER. They are NEVER interpolated into innerHTML or a template
   string. Text values are written via `el.textContent`; any <img> is
   built with `document.createElement('img')` + `img.src = url` +
   an `error` event listener (never an inline onerror attribute or a
   template-string `src=`).
   ============================================================ */

import { skLine } from './skeleton.js';
import { formatMoney } from '../utils/fee.js';

function t(key, fallback) {
  return (typeof window !== 'undefined' && typeof window.t === 'function' && window.t(key)) || fallback;
}

function clearNode(node) {
  if (node) node.replaceChildren();
}

/** Build a single invoice row: <div class="inv-row"><span>label</span><span>value</span></div> */
function buildRow({ label, value, emphasis = false, className = '' } = {}) {
  const row = document.createElement('div');
  row.className = `inv-row${emphasis ? ' inv-row--total' : ''}${className ? ' ' + className : ''}`;

  const labelEl = document.createElement('span');
  labelEl.className = 'inv-row__label';
  labelEl.textContent = label; // label text is app-controlled, but textContent is safest regardless

  const valueEl = document.createElement('span');
  valueEl.className = 'inv-row__value';
  valueEl.textContent = value;

  row.append(labelEl, valueEl);
  return row;
}

/**
 * Build a single material line item row.
 * `material.name`, `material.reason`, `material.photo` are technician
 * free text/URL — rendered via textContent / createElement('img') only.
 */
function buildMaterialRow(material) {
  const qty = Number(material?.qty) || 0;
  const unitPrice = Number(material?.unitPrice) || 0;
  const lineTotal = qty * unitPrice;

  const wrap = document.createElement('div');
  wrap.className = 'inv-material';

  const main = document.createElement('div');
  main.className = 'inv-material__main';

  const nameEl = document.createElement('span');
  nameEl.className = 'inv-material__name';
  nameEl.textContent = String(material?.name ?? ''); // SAFE: textContent, never innerHTML

  const calcEl = document.createElement('span');
  calcEl.className = 'inv-material__calc';
  calcEl.textContent = `${qty} × ${formatMoney(unitPrice)}`;

  const totalEl = document.createElement('span');
  totalEl.className = 'inv-material__total';
  totalEl.textContent = formatMoney(lineTotal);

  main.append(nameEl, calcEl, totalEl);
  wrap.appendChild(main);

  const reasonText = String(material?.reason ?? '').trim();
  if (reasonText) {
    const reasonEl = document.createElement('p');
    reasonEl.className = 'inv-material__reason';
    reasonEl.textContent = reasonText; // SAFE: textContent, never innerHTML
    wrap.appendChild(reasonEl);
  }

  const photoUrl = String(material?.photo ?? '').trim();
  if (photoUrl) {
    const figure = document.createElement('figure');
    figure.className = 'inv-material__photo';

    // SAFE: built via createElement + .src assignment + addEventListener.
    // Never an inline onerror attribute or a template-string `src="${...}"`.
    const img = document.createElement('img');
    img.alt = 'Material photo';
    img.loading = 'lazy';
    img.addEventListener('error', () => {
      figure.hidden = true;
    });
    img.src = photoUrl;

    figure.appendChild(img);
    wrap.appendChild(figure);
  }

  return wrap;
}

function buildOverBandBanner({ estimatedTotal, grandTotal }) {
  const banner = document.createElement('div');
  banner.className = 'inv-overband-banner';
  banner.setAttribute('role', 'status');

  const icon = document.createElement('span');
  icon.className = 'inv-overband-banner__icon';
  icon.setAttribute('aria-hidden', 'true');
  icon.textContent = '⚠️';

  const text = document.createElement('span');
  text.className = 'inv-overband-banner__text';
  const template = t('invoice_overband_banner', 'Estimated {estimate} · This invoice {total} — significantly above estimate, please review.');
  text.textContent = template
    .replace('{estimate}', formatMoney(estimatedTotal))
    .replace('{total}', formatMoney(grandTotal));

  banner.append(icon, text);
  return banner;
}

/** Render the loading skeleton state. */
export function renderInvoiceLoading(container) {
  if (!container) return;
  container.hidden = false;
  container.className = 'invoice-card invoice-card--loading';
  clearNode(container);

  const wrap = document.createElement('div');
  wrap.className = 'inv-skeleton';
  wrap.innerHTML = `
    ${skLine('sk-w-40')}
    ${skLine('sk-w-100')}
    ${skLine('sk-w-100')}
    ${skLine('sk-w-75')}
    ${skLine('sk-w-60')}
  `;
  container.appendChild(wrap);
}

/** Render the empty state (no invoice yet). */
export function renderInvoiceEmpty(container) {
  if (!container) return;
  container.hidden = false;
  container.className = 'invoice-card invoice-card--empty';
  clearNode(container);

  const wrap = document.createElement('div');
  wrap.className = 'inv-empty';

  const icon = document.createElement('div');
  icon.className = 'inv-empty__icon';
  icon.setAttribute('aria-hidden', 'true');
  icon.textContent = '🧾';

  const title = document.createElement('p');
  title.className = 'inv-empty__title';
  title.textContent = t('invoice_empty_title', 'Invoice not ready yet');

  const body = document.createElement('p');
  body.className = 'inv-empty__body';
  body.textContent = t('invoice_empty_body', 'Your technician has not submitted a final invoice for this booking yet.');

  wrap.append(icon, title, body);
  container.appendChild(wrap);
}

/** Render the error state with a retry button. */
export function renderInvoiceError(container, { message, onRetry } = {}) {
  if (!container) return;
  container.hidden = false;
  container.className = 'invoice-card invoice-card--error';
  clearNode(container);

  const wrap = document.createElement('div');
  wrap.className = 'inv-error';

  const icon = document.createElement('div');
  icon.className = 'inv-error__icon';
  icon.setAttribute('aria-hidden', 'true');
  icon.textContent = '⚠️';

  const title = document.createElement('p');
  title.className = 'inv-error__title';
  title.textContent = t('invoice_error_title', 'Could not load invoice');

  const body = document.createElement('p');
  body.className = 'inv-error__body';
  body.textContent = String(message || t('invoice_error_body', 'Something went wrong while loading your invoice.'));

  wrap.append(icon, title, body);

  if (typeof onRetry === 'function') {
    const retryBtn = document.createElement('button');
    retryBtn.type = 'button';
    retryBtn.className = 'btn btn--primary btn--sm inv-error__retry';
    retryBtn.textContent = t('invoice_retry', 'Retry');
    retryBtn.addEventListener('click', onRetry);
    wrap.appendChild(retryBtn);
  }

  container.appendChild(wrap);
}

/**
 * Render the itemized invoice success state (and over-band banner if flagged).
 * @param {HTMLElement} container
 * @param {object} booking - must carry laborAmount, materials[], subtotal,
 *   platformFee, vat, grandTotal, isOverBand, estimatedTotal
 */
export function renderInvoiceSuccess(container, booking = {}) {
  if (!container) return;
  container.hidden = false;
  container.className = 'invoice-card invoice-card--success';
  clearNode(container);

  const laborAmount = Number(booking.laborAmount) || 0;
  const materials = Array.isArray(booking.materials) ? booking.materials : [];
  const subtotal = Number(booking.subtotal) || 0;
  const platformFee = Number(booking.platformFee) || 0;
  const vat = Number(booking.vat) || 0;
  const grandTotal = Number(booking.grandTotal) || 0;
  const isOverBand = !!booking.isOverBand;
  const estimatedTotal = Number(booking.estimatedTotal) || 0;

  const header = document.createElement('div');
  header.className = 'inv-header';
  const headerTitle = document.createElement('h3');
  headerTitle.className = 'inv-header__title';
  headerTitle.textContent = t('invoice_title', 'Itemized Invoice');
  header.appendChild(headerTitle);
  container.appendChild(header);

  const body = document.createElement('div');
  body.className = 'inv-body';

  // Labor row
  body.appendChild(buildRow({
    label: t('invoice_labor', 'Labor'),
    value: formatMoney(laborAmount),
  }));

  // Material rows (XSS-safe — see buildMaterialRow)
  if (materials.length) {
    const materialsWrap = document.createElement('div');
    materialsWrap.className = 'inv-materials';

    const materialsLabel = document.createElement('p');
    materialsLabel.className = 'inv-materials__label';
    materialsLabel.textContent = t('invoice_materials', 'Materials');
    materialsWrap.appendChild(materialsLabel);

    materials.forEach((material) => {
      materialsWrap.appendChild(buildMaterialRow(material));
    });

    body.appendChild(materialsWrap);
  }

  // Subtotal
  body.appendChild(buildRow({
    label: t('invoice_subtotal', 'Subtotal'),
    value: formatMoney(subtotal),
    className: 'inv-row--subtotal',
  }));

  // Platform fee
  body.appendChild(buildRow({
    label: t('invoice_platform_fee', 'Platform fee'),
    value: formatMoney(platformFee),
  }));

  // VAT (only if present/non-zero)
  if (vat) {
    body.appendChild(buildRow({
      label: t('invoice_vat', 'VAT'),
      value: formatMoney(vat),
    }));
  }

  // Grand total — emphasized
  body.appendChild(buildRow({
    label: t('invoice_grand_total', 'Grand Total'),
    value: formatMoney(grandTotal),
    emphasis: true,
  }));

  container.appendChild(body);

  // Over-band soft alert (§9.2) — non-blocking, informational only
  if (isOverBand) {
    container.appendChild(buildOverBandBanner({ estimatedTotal, grandTotal }));
    container.classList.add('invoice-card--overband');
  }
}

/**
 * Decide which state to render for a booking and render it.
 * Returns the resolved state name for callers that need it.
 */
export function renderInvoice(container, booking, { loading = false, error = null, onRetry } = {}) {
  if (!container) return 'empty';

  if (loading) {
    renderInvoiceLoading(container);
    return 'loading';
  }
  if (error) {
    renderInvoiceError(container, { message: error, onRetry });
    return 'error';
  }
  const hasInvoice = booking && (
    booking.grandTotal !== undefined && booking.grandTotal !== null
  );
  if (!hasInvoice) {
    renderInvoiceEmpty(container);
    return 'empty';
  }
  renderInvoiceSuccess(container, booking);
  return booking.isOverBand ? 'overband' : 'success';
}
