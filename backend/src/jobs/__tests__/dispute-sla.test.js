const mongoose = require('mongoose');
const db = require('../../test-utils/db');
const Dispute = require('../../modules/payments/dispute.model');
const job = require('../dispute-sla.job');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function makeDispute({ ageHours }) {
  const d = await Dispute.create({
    booking: id(),
    raisedBy: id(),
    raisedByRole: 'user',
    reason: 'Customer claims service quality was unacceptable for paid amount.',
    status: 'open',
  });
  // override createdAt via direct update (Mongoose locks timestamps on create)
  await Dispute.collection.updateOne(
    { _id: d._id },
    { $set: { createdAt: new Date(Date.now() - ageHours * 3600 * 1000) } }
  );
  return d;
}

describe('dispute SLA job', () => {
  test('marks disputes open >24h as SLA-breached', async () => {
    const stale = await makeDispute({ ageHours: 25 });
    const fresh = await makeDispute({ ageHours: 1 });
    const r = await job.tick();
    expect(r.breached).toBeGreaterThanOrEqual(1);
    const staleAfter = await Dispute.findById(stale._id);
    const freshAfter = await Dispute.findById(fresh._id);
    expect(staleAfter.slaBreachedAt).toBeTruthy();
    expect(freshAfter.slaBreachedAt).toBeFalsy();
  });

  test('auto-escalates disputes open >72h', async () => {
    const veryOld = await makeDispute({ ageHours: 73 });
    await job.tick();
    const after = await Dispute.findById(veryOld._id);
    expect(after.status).toBe('escalated');
    expect(after.escalatedAt).toBeTruthy();
    expect(after.history.some(h => h.status === 'escalated' && h.byRole === 'system')).toBe(true);
  });

  test('idempotent — second tick does not re-mark/re-escalate', async () => {
    await makeDispute({ ageHours: 80 });
    const r1 = await job.tick();
    const r2 = await job.tick();
    expect(r1.escalated).toBe(1);
    expect(r2.escalated).toBe(0);
  });

  test('leaves resolved disputes untouched', async () => {
    const resolved = await Dispute.create({
      booking: id(), raisedBy: id(), raisedByRole: 'user',
      reason: 'Quality complaint already settled by admin team.',
      status: 'resolved_refund',
    });
    await Dispute.collection.updateOne(
      { _id: resolved._id },
      { $set: { createdAt: new Date(Date.now() - 100 * 3600 * 1000) } }
    );
    await job.tick();
    const after = await Dispute.findById(resolved._id);
    expect(after.status).toBe('resolved_refund');
    expect(after.slaBreachedAt).toBeFalsy();
  });
});
