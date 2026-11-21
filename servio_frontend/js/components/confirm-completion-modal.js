import { confirmBooking } from '../api/payments.js';
import { formatMoney } from '../utils/fee.js';

function t(key, fallback) {
  return (typeof window !== 'undefined' && typeof window.t === 'function' && window.t(key)) || fallback;
}

/**
 * Build a single material line (technician free-text `name`/`reason`,
 * URL `photo`). Stored-XSS guard (I-A): rendered via textContent /
 * createElement('img') only — never interpolated into innerHTML.
 */
function buildMaterialLine(material) {
  const qty = Number(material?.qty) || 0;
  const unitPrice = Number(material?.unitPrice) || 0;
  const lineTotal = qty * unitPrice;

  const row = document.createElement('div');
  row.className = 'confirm-completion-modal__invoice-material';

  const main = document.createElement('div');
  main.className = 'confirm-completion-modal__invoice-material-main';

  const name = document.createElement('span');
  name.textContent = String(material?.name ?? ''); // SAFE: textContent

  const calc = document.createElement('span');
  calc.textContent = `${qty} × ${formatMoney(unitPrice)} = ${formatMoney(lineTotal)}`;

  main.append(name, calc);
  row.appendChild(main);

  const reasonText = String(material?.reason ?? '').trim();
  if (reasonText) {
    const reason = document.createElement('p');
    reason.className = 'confirm-completion-modal__invoice-material-reason';
    reason.textContent = reasonText; // SAFE: textContent
    row.appendChild(reason);
  }

  const photoUrl = String(material?.photo ?? '').trim();
  if (photoUrl) {
    const img = document.createElement('img');
    img.alt = 'Material photo';
    img.className = 'confirm-completion-modal__invoice-material-photo';
    img.loading = 'lazy';
    img.addEventListener('error', () => { img.hidden = true; });
    img.src = photoUrl; // SAFE: assigned via property, not a template-string attribute
    row.appendChild(img);
  }

  return row;
}

/** Build the invoice breakdown block shown above the confirm button. */
function buildInvoiceBreakdown(booking) {
  if (!booking || booking.grandTotal === undefined || booking.grandTotal === null) return null;

  const wrap = document.createElement('div');
  wrap.className = 'confirm-completion-modal__invoice';

  const title = document.createElement('h3');
  title.className = 'confirm-completion-modal__invoice-title';
  title.textContent = t('invoice_title', 'Itemized Invoice');
  wrap.appendChild(title);

  const addRow = (label, value, emphasis = false) => {
    const row = document.createElement('div');
    row.className = `inv-row${emphasis ? ' inv-row--total' : ''}`;
    const labelEl = document.createElement('span');
    labelEl.className = 'inv-row__label';
    labelEl.textContent = label;
    const valueEl = document.createElement('span');
    valueEl.className = 'inv-row__value';
    valueEl.textContent = value;
    row.append(labelEl, valueEl);
    wrap.appendChild(row);
  };

  addRow(t('invoice_labor', 'Labor'), formatMoney(Number(booking.laborAmount) || 0));

  const materials = Array.isArray(booking.materials) ? booking.materials : [];
  if (materials.length) {
    const materialsLabel = document.createElement('p');
    materialsLabel.className = 'confirm-completion-modal__invoice-materials-label';
    materialsLabel.textContent = t('invoice_materials', 'Materials');
    wrap.appendChild(materialsLabel);
    materials.forEach((material) => wrap.appendChild(buildMaterialLine(material)));
  }

  addRow(t('invoice_subtotal', 'Subtotal'), formatMoney(Number(booking.subtotal) || 0));
  addRow(t('invoice_platform_fee', 'Platform fee'), formatMoney(Number(booking.platformFee) || 0));
  if (booking.vat) addRow(t('invoice_vat', 'VAT'), formatMoney(Number(booking.vat) || 0));
  addRow(t('invoice_grand_total', 'Grand Total'), formatMoney(Number(booking.grandTotal) || 0), true);

  if (booking.isOverBand) {
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
      .replace('{estimate}', formatMoney(Number(booking.estimatedTotal) || 0))
      .replace('{total}', formatMoney(Number(booking.grandTotal) || 0));
    banner.append(icon, text);
    wrap.appendChild(banner);
  }

  return wrap;
}

/**
 * @param {object} opts
 * @param {string} opts.bookingId
 * @param {object} [opts.booking] - booking/invoice fields (laborAmount, materials,
 *   subtotal, platformFee, vat, grandTotal, isOverBand, estimatedTotal). When
 *   present, the itemized breakdown renders above the confirm button.
 */
export function openConfirmCompletionModal({ bookingId, booking, rating, comment, tags, onSuccess, onError }) {
  const wrap = document.createElement('div');
  wrap.className = 'modal modal--center';
  wrap.innerHTML = `
    <div class="modal__panel">
      <button class="modal__close" aria-label="Close">&times;</button>
      <h2 data-i18n="escrow.confirmModalTitle">Confirm completion</h2>
      <p data-i18n="escrow.confirmModalBody">By confirming, the booking moves to admin review and payment will be released after approval.</p>
      <div class="confirm-completion-modal__invoice-slot" data-invoice-slot></div>
      <div class="modal__actions">
        <button class="btn btn--ghost" data-action="cancel">Cancel</button>
        <button class="btn btn--primary" data-action="submit">Confirm</button>
      </div>
    </div>`;
  document.body.appendChild(wrap);

  const invoiceSlot = wrap.querySelector('[data-invoice-slot]');
  const breakdown = buildInvoiceBreakdown(booking);
  if (breakdown && invoiceSlot) invoiceSlot.appendChild(breakdown);

  const close = () => wrap.remove();
  wrap.querySelector('.modal__close').onclick = close;
  wrap.querySelector('[data-action="cancel"]').onclick = close;
  wrap.querySelector('[data-action="submit"]').onclick = async () => {
    const btn = wrap.querySelector('[data-action="submit"]');
    btn.disabled = true;
    btn.textContent = 'Submitting…';
    try {
      const result = await confirmBooking(bookingId, { rating, comment, tags });
      close();
      onSuccess?.(result);
    } catch (err) {
      btn.disabled = false;
      btn.textContent = 'Confirm';
      onError?.(err);
    }
  };
}
