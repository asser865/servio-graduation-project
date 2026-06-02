const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../../bookings/booking.model');
const CashDebt = require('../cash-debt.model');
const Dispute = require('../dispute.model');
const svc = require('../auto-fee-debt.service');

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
    status: 'pending_admin_review',
    paymentMethod: 'cash',
    totalPrice: 100,
    platformFeeAmount: 18,
    customerFeedback: { action: 'confirmed' },
    ...overrides,
  });
}

async function createDispute(booking, status) {
  return Dispute.create({
    booking: booking._id,
    raisedBy: booking.user,
    raisedByRole: 'user',
    reason: 'Customer raised a sufficiently detailed issue.',
    status,
  });
}

test('creates a platform-fee debt and completes a clean cash booking', async () => {
  const booking = await createBooking();

  const result = await svc.createIfClean(booking._id);

  const after = await Booking.findById(booking._id);
  const debt = await CashDebt.findOne({ booking: booking._id });
  expect(result.created).toBe(true);
  expect(after.status).toBe('completed');
  expect(after.paymentStatus).toBe('cash_pending_settlement');
  expect(debt.worker).toEqual(booking.worker);
  expect(debt.amount).toBe(18);
  expect(debt.debtType).toBe('platform_fee');
});

test('does not create a debt twice for repeated internal calls', async () => {
  const booking = await createBooking();

  await svc.createIfClean(booking._id);
  const second = await svc.createIfClean(booking._id);

  expect(second.created).toBe(false);
  expect(second.skippedReason).toBe('existing_debt');
  expect(await CashDebt.countDocuments({ booking: booking._id })).toBe(1);
});

test('leaves non-cash bookings pending review', async () => {
  const booking = await createBooking({ paymentMethod: 'online' });

  const result = await svc.createIfClean(booking._id);

  expect(result.skippedReason).toBe('non_cash');
  expect((await Booking.findById(booking._id)).status).toBe('pending_admin_review');
  expect(await CashDebt.countDocuments()).toBe(0);
});

test('leaves customer-reported issues pending for review', async () => {
  const booking = await createBooking({
    status: 'customer_disputed',
    customerFeedback: { action: 'reported_issue', issueReason: 'work_not_done' },
  });

  const result = await svc.createIfClean(booking._id);

  expect(result.skippedReason).toBe('customer_reported_issue');
  expect((await Booking.findById(booking._id)).status).toBe('customer_disputed');
  expect(await CashDebt.countDocuments()).toBe(0);
});

test('leaves flagged bookings pending review', async () => {
  const booking = await createBooking({ flaggedForReview: true });

  const result = await svc.createIfClean(booking._id);

  expect(result.skippedReason).toBe('flagged_for_review');
  expect((await Booking.findById(booking._id)).status).toBe('pending_admin_review');
  expect(await CashDebt.countDocuments()).toBe(0);
});

test.each(svc.ACTIVE_DISPUTE_STATUSES)(
  'leaves bookings with an active %s dispute pending review',
  async (status) => {
    const booking = await createBooking();
    await createDispute(booking, status);

    const result = await svc.createIfClean(booking._id);

    expect(result.skippedReason).toBe('active_dispute');
    expect((await Booking.findById(booking._id)).status).toBe('pending_admin_review');
    expect(await CashDebt.countDocuments()).toBe(0);
  }
);
