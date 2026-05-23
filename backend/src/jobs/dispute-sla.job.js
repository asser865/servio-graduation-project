const cron = require('node-cron');
const Dispute = require('../modules/payments/dispute.model');
const Booking = require('../modules/bookings/booking.model');
const AdminAction = require('../modules/admin/admin-action.model');
const notify = require('../modules/notifications/dispatcher');

const SLA_BREACH_HOURS = Number(process.env.DISPUTE_SLA_BREACH_HOURS || 24);
const ESCALATE_HOURS   = Number(process.env.DISPUTE_ESCALATE_HOURS   || 72);

const OPEN_STATES = ['open', 'reviewing', 'awaiting_evidence', 'appealed'];

async function tick() {
  const now = Date.now();
  const breachCutoff   = new Date(now - SLA_BREACH_HOURS * 3600 * 1000);
  const escalateCutoff = new Date(now - ESCALATE_HOURS   * 3600 * 1000);

  const breachRes = await Dispute.updateMany(
    {
      status: { $in: OPEN_STATES },
      createdAt: { $lte: breachCutoff },
      $or: [{ slaBreachedAt: null }, { slaBreachedAt: { $exists: false } }],
    },
    { $set: { slaBreachedAt: new Date() } }
  );

  const toEscalate = await Dispute.find({
    status: { $in: OPEN_STATES },
    createdAt: { $lte: escalateCutoff },
    $or: [{ escalatedAt: null }, { escalatedAt: { $exists: false } }],
  });

  let escalated = 0;
  for (const d of toEscalate) {
    d.status = 'escalated';
    d.escalatedAt = new Date();
    d.history = d.history || [];
    d.history.push({ status: 'escalated', byRole: 'system', note: `Auto-escalated after ${ESCALATE_HOURS}h SLA breach`, at: new Date() });
    await d.save();
    try {
      await AdminAction.create({
        actionType: 'dispute_escalate',
        targetType: 'dispute',
        targetId: d._id,
        details: { reason: 'sla_auto_escalate', hours: ESCALATE_HOURS },
      });
    } catch (_) { /* audit log non-fatal */ }
    try {
      const booking = await Booking.findById(d.booking).select('user worker');
      if (booking?.user) notify.safeDispatch('dispute.escalated', { recipient: booking.user, disputeId: d._id, bookingId: booking._id });
      if (booking?.worker) notify.safeDispatch('dispute.escalated', { recipient: booking.worker, disputeId: d._id, bookingId: booking._id });
    } catch (_) {}
    escalated++;
  }

  return { breached: breachRes?.modifiedCount || 0, escalated, scanned: toEscalate.length };
}

function start() {
  if (process.env.NODE_ENV === 'test') return;
  cron.schedule('*/30 * * * *', async () => {
    try {
      const r = await tick();
      if (r.breached || r.escalated) {
        console.log(`[dispute-sla] breached=${r.breached} escalated=${r.escalated}`);
      }
    } catch (err) {
      console.error('[dispute-sla] error:', err);
    }
  });
}

module.exports = { start, tick, SLA_BREACH_HOURS, ESCALATE_HOURS };
