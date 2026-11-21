const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');
const svc = require('../completion-outcome.service');

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
    status: 'in_progress',
    seedRangeSnapshot: { min: 300, max: 700 },
    platformFeeRate: 10,
    ...extra,
  };
}

test('computes subtotal/platformFee(labor-only)/grandTotal and isOverBand=false within band', async () => {
  const b = await Booking.create(base());
  const out = await svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 300,
    materials: [{ name: 'pipe', qty: 1, unitPrice: 80 }],
  });
  expect(out.subtotal).toBe(380);
  expect(out.platformFee).toBe(30);
  expect(out.grandTotal).toBe(410);
  expect(out.isOverBand).toBe(false);
  expect(out.flaggedForReview).toBe(false);
  expect(out.status).toBe('awaiting_customer_confirmation');
  expect(out.customerConfirmAutoAt).toBeInstanceOf(Date);
});

test('flags over-band invoice and sets flaggedForReview/flagReason', async () => {
  const b = await Booking.create(base());
  const out = await svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 1200,
    materials: [],
  });
  // platformFee = 120, subtotal = 1200, grandTotal = 1320; bandMax*mult = 700*1.5 = 1050
  expect(out.grandTotal).toBe(1320);
  expect(out.isOverBand).toBe(true);
  expect(out.flaggedForReview).toBe(true);
  expect(out.flagReason).toBe('over_band_invoice');
});

test('flags high-value invoice even when within band (no seedRangeSnapshot)', async () => {
  const b = await Booking.create(base({ seedRangeSnapshot: { min: 0, max: 0 } }));
  const out = await svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 3000,
    materials: [],
  });
  expect(out.isOverBand).toBe(false);
  expect(out.flaggedForReview).toBe(true);
  expect(out.flagReason).toBe('high_value_invoice');
});

test('rejects material with qty < 1', async () => {
  const b = await Booking.create(base());
  await expect(svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 100,
    materials: [{ name: 'x', qty: 0, unitPrice: 10 }],
  })).rejects.toThrow();
});

test('rejects material with unitPrice <= 0', async () => {
  const b = await Booking.create(base());
  await expect(svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 100,
    materials: [{ name: 'x', qty: 1, unitPrice: 0 }],
  })).rejects.toThrow();
});

test('rejects material with empty name', async () => {
  const b = await Booking.create(base());
  await expect(svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 100,
    materials: [{ name: '  ', qty: 1, unitPrice: 10 }],
  })).rejects.toThrow();
});

test('rejects more than 50 material lines', async () => {
  const b = await Booking.create(base());
  const materials = Array.from({ length: 51 }, (_, i) => ({ name: `m${i}`, qty: 1, unitPrice: 1 }));
  await expect(svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 100,
    materials,
  })).rejects.toThrow();
});

test('VAT is carved out of grandTotal (inclusive), not added on top of subtotal', async () => {
  const b = await Booking.create(base());
  const out = await svc.submit(b._id, b.worker, {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 300,
    materials: [{ name: 'pipe', qty: 1, unitPrice: 80 }],
  });
  // grandTotal = 410; vatRate default 0.14 -> vat = 410 - 410/1.14 = 50.35
  expect(out.vat).toBeCloseTo(410 - 410 / 1.14, 2);
});

test('concurrent submit: second call is rejected and does not double-write the invoice', async () => {
  const b = await Booking.create(base());
  const payload = {
    outcome: 'customer_paid',
    beforePhotos: ['a'],
    afterPhotos: ['b'],
    laborAmount: 300,
    materials: [{ name: 'pipe', qty: 1, unitPrice: 80 }],
  };

  const results = await Promise.allSettled([
    svc.submit(b._id, b.worker, payload),
    svc.submit(b._id, b.worker, payload),
  ]);

  const fulfilled = results.filter(r => r.status === 'fulfilled');
  const rejected = results.filter(r => r.status === 'rejected');
  expect(fulfilled.length).toBe(1);
  expect(rejected.length).toBe(1);

  const after = await Booking.findById(b._id);
  expect(after.status).toBe('awaiting_customer_confirmation');
  expect(after.grandTotal).toBe(410);
});
