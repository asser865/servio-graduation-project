// ─── Purpose ──────────────────────────────────────────────────────────────────
// Task 15 (I3 + I6): guard the two edges the rest of the pricing/escrow work
// (Tasks 7-14) didn't directly exercise:
//
//  (a) I3 in-flight degradation — a booking created BEFORE the band/ceiling
//      migration (no seedRangeSnapshot.max, no holdCeiling) must complete and
//      settle WITHOUT throwing: falls back to estimatedTotal, isOverBand=false.
//
//  (b) I6 cash path — a paymentMethod:'cash' booking completing records the
//      final invoice (grandTotal etc.) and the settle path (auto-fee-debt's
//      createIfClean, reached via customer-feedback confirmation) makes NO
//      gateway call, because cash bookings never have a held Payment.
//
//  (P5) cash fee base — the platform-fee CashDebt created on settlement must
//      be computed from the FINAL booking.platformFee (labor-only, Adj.14),
//      not the old pre-completion estimate (platformFeeAmount).
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');
const Payment = require('../../payments/payment.model');
const SavedCard = require('../../savedCards/savedCard.model');
const CashDebt = require('../../payments/cash-debt.model');
require('../../services/service.model');

const completionSvc = require('../completion-outcome.service');
const paymentService = require('../../payments/payment.service');
const feedbackSvc = require('../customer-feedback.service');
const DemoGateway = require('../../payments/gateways/demo.gateway');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() {
  return new mongoose.Types.ObjectId();
}

describe('I3: in-flight booking with no seedRangeSnapshot/holdCeiling', () => {
  test('completes and settles without throwing; falls back to estimatedTotal, isOverBand=false', async () => {
    const user = id();
    const worker = id();
    const serviceId = id();
    const card = await SavedCard.create({
      userId: user, last4: '4242', expiry: '12/30', cardType: 'visa',
    });

    // Pre-migration shape: no seedRangeSnapshot, no holdCeiling (both default to 0).
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
      platformFeeRate: 10,
      // seedRangeSnapshot / holdCeiling intentionally omitted -> model defaults (0/0).
    });

    expect(booking.seedRangeSnapshot?.max).toBeFalsy();
    expect(booking.holdCeiling).toBe(0);

    // Hold falls back to estimatedTotal (P3, Task 7) since holdCeiling is 0.
    await expect(
      paymentService.holdPayment(booking._id, user, { savedCardId: card._id })
    ).resolves.toBeTruthy();

    const held = await Payment.findOne({ booking: booking._id });
    expect(held.amount).toBe(330); // estimatedTotal fallback, not holdCeiling*(1+rate)

    // Worker submits completion outcome -> invoice computed, isOverBand must be false
    // because there is no band to be over.
    await Booking.findByIdAndUpdate(booking._id, { status: 'in_progress' });
    const submitted = await completionSvc.submit(booking._id, worker, {
      outcome: 'customer_paid',
      beforePhotos: ['a'],
      afterPhotos: ['b'],
      laborAmount: 300,
      materials: [{ name: 'pipe', qty: 1, unitPrice: 80 }],
    });
    expect(submitted.isOverBand).toBe(false);
    expect(submitted.flaggedForReview).toBe(false);

    // Customer confirms -> pending_admin_review; admin approves -> settle.
    await Booking.findByIdAndUpdate(booking._id, {
      status: 'pending_admin_review',
      customerConfirmedAt: new Date(),
    });

    await expect(
      paymentService.adminApproveCompletion(booking._id, id())
    ).resolves.toBeTruthy();

    const finalBooking = await Booking.findById(booking._id);
    expect(finalBooking.status).toBe('completed');
    expect(finalBooking.isOverBand).toBe(false);

    const finalPayment = await Payment.findOne({ booking: booking._id });
    expect(finalPayment.status).toBe('released');
    // grandTotal (410) under the estimatedTotal-based hold (330)? No -- 410 > 330,
    // so this exercises the above-hold clamp path too, without throwing.
    expect(finalPayment.capturedAmount).toBeLessThanOrEqual(330);
  });
});

describe('I6: cash booking completes and settles with no gateway call', () => {
  let authorizeSpy;
  let captureSpy;

  beforeEach(() => {
    authorizeSpy = jest.spyOn(DemoGateway.prototype, 'authorize');
    captureSpy = jest.spyOn(DemoGateway.prototype, 'capture');
  });

  afterEach(() => {
    authorizeSpy.mockRestore();
    captureSpy.mockRestore();
  });

  test('records grandTotal, settles via auto-fee-debt, never calls the gateway', async () => {
    const user = id();
    const worker = id();
    const serviceId = id();

    const booking = await Booking.create({
      user, worker, service: serviceId,
      serviceCategory: 'Cleaning',
      scheduledDate: new Date(Date.now() + 86400000),
      address: '123 Test St',
      status: 'in_progress',
      paymentMethod: 'cash',
      seedRangeSnapshot: { min: 300, max: 700 },
      platformFeeRate: 10,
    });

    const out = await completionSvc.submit(booking._id, worker, {
      outcome: 'customer_paid',
      beforePhotos: ['a'],
      afterPhotos: ['b'],
      laborAmount: 300,
      materials: [{ name: 'pipe', qty: 1, unitPrice: 80 }],
    });

    expect(out.subtotal).toBe(380);
    expect(out.platformFee).toBe(30); // money(300 * 0.10) -- labor only, Adj.14
    expect(out.grandTotal).toBe(410);
    expect(out.status).toBe('awaiting_customer_confirmation');

    // No held Payment ever exists for cash.
    expect(await Payment.countDocuments({ booking: booking._id })).toBe(0);

    // Customer confirms -> cash settle path (auto-fee-debt.createIfClean).
    const settled = await feedbackSvc.submit(booking._id, user, { action: 'confirmed' });

    expect(settled.status).toBe('completed');
    expect(settled.paymentStatus).toBe('cash_pending_settlement');
    expect(settled.grandTotal).toBe(410);

    // No gateway call anywhere in the cash settle path.
    expect(authorizeSpy).not.toHaveBeenCalled();
    expect(captureSpy).not.toHaveBeenCalled();
    expect(await Payment.countDocuments({ booking: booking._id })).toBe(0);

    // P5: the platform-fee debt must be based on the FINAL platformFee (labor-only,
    // money(300 * 0.10) = 30), not the old pre-completion estimate (platformFeeAmount,
    // which defaults to 0 here and was never set).
    const debt = await CashDebt.findOne({ booking: booking._id, debtType: 'platform_fee' });
    expect(debt).toBeTruthy();
    expect(debt.amount).toBe(30);
  });
});
