const mongoose  = require('mongoose');
const db        = require('../../../test-utils/db');
const Payment   = require('../payment.model');
const Booking   = require('../../bookings/booking.model');
const SavedCard = require('../../savedCards/savedCard.model');
const service   = require('../payment.service');
const creditSvc = require('../customer-credit.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function setup({ total = 1000 } = {}) {
  const user = id(), worker = id();
  const card = await SavedCard.create({
    userId: user, last4: '4242', expiry: '12/30', cardType: 'visa',
  });
  const booking = await Booking.create({
    user, worker, service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: 'x',
    status: 'pending',
    paymentMethod: 'online',
    estimatedTotal: total,
    totalPrice: Math.round(total * 0.9),
    platformFeeAmount: Math.round(total * 0.1),
  });
  return { booking, user, worker, card };
}

describe('credit at checkout', () => {
  test('applies credit balance, charges gateway for remainder', async () => {
    const { booking, user, card } = await setup({ total: 1000 });
    await creditSvc.issueCredit({
      customer: user, amount: 200, source: 'apology', reason: 'test', issuedBy: id(),
    });
    const p = await service.holdPayment(booking._id, user, { savedCardId: card._id, useCredit: true });
    expect(p.creditApplied).toBe(200);
    expect(p.gatewayChargeAmount).toBe(800);
    expect(p.amount).toBe(1000);
    const bal = await creditSvc.balance(user);
    expect(bal).toBe(0);
  });

  test('charges full gateway when useCredit false', async () => {
    const { booking, user, card } = await setup({ total: 500 });
    await creditSvc.issueCredit({
      customer: user, amount: 100, source: 'apology', reason: 'test', issuedBy: id(),
    });
    const p = await service.holdPayment(booking._id, user, { savedCardId: card._id });
    expect(p.creditApplied).toBe(0);
    expect(p.gatewayChargeAmount).toBe(500);
    const bal = await creditSvc.balance(user);
    expect(bal).toBe(100);
  });

  test('credit covers full amount, no gateway authorize needed', async () => {
    const { booking, user, card } = await setup({ total: 300 });
    await creditSvc.issueCredit({
      customer: user, amount: 500, source: 'apology', reason: 'test', issuedBy: id(),
    });
    const p = await service.holdPayment(booking._id, user, { savedCardId: card._id, useCredit: true });
    expect(p.creditApplied).toBe(300);
    expect(p.gatewayChargeAmount).toBe(0);
    const bal = await creditSvc.balance(user);
    expect(bal).toBe(200);
  });
});
