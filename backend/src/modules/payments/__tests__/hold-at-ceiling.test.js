const mongoose  = require('mongoose');
const db        = require('../../../test-utils/db');
const Payment   = require('../payment.model');
const Booking   = require('../../bookings/booking.model');
const SavedCard = require('../../savedCards/savedCard.model');
require('../../services/service.model');
const paymentSvc = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

test('holdPayment holds the band ceiling plus fee-on-ceiling, not the estimate', async () => {
  const user = id(), worker = id(), serviceId = id();
  const card = await SavedCard.create({
    userId: user, last4: '4242', expiry: '12/30', cardType: 'visa',
  });
  const booking = await Booking.create({
    user, worker, service: serviceId,
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '123 Test St',
    status: 'pending',
    paymentMethod: 'online',
    estimatedTotal: 330,
    totalPrice: 300,
    platformFeeAmount: 30,
    holdCeiling: 700,
    platformFeeRate: 10,
  });

  const p = await paymentSvc.holdPayment(booking._id, user, { savedCardId: card._id });
  expect(p.status).toBe('held');

  const saved = await Payment.findOne({ booking: booking._id });
  expect(saved.amount).toBe(770); // 700 ceiling + 70 fee-on-ceiling (700 * 0.10)
});
