export const DEFAULT_PLATFORM_FEE_RATE = 10;

const toNumber = (value, fallback = 0) => {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
};

export const money = (value) => Number(toNumber(value).toFixed(2));

export function calculateBookingFee(baseAmount, platformFeeRate = DEFAULT_PLATFORM_FEE_RATE) {
  const base = money(baseAmount);
  const feeRate = Math.max(0, toNumber(platformFeeRate, DEFAULT_PLATFORM_FEE_RATE));
  const feeAmount = money(base * (feeRate / 100));
  return {
    base,
    feeRate,
    feeAmount,
    estimatedTotal: money(base + feeAmount),
  };
}

export function snapshotFeeFromBooking(booking, fallbackRate = DEFAULT_PLATFORM_FEE_RATE) {
  const base = money(booking?.totalPrice ?? booking?.rate ?? booking?.service?.basePrice ?? booking?.price ?? 0);
  const feeRate = toNumber(booking?.platformFeeRate, fallbackRate);
  const calculated = calculateBookingFee(base, feeRate);
  return {
    base,
    feeRate,
    feeAmount: money(booking?.platformFeeAmount ?? calculated.feeAmount),
    estimatedTotal: money(booking?.estimatedTotal ?? calculated.estimatedTotal),
  };
}

export function formatMoney(value, currency = 'EGP') {
  return `${money(value).toFixed(2)} ${currency}`;
}

export function paymentMethodLabel(method, paymentMeta) {
  if (method === 'cash') return 'Cash after service';
  if (paymentMeta?.last4) return `Card payment - ${String(paymentMeta.cardType || 'Card').toUpperCase()} ending ${paymentMeta.last4}`;
  return 'Card payment';
}
