const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Payment = require('../payment.model');
const Booking = require('../../bookings/booking.model');
const AdminAction = require('../../admin/admin-action.model');
const Wallet = require('../wallet.model');
const service = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function makeHeldPayment() {
  const user = id(), worker = id(), admin = id();
  const booking = await Booking.create({
    user, worker, service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: 'x',
    paymentMethod: 'online',
    status: 'pending_admin_review',
    estimatedTotal: 1000, totalPrice: 900, platformFeeAmount: 100,
  });
  const payment = await Payment.create({
    booking: booking._id, user, worker,
    amount: 1000, platformFee: 100, workerEarning: 900,
    status: 'held',
    gatewayIntentId: `demo_pi_${booking._id}`,
    heldAt: new Date(),
    skipFeeCalc: true,
  });
  await Wallet.create({ worker, pendingBalance: 900, balance: 0 });
  return { payment, booking, admin };
}

describe('emergency admin actions', () => {
  test('forceRelease releases held payment + logs audit', async () => {
    const { payment, admin } = await makeHeldPayment();
    await service.forceRelease(payment._id, {
      actor: admin,
      reason: 'customer unresponsive for 14 days',
    });
    const after = await Payment.findById(payment._id);
    expect(after.status).toBe('released');
    const action = await AdminAction.findOne({ actionType: 'emergency_release' });
    expect(action).toBeTruthy();
    expect(action.details.reason).toMatch(/14 days/);
  });

  test('forceRelease rejects short reason', async () => {
    const { payment, admin } = await makeHeldPayment();
    await expect(
      service.forceRelease(payment._id, { actor: admin, reason: 'short' })
    ).rejects.toThrow(/min 10 chars/i);
  });

  test('forceLock prevents subsequent refundPayment', async () => {
    const { payment, admin } = await makeHeldPayment();
    await service.forceLock(payment._id, { actor: admin, reason: 'fraud investigation pending' });
    const after = await Payment.findById(payment._id);
    expect(after.lockedAt).toBeTruthy();
    expect(after.lockReason).toMatch(/fraud/);

    await expect(
      service.refundPayment(payment._id, admin, 'refund attempt')
    ).rejects.toThrow(/locked/i);
  });

  test('forceLock twice is rejected', async () => {
    const { payment, admin } = await makeHeldPayment();
    await service.forceLock(payment._id, { actor: admin, reason: 'first lock reason 123' });
    await expect(
      service.forceLock(payment._id, { actor: admin, reason: 'second lock reason 456' })
    ).rejects.toThrow(/already locked/i);
  });

  test('forceUnlock clears lock + records audit', async () => {
    const { payment, admin } = await makeHeldPayment();
    await service.forceLock(payment._id, { actor: admin, reason: 'temporary lock for review' });
    await service.forceUnlock(payment._id, { actor: admin, reason: 'cleared' });
    const after = await Payment.findById(payment._id);
    expect(after.lockedAt).toBeFalsy();
    const action = await AdminAction.findOne({ actionType: 'emergency_unlock' });
    expect(action).toBeTruthy();
  });
});
