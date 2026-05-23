const mongoose = require('mongoose');
const db = require('../../test-utils/db');
const Booking = require('../../modules/bookings/booking.model');

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
});

test('sends 24h reminder once', async () => {
  notify.sendToUser.mockClear();
  const confirmAt = new Date(Date.now() + 48 * 3600 * 1000);
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
