const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Payment = require('../payment.model');
const Booking = require('../../bookings/booking.model');
const CustomerCredit = require('../customer-credit.model');
const service = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function makePayment({ ageDays = 0 } = {}) {
  const user = id(), worker = id();
  const booking = await Booking.create({
    user, worker, service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: 'x',
    paymentMethod: 'online',
    status: 'disputed',
    estimatedTotal: 1000, totalPrice: 900, platformFeeAmount: 100,
  });
  const payment = await Payment.create({
    booking: booking._id, user, worker,
    amount: 1000, platformFee: 100, workerEarning: 900,
    status: 'held',
    gatewayIntentId: 'pi_x', gatewayChargeId: 'ch_x',
    capturedAt: new Date(Date.now() - ageDays * 86400000),
    skipFeeCalc: true,
  });
  return { payment, user, worker, booking };
}

describe('refundWithFallback destination policy', () => {
  test('refunds to gateway when capture < 90 days old', async () => {
    const { payment } = await makePayment({ ageDays: 5 });
    const r = await service.refundWithFallback({
      paymentId: payment._id, amount: 1000, reason: 'cancel', actor: id(),
    });
    expect(r.destination).toBe('gateway');
    const credits = await CustomerCredit.find({});
    expect(credits.length).toBe(0);
  });

  test('falls back to wallet_credit when refund window expired', async () => {
    const { payment, user } = await makePayment({ ageDays: 100 });
    const r = await service.refundWithFallback({
      paymentId: payment._id, amount: 1000, reason: 'cancel', actor: id(),
    });
    expect(r.destination).toBe('wallet_credit');
    const credit = await CustomerCredit.findOne({ customer: user });
    expect(credit).toBeTruthy();
    expect(credit.amount).toBe(1000);
    expect(credit.source).toBe('refund_fallback');
  });

  test('rejects refund exceeding available amount', async () => {
    const { payment } = await makePayment({ ageDays: 1 });
    await expect(
      service.refundWithFallback({ paymentId: payment._id, amount: 2000, reason: 'x', actor: id() })
    ).rejects.toThrow(/exceeds/i);
  });
});
