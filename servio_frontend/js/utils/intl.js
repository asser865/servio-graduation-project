const LOCALE   = (typeof navigator !== 'undefined' && navigator.language) || 'en-EG';
const CURRENCY = 'EGP';
const TIMEZONE = 'Africa/Cairo';

export const formatMoney = (amount, currency = CURRENCY) => {
  const num = Number(amount);
  if (!Number.isFinite(num)) return '';
  try {
    return new Intl.NumberFormat(LOCALE, { style: 'currency', currency, minimumFractionDigits: 2 }).format(num);
  } catch {
    return `${num.toFixed(2)} ${currency}`;
  }
};

export const formatDate = (date) => {
  if (!date) return '';
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return '';
  return new Intl.DateTimeFormat(LOCALE, { dateStyle: 'medium', timeZone: TIMEZONE }).format(d);
};

export const formatDateTime = (date) => {
  if (!date) return '';
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return '';
  return new Intl.DateTimeFormat(LOCALE, { dateStyle: 'medium', timeStyle: 'short', timeZone: TIMEZONE }).format(d);
};

export const formatRelative = (date) => {
  if (!date) return '';
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return '';
  const rtf = new Intl.RelativeTimeFormat(LOCALE, { numeric: 'auto' });
  const diffMs = d - Date.now();
  const diffMin = Math.round(diffMs / 60000);
  if (Math.abs(diffMin) < 60) return rtf.format(diffMin, 'minute');
  const diffH = Math.round(diffMin / 60);
  if (Math.abs(diffH) < 24) return rtf.format(diffH, 'hour');
  const diffD = Math.round(diffH / 24);
  return rtf.format(diffD, 'day');
};
