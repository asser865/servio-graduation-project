const fmt = (amount, currency = 'EGP') =>
  typeof amount === 'number' ? `${amount.toFixed(2)} ${currency}` : amount;

const TEMPLATES = {
  'payment.held': {
    type:    'payment_held',
    title:   () => 'Payment held in escrow',
    body:    (p) => `We're holding ${fmt(p.amount, p.currency)} until your service is complete.`,
    channels: ['email', 'in-app'],
  },
  'payment.released': {
    type:    'payment_released',
    title:   () => 'Payment released to worker',
    body:    (p) => `Your payment of ${fmt(p.amount, p.currency)} has been released to the worker.`,
    channels: ['email', 'in-app', 'push'],
  },
  'payment.refunded': {
    type:    'payment_refunded',
    title:   () => 'Refund issued',
    body:    (p) => `We refunded ${fmt(p.amount, p.currency)} to your account.`,
    channels: ['email', 'in-app'],
  },
  'dispute.opened': {
    type:    'dispute_opened',
    title:   () => 'A dispute was opened for your booking',
    body:    () => 'Please review the details and respond within 24 hours.',
    channels: ['email', 'in-app'],
  },
  'dispute.evidence_added': {
    type:    'dispute_evidence_added',
    title:   () => 'New evidence on your dispute',
    body:    () => 'New evidence has been submitted to your dispute.',
    channels: ['in-app'],
  },
  'dispute.escalated': {
    type:    'dispute_escalated',
    title:   () => 'Dispute escalated for admin review',
    body:    () => 'Your dispute has exceeded the SLA and is now escalated.',
    channels: ['in-app', 'email'],
  },
  'settlement.verified': {
    type:    'settlement_verified',
    title:   () => 'Settlement verified',
    body:    (p) => `Your settlement of ${fmt(p.amount, p.currency)} has been verified.`,
    channels: ['email', 'in-app'],
  },
  'settlement.rejected': {
    type:    'settlement_rejected',
    title:   () => 'Settlement rejected',
    body:    (p) => `Your settlement was rejected: ${p.reason || 'Please resubmit.'}`,
    channels: ['email', 'in-app'],
  },
  'payout.approved': {
    type:    'payout_approved',
    title:   () => 'Payout approved',
    body:    (p) => `Your payout request of ${fmt(p.amount, p.currency)} has been approved.`,
    channels: ['email', 'in-app'],
  },
  'payout.paid': {
    type:    'payout_paid',
    title:   () => 'Payout paid',
    body:    (p) => `${fmt(p.amount, p.currency)} has been sent to your account.`,
    channels: ['email', 'in-app', 'push'],
  },
  'booking.no_show': {
    type:    'booking_no_show',
    title:   () => 'No-show recorded',
    body:    () => 'A no-show has been recorded for your booking.',
    channels: ['in-app', 'push'],
  },
  'credit.issued': {
    type:    'credit_issued',
    title:   () => 'Credit issued to your wallet',
    body:    (p) => `${fmt(p.amount, p.currency)} has been credited to your wallet${p.reason ? `: ${p.reason}` : '.'}`,
    channels: ['email', 'in-app'],
  },
};

module.exports = { TEMPLATES };
