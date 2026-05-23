const mongoose  = require('mongoose');
const db        = require('../../../test-utils/db');
const Payment   = require('../payment.model');
const Booking   = require('../../bookings/booking.model');
const SavedCard = require('../../savedCards/savedCard.model');
const Wallet    = require('../wallet.model');
const service   = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function setup() {
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
    estimatedTotal: 118,
    totalPrice: 100,
    platformFeeAmount: 18,
  });
  return { booking, user, worker, card };
}

test('holdPayment writes gateway intent id + heldAt', async () => {
  const { booking, user, card } = await setup();
  const p = await service.holdPayment(booking._id, user, { savedCardId: card._id });
  expect(p.status).toBe('held');
  expect(p.gatewayIntentId).toMatch(/^demo_pi_/);
  expect(p.heldAt).toBeInstanceOf(Date);
});

test('adminApproveCompletion captures + writes gatewayChargeId + audit', async () => {
  const { booking, user, worker, card } = await setup();
  await service.holdPayment(booking._id, user, { savedCardId: card._id });
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'pending_admin_review',
    customerConfirmedAt: new Date(),
  });
  const adminId = id();
  await service.adminApproveCompletion(booking._id, adminId);
  const after = await Payment.findOne({ booking: booking._id });
  expect(after.status).toBe('released');
  expect(after.gatewayChargeId).toMatch(/^demo_ch_/);
  expect(after.releasedAt).toBeInstanceOf(Date);
  const AdminAction = require('../../admin/admin-action.model');
  const rows = await AdminAction.find({ actionType: 'payment_release' });
  expect(rows.length).toBe(1);
  const wallet = await Wallet.findOne({ worker });
  expect(wallet.balance).toBe(100);
});
