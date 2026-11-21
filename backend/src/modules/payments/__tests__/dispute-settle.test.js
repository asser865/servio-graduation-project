const mongoose  = require('mongoose');
const db        = require('../../../test-utils/db');
const Payment   = require('../payment.model');
const Booking   = require('../../bookings/booking.model');
const Dispute   = require('../dispute.model');
const SavedCard = require('../../savedCards/savedCard.model');
const Wallet    = require('../wallet.model');
const CustomerCredit = require('../customer-credit.model');
require('../../services/service.model');
const paymentService  = require('../payment.service');
const disputeService  = require('../dispute.service');
const { money } = require('../../../utils/rounding');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function holdWithBand({
  holdCeiling = 700,
  platformFeeRate = 10,
  grandTotal,
  subtotal,
  platformFee,
  useCredit = false,
  creditBalance = 0,
} = {}) {
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
    holdCeiling,
    platformFeeRate,
  });

  if (useCredit && creditBalance > 0) {
    await CustomerCredit.create({
      customer: user,
      amount: creditBalance,
      source: 'admin_grant',
      reason: 'test credit',
    });
  }

  await paymentService.holdPayment(booking._id, user, { savedCardId: card._id, useCredit });

  // Simulate the itemized final invoice attached to the booking (Task 9 fields).
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'awaiting_customer_confirmation',
    customerConfirmedAt: new Date(),
    completionOutcome: { afterPhotos: ['https://example.com/after.jpg'] },
    grandTotal,
    subtotal,
    platformFee,
  });

  return { booking, user, worker, card };
}

async function openDisputeFor(booking, user) {
  return disputeService.openDispute(
    booking._id,
    user,
    'Service was not completed as described by the worker at all',
    [],
    'quality'
  );
}

describe('Dispute resolution settles against the held payment', () => {
  test('release decision: captures min(grandTotal, hold) and marks resolved_release', async () => {
    // hold = 700 ceiling + 70 fee-on-ceiling(10%) = 770
    const { booking, user, worker } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 410,
      subtotal: 380,
      platformFee: 30,
    });

    const dispute = await openDisputeFor(booking, user);
    const adminId = id();
    const resolved = await disputeService.resolveDispute(dispute._id, adminId, {
      resolution: 'Worker did complete the job satisfactorily.',
      decision: 'release',
    });

    expect(resolved.status).toBe('resolved_release');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.capturedAmount).toBe(410);
    expect(payment.workerEarning).toBe(380);

    const wallet = await Wallet.findOne({ worker });
    expect(wallet.balance).toBe(380);
  });

  test('refund decision: no capture, payment refunded, status resolved_refund', async () => {
    const { booking, user } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 410,
      subtotal: 380,
      platformFee: 30,
    });

    const dispute = await openDisputeFor(booking, user);
    const adminId = id();
    const resolved = await disputeService.resolveDispute(dispute._id, adminId, {
      resolution: 'Customer is right, job was not delivered.',
      decision: 'refund',
    });

    expect(resolved.status).toBe('resolved_refund');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('refunded');
    expect(payment.capturedAmount).toBeFalsy();
  });

  test('partial_refund decision: captures money(grandTotal - refundAmount), status resolved_partial', async () => {
    const { booking, user, worker } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 410,
      subtotal: 380,
      platformFee: 30,
    });

    const dispute = await openDisputeFor(booking, user);
    const adminId = id();
    const refundAmount = 100;
    const resolved = await disputeService.resolveDispute(dispute._id, adminId, {
      resolution: 'Partial credit for incomplete portion of the job.',
      decision: 'partial_refund',
      refundAmount,
    });

    expect(resolved.status).toBe('resolved_partial');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.capturedAmount).toBe(money(410 - refundAmount));

    // MONEY-LEAK REGRESSION GUARD: worker earning (and thus the wallet credit) must
    // track the CAPTURED amount (310), not the full pre-refund subtotal (380).
    // captureAmount 310 - platformFee 30 = 280. Before the fix this credited 350
    // (380 - debt offset 30... actually here debt offset is 0, so it credited the
    // full subtotal 380), overpaying the worker by 100 (exactly the refundAmount)
    // while the platform absorbed the entire refund instead of sharing it.
    expect(payment.workerEarning).toBe(280);

    const wallet = await Wallet.findOne({ worker });
    expect(wallet.balance).toBe(280);
  });

  test('BUG FIX: partial_refund with refundAmount between grandTotal and hold is REJECTED (no negative capture)', async () => {
    // hold = 700 ceiling + 70 fee-on-ceiling(10%) = 770; grandTotal = 410.
    // refundAmount = 500 is < hold(770) but > grandTotal(410) — must be rejected,
    // because settleTarget = money(grandTotal - refundAmount) = money(410 - 500) = -90
    // would otherwise be passed to settleToAmount as a negative capture target.
    const { booking, user, worker } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 410,
      subtotal: 380,
      platformFee: 30,
    });

    const dispute = await openDisputeFor(booking, user);
    const adminId = id();
    const refundAmount = 500;

    await expect(
      disputeService.resolveDispute(dispute._id, adminId, {
        resolution: 'Admin attempts an out-of-bounds partial refund.',
        decision: 'partial_refund',
        refundAmount,
      })
    ).rejects.toMatchObject({ statusCode: 400 });

    // Payment must be untouched — no negative capture, no bad state left behind.
    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('disputed');
    expect(payment.capturedAmount).toBeFalsy();
    expect(payment.capturedAmount || 0).not.toBeLessThan(0);

    const wallet = await Wallet.findOne({ worker });
    expect(wallet?.balance || 0).toBe(0);
  });

  test('settleToAmount-level guarantee: valid partial_refund (refundAmount 100, grandTotal 410) still captures money(310)', async () => {
    const { booking, user, worker } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 410,
      subtotal: 380,
      platformFee: 30,
    });

    const dispute = await openDisputeFor(booking, user);
    const adminId = id();
    const refundAmount = 100;
    const resolved = await disputeService.resolveDispute(dispute._id, adminId, {
      resolution: 'Valid partial refund within grandTotal bound.',
      decision: 'partial_refund',
      refundAmount,
    });

    expect(resolved.status).toBe('resolved_partial');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.capturedAmount).toBe(money(410 - refundAmount));
    expect(payment.capturedAmount).toBeGreaterThanOrEqual(0);

    const wallet = await Wallet.findOne({ worker });
    expect(wallet.balance).toBeGreaterThan(0);
  });

  test('I-C: refund decision restores creditApplied at hold time to customer credit balance', async () => {
    const { booking, user } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 410,
      subtotal: 380,
      platformFee: 30,
      useCredit: true,
      creditBalance: 100,
    });

    const paymentBeforeResolution = await Payment.findOne({ booking: booking._id });
    expect(paymentBeforeResolution.creditApplied).toBe(100);

    const balanceBeforeResolution = await require('../customer-credit.service').balance(user);
    expect(balanceBeforeResolution).toBe(0);

    const dispute = await openDisputeFor(booking, user);
    const adminId = id();
    await disputeService.resolveDispute(dispute._id, adminId, {
      resolution: 'Customer is right, job was not delivered. Restoring credit used at checkout.',
      decision: 'refund',
    });

    const balanceAfterResolution = await require('../customer-credit.service').balance(user);
    expect(balanceAfterResolution).toBe(100);
  });
});
