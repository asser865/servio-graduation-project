const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function base(extra = {}) {
  return {
    user: new mongoose.Types.ObjectId(),
    worker: new mongoose.Types.ObjectId(),
    serviceCategory: 'plumbing',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '1 Test St',
    paymentMethod: 'online',
    ...extra,
  };
}

test('pricing snapshot + invoice + breakdown fields persist', async () => {
  const b = await Booking.create(base({
    startsFromSnapshot: 300,
    seedRangeSnapshot: { min: 300, max: 700 },
    holdCeiling: 700,
    laborAmount: 300,
    materials: [{ name: 'PVC pipe', qty: 1, unitPrice: 80, reason: 'burst' }],
    subtotal: 380, platformFee: 30, vat: 53.2, grandTotal: 410, isOverBand: false,
  }));
  expect(b.holdCeiling).toBe(700);
  expect(b.materials[0].name).toBe('PVC pipe');
  expect(b.grandTotal).toBe(410);
});

test('new enum values accepted', async () => {
  const b = await Booking.create(base({ status: 'customer_declined' }));
  b.completionOutcome = { outcome: 'customer_declined_work', submittedAt: new Date() };
  await expect(b.save()).resolves.toBeTruthy();
});
