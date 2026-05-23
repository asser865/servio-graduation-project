const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Payment = require('../payment.model');
require('../../bookings/booking.model');
require('../../users/user.model');
require('../../services/service.model');
const queries = require('../payment.queries');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function held(amount) {
  return Payment.create({
    booking: id(), user: id(), worker: id(),
    amount, platformFee: 0, workerEarning: amount,
    status: 'held', skipFeeCalc: true,
  });
}

test('listAdminPayments filters + paginates', async () => {
  for (let i = 0; i < 5; i++) await held(118);
  const r = await queries.listAdminPayments({ status: 'held', page: 1, limit: 3 });
  expect(r.items.length).toBe(3);
  expect(r.total).toBe(5);
});

test('statsAdmin returns aggregates', async () => {
  await held(100);
  await Payment.create({
    booking: id(), user: id(), worker: id(),
    amount: 50, platformFee: 0, workerEarning: 50,
    status: 'released', releasedAt: new Date(), skipFeeCalc: true,
  });
  const r = await queries.statsAdmin();
  expect(r.heldTotal).toBe(100);
  expect(r.releasedTodayTotal).toBe(50);
});
