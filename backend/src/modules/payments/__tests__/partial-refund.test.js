const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Payment = require('../payment.model');
const Booking = require('../../bookings/booking.model');
const Wallet  = require('../wallet.model');
const service = require('../payment.service');
const AdminAction = require('../../admin/admin-action.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function setup() {
  const user = id(), worker = id();
  const booking = await Booking.create({
    user, worker, service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: 'x',
    paymentMethod: 'online',
    status: 'disputed',
    estimatedTotal: 118, totalPrice: 100, platformFeeAmount: 18,
  });
  await Payment.create({
    booking: booking._id, user, worker,
    amount: 118, platformFee: 18, workerEarning: 100,
    status: 'held',
    gatewayIntentId: 'demo_pi_x', gatewayChargeId: 'demo_ch_x',
    skipFeeCalc: true,
  });
  await Wallet.create({ worker, pendingBalance: 100, balance: 0 });
  return { booking, user, worker };
}

test('proportional partial-refund splits + writes audit', async () => {
  const { booking, worker } = await setup();
  const adminId = id();
  const res = await service.partialRefund({
    bookingId: booking._id, adminId, refundAmount: 40,
    deductFrom: 'proportional', reasonCode: 'quality_issue', reason: 'late service issue',
  });
  expect(res.payment.status).toBe('partially_refunded');
  expect(res.splits.fromTech).toBeCloseTo(40 * (100 / 118), 1);
  expect(res.splits.fromPlatform).toBeCloseTo(40 * (18 / 118), 1);
  const audits = await AdminAction.find({ actionType: 'payment_partial_refund' });
  expect(audits.length).toBe(1);
  const wallet = await Wallet.findOne({ worker });
  expect(wallet.pendingBalance).toBeLessThan(100);
});

test('rejects refund > amount', async () => {
  const { booking } = await setup();
  await expect(service.partialRefund({
    bookingId: booking._id, adminId: id(),
    refundAmount: 200, deductFrom: 'tech', reasonCode: 'quality_issue', reason: 'bad outcome',
  })).rejects.toThrow(/Refund/);
});

test('rejects refund split beyond available worker earnings', async () => {
  const { booking } = await setup();
  await expect(service.partialRefund({
    bookingId: booking._id,
    adminId: id(),
    refundAmount: 110,
    deductFrom: 'tech',
    reasonCode: 'quality_issue',
    reason: 'worker share too small',
  })).rejects.toThrow(/worker earnings/);
});

test('rejects missing structured reason code', async () => {
  const { booking } = await setup();
  await expect(service.partialRefund({
    bookingId: booking._id,
    adminId: id(),
    refundAmount: 10,
    deductFrom: 'platform',
    reason: 'missing code',
  })).rejects.toThrow(/reasonCode/);
});
