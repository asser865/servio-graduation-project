const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');
const CashDebt = require('../../payments/cash-debt.model');
const svc = require('../customer-feedback.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() {
  return new mongoose.Types.ObjectId();
}

async function createBooking(overrides = {}) {
  return Booking.create({
    user: id(),
    worker: id(),
    service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '123 Test St',
    status: 'awaiting_customer_confirmation',
    paymentMethod: 'cash',
    totalPrice: 100,
    platformFeeAmount: 18,
    ...overrides,
  });
}

test('confirmed cash feedback creates fee debt and completes booking', async () => {
  const booking = await createBooking();

  const result = await svc.submit(booking._id, booking.user, {
    action: 'confirmed',
    rating: 5,
  });

  const debt = await CashDebt.findOne({ booking: booking._id });
  expect(result.status).toBe('completed');
  expect(result.paymentStatus).toBe('cash_pending_settlement');
  expect(debt.amount).toBe(18);
  expect(debt.debtType).toBe('platform_fee');
});

test.each(['card', 'online'])(
  'confirmed %s feedback retains pending admin review',
  async (paymentMethod) => {
    const booking = await createBooking({ paymentMethod });

    const result = await svc.submit(booking._id, booking.user, {
      action: 'confirmed',
      rating: 5,
    });

    expect(result.status).toBe('pending_admin_review');
    expect(await CashDebt.countDocuments()).toBe(0);
  }
);

test('reported cash issue does not create debt', async () => {
  const booking = await createBooking();

  const result = await svc.submit(booking._id, booking.user, {
    action: 'reported_issue',
    issueReason: 'work_not_done',
    notes: 'The requested work is still incomplete.',
    evidenceImages: ['https://example.com/customer-evidence.jpg'],
  });

  expect(result.status).toBe('customer_disputed');
  expect(await CashDebt.countDocuments()).toBe(0);
});

test('reported issue requires evidence', async () => {
  const booking = await createBooking();

  await expect(svc.submit(booking._id, booking.user, {
    action: 'reported_issue',
    issueReason: 'work_not_done',
    notes: 'The requested work is still incomplete.',
  })).rejects.toThrow(/at least one evidence image is required/i);
});
