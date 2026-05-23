const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');
const CashDebt = require('../../payments/cash-debt.model');
const settings = require('../../admin/admin-settings.service');
const bookingService = require('../booking.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function bookingFixture(overrides = {}) {
  return {
    user: new mongoose.Types.ObjectId(),
    worker: new mongoose.Types.ObjectId(),
    service: new mongoose.Types.ObjectId(),
    serviceCategory: 'plumbing',
    status: 'pending',
    scheduledDate: new Date(Date.now() + 86400e3),
    address: '123 Test St',
    totalPrice: 100,
    paymentMethod: 'online',
    ...overrides,
  };
}

test('absolute-block prevents accepting any booking', async () => {
  const worker = new mongoose.Types.ObjectId();
  const cfg = await settings.get();
  await CashDebt.create({
    worker,
    booking: new mongoose.Types.ObjectId(),
    amount: cfg.debt.absoluteBlockThreshold + 50,
    remaining: cfg.debt.absoluteBlockThreshold + 50,
    status: 'outstanding',
  });
  const b = await Booking.create(bookingFixture({ worker, paymentMethod: 'online' }));
  await expect(bookingService.acceptBooking({ bookingId: b._id, technicianId: worker })).rejects.toThrow(/absolute_block/);
});

test('cash-block prevents accepting cash bookings only', async () => {
  const worker = new mongoose.Types.ObjectId();
  const cfg = await settings.get();
  await CashDebt.create({
    worker,
    booking: new mongoose.Types.ObjectId(),
    amount: cfg.debt.blockThreshold + 10,
    remaining: cfg.debt.blockThreshold + 10,
    status: 'outstanding',
  });
  const cashBooking = await Booking.create(bookingFixture({ worker, paymentMethod: 'cash' }));
  await expect(
    bookingService.acceptBooking({ bookingId: cashBooking._id, technicianId: worker }),
  ).rejects.toThrow(/cash_block/);

  const onlineBooking = await Booking.create(bookingFixture({ worker, paymentMethod: 'online' }));
  const accepted = await bookingService.acceptBooking({ bookingId: onlineBooking._id, technicianId: worker });
  expect(accepted.status).toBe('accepted');
});

test('no debt → accept proceeds normally', async () => {
  const worker = new mongoose.Types.ObjectId();
  const b = await Booking.create(bookingFixture({ worker, paymentMethod: 'cash' }));
  const accepted = await bookingService.acceptBooking({ bookingId: b._id, technicianId: worker });
  expect(accepted.status).toBe('accepted');
});
