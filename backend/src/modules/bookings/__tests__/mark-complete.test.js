const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');
const settings = require('../../admin/admin-settings.service');
const svc = require('../booking.service');

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

test('mark complete → awaiting_customer_confirmation + customerConfirmAutoAt set', async () => {
  const b = await Booking.create({ ...base(), status: 'in_progress' });
  await svc.markComplete({ bookingId: b._id, technicianId: b.worker, notes: 'done', photos: [] });
  const after = await Booking.findById(b._id);
  expect(after.status).toBe('awaiting_customer_confirmation');
  expect(after.customerConfirmAutoAt).toBeInstanceOf(Date);
  const cfg = await settings.get();
  const expectedMs = cfg.escrow.autoConfirmHours * 3600 * 1000;
  expect(after.customerConfirmAutoAt - new Date()).toBeGreaterThan(expectedMs - 5000);
});

test('rejects mark complete from non-in_progress', async () => {
  const b = await Booking.create({ ...base(), status: 'accepted' });
  await expect(svc.markComplete({ bookingId: b._id, technicianId: b.worker }))
    .rejects.toThrow(/in_progress/);
});
