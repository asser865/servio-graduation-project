const classifier = require('../queue-classifier.service');
const { classify, REASONS } = classifier;

describe('finance queue classifier', () => {
  test('exports the canonical API', () => {
    expect(Object.keys(classifier).sort()).toEqual(['REASONS', 'classify']);
  });

  test('exports the canonical reasons', () => {
    expect(REASONS).toEqual({
      DISPUTE_FILED: 'DISPUTE_FILED',
      SLA_BREACH: 'SLA_BREACH',
      HIGH_VALUE: 'HIGH_VALUE',
      FRAUD_INDICATOR: 'FRAUD_INDICATOR',
      PAYMENT_REFUSAL: 'PAYMENT_REFUSAL',
      AUTO_RELEASE_BLOCK: 'AUTO_RELEASE_BLOCK',
      MANUAL_ESCALATION: 'MANUAL_ESCALATION',
      REPEAT_OFFENDER: 'REPEAT_OFFENDER',
    });
  });

  test.each([
    [
      {
        type: 'dispute',
        slaBreached: true,
        techStrikes: 4,
        customerStrikes: 4,
        fraudFlag: true,
        amount: 9000,
        escalated: true,
      },
      'SLA_BREACH',
    ],
    [{ techStrikes: 3, fraudFlag: true }, 'REPEAT_OFFENDER'],
    [{ customerStrikes: 3, fraudFlag: true }, 'REPEAT_OFFENDER'],
    [{ fraudFlag: true, amount: 9000 }, 'FRAUD_INDICATOR'],
    [{ amount: 3000, escalated: true }, 'HIGH_VALUE'],
    [{ escalated: true, type: 'dispute' }, 'MANUAL_ESCALATION'],
  ])('classifies critical inputs in precedence order', (input, reason) => {
    expect(classify(input)).toEqual({ tier: 'critical', reason });
  });

  test('uses the canonical input threshold inclusively', () => {
    expect(classify({ amount: 750, threshold: 750 })).toEqual({
      tier: 'critical',
      reason: 'HIGH_VALUE',
    });
    expect(classify({ amount: 2999 })).toEqual({
      tier: 'low',
      reason: 'AUTO_RELEASE_BLOCK',
    });
  });

  test.each([
    [{ type: 'dispute' }, 'DISPUTE_FILED'],
    [{ refusalPending: true }, 'PAYMENT_REFUSAL'],
    [{ type: 'refund' }, 'DISPUTE_FILED'],
  ])('classifies %p as high tier', (input, reason) => {
    expect(classify(input)).toEqual({ tier: 'high', reason });
  });

  test.each([
    { techRisk: 'high' },
    { customerRisk: 'high' },
    { type: 'payout_verify' },
    { type: 'cash_debt' },
  ])('classifies %p as medium tier', input => {
    expect(classify(input)).toEqual({
      tier: 'medium',
      reason: 'AUTO_RELEASE_BLOCK',
    });
  });

  test('keeps a clean low-value card release and fallback work low tier', () => {
    expect(classify({
      type: 'card_release',
      amount: 2999,
      techRisk: 'low',
      customerRisk: 'low',
    })).toEqual({
      tier: 'low',
      reason: 'AUTO_RELEASE_BLOCK',
    });
    expect(classify()).toEqual({
      tier: 'low',
      reason: 'AUTO_RELEASE_BLOCK',
    });
  });
});
