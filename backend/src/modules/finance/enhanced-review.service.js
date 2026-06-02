const Dispute = require('../payments/dispute.model');
const SupportIssue = require('../support/support-issue.model');
const { HIGH_VALUE_THRESHOLD_EGP } = require('../../config/finance.config');

const ACTIVE_DISPUTE_STATUSES = ['open', 'reviewing', 'awaiting_evidence', 'appealed', 'escalated'];
const ACTIVE_SUPPORT_STATUSES = ['open', 'reviewing', 'waiting_customer', 'waiting_worker'];

function withSession(query, session) {
  return session ? query.session(session) : query;
}

async function shouldBlock(booking, session = null) {
  if (Number(booking.totalPrice || 0) >= HIGH_VALUE_THRESHOLD_EGP) {
    return { blocked: true, reason: 'HIGH_VALUE', threshold: HIGH_VALUE_THRESHOLD_EGP };
  }

  const dispute = await withSession(Dispute.findOne({
    booking: booking._id,
    status: { $in: ACTIVE_DISPUTE_STATUSES },
  }), session);
  if (dispute) return { blocked: true, reason: 'SAFEGUARD_BLOCK', signal: 'active_dispute', refId: dispute._id };

  const supportIssue = await withSession(SupportIssue.findOne({
    booking: booking._id,
    status: { $in: ACTIVE_SUPPORT_STATUSES },
  }), session);
  if (supportIssue) return { blocked: true, reason: 'SAFEGUARD_BLOCK', signal: 'active_support_issue', refId: supportIssue._id };

  if (booking.status === 'refusal_under_investigation') {
    return { blocked: true, reason: 'SAFEGUARD_BLOCK', signal: 'active_investigation' };
  }

  if (Array.isArray(booking.riskFlags) && booking.riskFlags.some(flag => flag?.status !== 'resolved')) {
    return { blocked: true, reason: 'SAFEGUARD_BLOCK', signal: 'unresolved_risk_flag' };
  }

  if (booking.flaggedForReview) {
    return { blocked: true, reason: 'SAFEGUARD_BLOCK', signal: 'flagged_for_review' };
  }

  return { blocked: false };
}

module.exports = {
  shouldBlock,
  ACTIVE_DISPUTE_STATUSES,
  ACTIVE_SUPPORT_STATUSES,
};
