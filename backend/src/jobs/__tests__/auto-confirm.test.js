const mongoose = require('mongoose');
const db = require('../../test-utils/db');
const Booking = require('../../modules/bookings/booking.model');
const CashDebt = require('../../modules/payments/cash-debt.model');

jest.mock('../../modules/notifications/notify.service', () => ({
  sendToUser: jest.fn().mockResolvedValue(),
}));
const notify = require('../../modules/notifications/notify.service');
const job = require('../auto-confirm-bookings.job');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function base() {
  return {
    user: new mongoose.Types.ObjectId(),
    worker: new mongoose.Types.ObjectId(),
    service: new mongoose.Types.ObjectId(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '123 Test',
    paymentMethod: 'online',
    totalPrice: 100,
    platformFeeAmount: 18,
  };
}

test('auto-confirms expired bookings', async () => {
  const past = new Date(Date.now() - 60 * 1000);
  const future = new Date(Date.now() + 86400 * 1000);
  await Booking.create({ ...base(), status: 'awaiting_customer_confirmation', customerConfirmAutoAt: past });
  await Booking.create({ ...base(), status: 'awaiting_customer_confirmation', customerConfirmAutoAt: future });
  const result = await job.runOnce();
  expect(result.confirmed).toBe(1);
  expect(result.scanned).toBe(2);
  const confirmed = await Booking.findOne({ customerConfirmedVia: 'system_auto' });
  expect(confirmed.status).toBe('pending_admin_review');
  expect(confirmed.customerConfirmedAt).toBeInstanceOf(Date);
  expect(confirmed.customerFeedback.action).toBe('system_auto_confirmed');
});

test('sends 24h reminder once', async () => {
  notify.sendToUser.mockClear();
  const confirmAt = new Date(Date.now() + 24 * 3600 * 1000);
  await Booking.create({ ...base(), status: 'awaiting_customer_confirmation', customerConfirmAutoAt: confirmAt });
  await job.runOnce();
  expect(notify.sendToUser).toHaveBeenCalledWith(
    expect.objectContaining({ event: 'confirm_reminder_24h' })
  );
  const callsBefore = notify.sendToUser.mock.calls.length;
  await job.runOnce();
  expect(notify.sendToUser.mock.calls.length).toBe(callsBefore);
});

test('skips disputed bookings', async () => {
  const past = new Date(Date.now() - 60 * 1000);
  await Booking.create({ ...base(), status: 'disputed', customerConfirmAutoAt: past });
  const result = await job.runOnce();
  expect(result.confirmed).toBe(0);
});

test('auto-confirmed clean cash booking creates fee debt and completes', async () => {
  const past = new Date(Date.now() - 60 * 1000);
  const booking = await Booking.create({
    ...base(),
    paymentMethod: 'cash',
    status: 'awaiting_customer_confirmation',
    customerConfirmAutoAt: past,
  });

  const result = await job.runOnce();

  expect(result.confirmed).toBe(1);
  const after = await Booking.findById(booking._id);
  expect(after.status).toBe('completed');
  expect(after.paymentStatus).toBe('cash_pending_settlement');
  expect(await CashDebt.countDocuments({ booking: booking._id })).toBe(1);
});

test('repairs legacy cash confirmation stranded in pending admin review', async () => {
  const booking = await Booking.create({
    ...base(),
    paymentMethod: 'cash',
    status: 'pending_admin_review',
    customerConfirmedAt: new Date(),
  });

  const result = await job.runOnce();

  expect(result.repaired).toBe(1);
  const after = await Booking.findById(booking._id);
  expect(after.status).toBe('completed');
  expect(after.paymentStatus).toBe('cash_pending_settlement');
  expect(await CashDebt.countDocuments({ booking: booking._id })).toBe(1);
});

test('routes high-value expired booking to manual review safeguard', async () => {
  const past = new Date(Date.now() - 60 * 1000);
  const booking = await Booking.create({
    ...base(),
    totalPrice: 5000,
    status: 'awaiting_customer_confirmation',
    customerConfirmAutoAt: past,
  });

  const result = await job.runOnce();

  expect(result.safeguarded).toBe(1);
  expect(result.confirmed).toBe(0);
  const after = await Booking.findById(booking._id);
  expect(after.status).toBe('pending_admin_review');
  expect(after.enhancedReviewReason).toBe('HIGH_VALUE');
  expect(after.customerConfirmedAt).toBeUndefined();
  expect(after.customerConfirmedVia).toBeUndefined();
  expect(after.customerFeedback.action).toBeUndefined();
});

test('uses completion submission time for legacy waiting bookings without stored deadline', async () => {
  const booking = await Booking.create({
    ...base(),
    status: 'awaiting_customer_confirmation',
    completionOutcome: {
      outcome: 'customer_paid',
      submittedAt: new Date(Date.now() - 49 * 3600 * 1000),
      beforePhotos: ['before.jpg'],
      afterPhotos: ['after.jpg'],
    },
  });

  const result = await job.runOnce();

  expect(result.confirmed).toBe(1);
  const after = await Booking.findById(booking._id);
  expect(after.customerConfirmedVia).toBe('system_auto');
  expect(after.status).toBe('pending_admin_review');
});
