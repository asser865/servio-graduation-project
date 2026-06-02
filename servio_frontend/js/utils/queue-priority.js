import { DEFAULT_THRESHOLD, REASONS } from './queue-priority.constants.js';

function toFiniteNumber(value, fallback = 0) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function normalizeType(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_');
}

function isHighRisk(value) {
  return value === true || String(value || '').trim().toLowerCase() === 'high';
}

function result(tier, reason) {
  return { tier, reason };
}

export function classify(input = {}) {
  const type = normalizeType(input.type);
  const amount = toFiniteNumber(input.amount);
  const threshold = toFiniteNumber(input.threshold, DEFAULT_THRESHOLD);
  const highValueThreshold = threshold >= 0 ? threshold : DEFAULT_THRESHOLD;

  if (input.slaBreached === true) {
    return result('critical', REASONS.SLA_BREACH);
  }
  if (
    toFiniteNumber(input.techStrikes) >= 3
    || toFiniteNumber(input.customerStrikes) >= 3
  ) {
    return result('critical', REASONS.REPEAT_OFFENDER);
  }
  if (input.fraudFlag === true) {
    return result('critical', REASONS.FRAUD_INDICATOR);
  }
  if (amount >= highValueThreshold) {
    return result('critical', REASONS.HIGH_VALUE);
  }
  if (input.escalated === true) {
    return result('critical', REASONS.MANUAL_ESCALATION);
  }
  if (type === 'dispute') {
    return result('high', REASONS.DISPUTE_FILED);
  }
  if (input.refusalPending === true) {
    return result('high', REASONS.PAYMENT_REFUSAL);
  }
  if (type === 'refund') {
    return result('high', REASONS.DISPUTE_FILED);
  }
  if (isHighRisk(input.techRisk) || isHighRisk(input.customerRisk)) {
    return result('medium', REASONS.AUTO_RELEASE_BLOCK);
  }
  if (type === 'payout_verify' || type === 'cash_debt') {
    return result('medium', REASONS.AUTO_RELEASE_BLOCK);
  }
  return result('low', REASONS.AUTO_RELEASE_BLOCK);
}
