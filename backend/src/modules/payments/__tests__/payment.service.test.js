const mongoose  = require('mongoose');
const db        = require('../../../test-utils/db');
const Payment   = require('../payment.model');
const Booking   = require('../../bookings/booking.model');
const SavedCard = require('../../savedCards/savedCard.model');
const Wallet    = require('../wallet.model');
const CashDebt  = require('../cash-debt.model');
require('../../services/service.model');
const service   = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function setup({ paymentMethod = 'online' } = {}) {
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
    paymentMethod,
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
    completionOutcome: { afterPhotos: ['https://example.com/after.jpg'] },
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

test('adminApproveCompletion rejects card release without completion evidence', async () => {
  const { booking, user, card } = await setup();
  await service.holdPayment(booking._id, user, { savedCardId: card._id });
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'pending_admin_review',
    customerConfirmedAt: new Date(),
  });

  await expect(service.adminApproveCompletion(booking._id, id()))
    .rejects.toMatchObject({
      statusCode: 400,
      message: 'Missing completion evidence. At least one after photo is required before releasing card funds.',
    });
});

test('adminApproveCompletion rejects card release when customer reported an issue', async () => {
  const { booking, user, card } = await setup();
  await service.holdPayment(booking._id, user, { savedCardId: card._id });
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'pending_admin_review',
    customerConfirmedAt: new Date(),
    completionOutcome: { afterPhotos: ['https://example.com/after.jpg'] },
    customerFeedback: { action: 'reported_issue', issueReason: 'work_not_done' },
  });

  await expect(service.adminApproveCompletion(booking._id, id()))
    .rejects.toMatchObject({
      statusCode: 400,
      message: 'Cannot release card funds while a customer-reported issue is open.',
    });
});

test('adminApproveCompletion rejects manual cash approval', async () => {
  const { booking } = await setup();
  await Booking.findByIdAndUpdate(booking._id, {
    paymentMethod: 'cash',
    status: 'pending_admin_review',
  });

  await expect(service.adminApproveCompletion(booking._id, id()))
    .rejects.toMatchObject({
      statusCode: 400,
      message: 'Manual cash approval is disabled. Cash platform fees are created automatically after a clean customer confirmation.',
    });
});

test('legacy customer confirmation auto-finalizes clean cash booking', async () => {
  const { booking, user } = await setup({ paymentMethod: 'cash' });
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'awaiting_customer_confirmation',
  });

  const result = await service.requestReleaseByCustomer(booking._id, user);

  const debt = await CashDebt.findOne({ booking: booking._id });
  expect(result.status).toBe('completed');
  expect(result.paymentStatus).toBe('cash_pending_settlement');
  expect(debt.amount).toBe(18);
  expect(debt.debtType).toBe('platform_fee');
});

test('adminApproveCompletion captures held funds for card bookings', async () => {
  const { booking, user, card } = await setup({ paymentMethod: 'card' });
  await service.holdPayment(booking._id, user, { savedCardId: card._id });
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'pending_admin_review',
    customerConfirmedAt: new Date(),
    completionOutcome: { afterPhotos: ['https://example.com/after.jpg'] },
  });

  await service.adminApproveCompletion(booking._id, id());

  const payment = await Payment.findOne({ booking: booking._id });
  expect(payment.status).toBe('released');
  expect(payment.gatewayChargeId).toMatch(/^demo_ch_/);
});

test('getPendingApprovals excludes cash bookings, including explicit cash queries', async () => {
  const shared = {
    user: id(),
    worker: id(),
    service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '123 Test St',
    status: 'pending_admin_review',
    estimatedTotal: 118,
    totalPrice: 100,
    platformFeeAmount: 18,
  };
  const cardBooking = await Booking.create({ ...shared, paymentMethod: 'online' });
  await Booking.create({ ...shared, paymentMethod: 'cash' });

  const approvals = await service.getPendingApprovals();
  expect(approvals.items.map(item => item.bookingId.toString())).toEqual([cardBooking._id.toString()]);

  const cashApprovals = await service.getPendingApprovals({ paymentMethod: 'cash' });
  expect(cashApprovals.items).toEqual([]);
  expect(cashApprovals.pagination.total).toBe(0);
});
