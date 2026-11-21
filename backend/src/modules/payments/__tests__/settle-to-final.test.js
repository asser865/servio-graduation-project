const mongoose  = require('mongoose');
const db        = require('../../../test-utils/db');
const Payment   = require('../payment.model');
const Booking   = require('../../bookings/booking.model');
const SavedCard = require('../../savedCards/savedCard.model');
const Wallet    = require('../wallet.model');
require('../../services/service.model');
const service   = require('../payment.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function holdWithBand({ holdCeiling, platformFeeRate = 10, grandTotal, subtotal, platformFee }) {
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

  await service.holdPayment(booking._id, user, { savedCardId: card._id });

  // Simulate the itemized final invoice being attached to the booking (Task 9 fields).
  await Booking.findByIdAndUpdate(booking._id, {
    status: 'pending_admin_review',
    customerConfirmedAt: new Date(),
    completionOutcome: { afterPhotos: ['https://example.com/after.jpg'] },
    grandTotal,
    subtotal,
    platformFee,
  });

  return { booking, user, worker, card };
}

describe('releaseHeldPayment settles to the final invoice', () => {
  test('normal: grandTotal under hold captures grandTotal and credits final subtotal', async () => {
    // hold = 700 ceiling + 70 fee-on-ceiling(10%) = 770
    const { booking, worker } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 410,
      subtotal: 380,
      platformFee: 30,
    });

    const adminId = id();
    await service.adminApproveCompletion(booking._id, adminId);

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.capturedAmount).toBe(410);
    expect(payment.workerEarning).toBe(380);

    const wallet = await Wallet.findOne({ worker });
    // C4 contract: pending must reflect the FINAL settled state (0 once released), not the stale estimate.
    expect(wallet.pendingBalance).toBe(0);
    expect(wallet.balance).toBe(380);

    const updatedBooking = await Booking.findById(booking._id);
    expect(updatedBooking.flaggedForReview).not.toBe(true);
  });

  test('above-hold: grandTotal over hold clamps capture to the hold and flags for review', async () => {
    // hold = 700 ceiling + 70 fee-on-ceiling(10%) = 770
    const { booking, worker } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 900,
      subtotal: 870,
      platformFee: 30,
    });

    const adminId = id();
    await service.adminApproveCompletion(booking._id, adminId);

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.capturedAmount).toBe(770); // clamped to hold, not 900
    expect(payment.workerEarning).toBe(740);  // 770 - platformFee(30), not blind subtotal(870)

    const wallet = await Wallet.findOne({ worker });
    expect(wallet.pendingBalance).toBe(0);
    expect(wallet.balance).toBe(740);

    const updatedBooking = await Booking.findById(booking._id);
    expect(updatedBooking.flaggedForReview).toBe(true);

    const AdminAction = require('../../admin/admin-action.model');
    const rows = await AdminAction.find({ actionType: 'above_hold_manual_collection', targetId: payment._id });
    expect(rows.length).toBe(1);
  });

  test('near-band: grandTotal just under band ceiling-with-fee still captures within hold (C-B invariant)', async () => {
    // hold = 700 ceiling + 70 fee-on-ceiling(10%) = 770
    const { booking, worker } = await holdWithBand({
      holdCeiling: 700,
      platformFeeRate: 10,
      grandTotal: 769,
      subtotal: 739,
      platformFee: 30,
    });

    const adminId = id();
    await service.adminApproveCompletion(booking._id, adminId);

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.capturedAmount).toBe(769);
    expect(payment.capturedAmount).toBeLessThanOrEqual(payment.amount); // never exceeds the hold
    expect(payment.workerEarning).toBe(739);

    const wallet = await Wallet.findOne({ worker });
    expect(wallet.pendingBalance).toBe(0);
    expect(wallet.balance).toBe(739);

    const updatedBooking = await Booking.findById(booking._id);
    expect(updatedBooking.flaggedForReview).not.toBe(true);
  });
});
