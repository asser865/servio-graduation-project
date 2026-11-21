const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');
const Payment = require('../../payments/payment.model');
const cancellationService = require('../cancellation.service');
const { money } = require('../../../utils/rounding');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

// Default admin-settings cancellation config (see admin-settings.model.js):
// customerFreeWindowMinutes: 15, customerLateFeePercent: 20.
describe('cancellationService.customerCancel — Task 14: fee base = estimate, not hold ceiling (R8)', () => {
  test('post-grace customer cancel: late fee is based on estimatedTotal, not the held payment.amount (ceiling+fee)', async () => {
    const user = id();
    const worker = id();

    const booking = await Booking.create({
      user,
      worker,
      serviceCategory: 'plumbing',
      scheduledDate: new Date(Date.now() + 86400000),
      address: '1 Test St',
      status: 'accepted',
      paymentMethod: 'online',
      estimatedTotal: 330,
      totalPrice: 300,
      platformFeeAmount: 30,
      holdCeiling: 700,
      platformFeeRate: 10,
      // Well past the 15-minute customerFreeWindowMinutes grace period.
      acceptedAt: new Date(Date.now() - 60 * 60000),
    });

    // Held payment mirrors the post-Task-7 ceiling+fee hold (holdCeiling * (1 + rate) = 700 * 1.1 = 770),
    // which is much larger than the booking's estimatedTotal (330).
    await Payment.create({
      booking: booking._id,
      user,
      worker,
      amount: 770,
      platformFee: 30,
      workerEarning: 300,
      gateway: 'demo',
      gatewayId: 'demo',
      gatewayIntentId: `intent_${booking._id}`,
      heldAt: new Date(),
      status: 'held',
      currency: 'egp',
    });

    const result = await cancellationService.customerCancel(booking._id, { reason: 'changed my mind', by: user });

    const expectedFee = money(330 * (20 / 100)); // 66, NOT money(770 * 0.2) = 154
    expect(result.lateFee).toBe(expectedFee);
    expect(result.lateFee).not.toBe(money(770 * (20 / 100)));

    const expectedRefund = money(770 - expectedFee); // refund = full hold minus fee-on-estimate
    expect(result.refundAmount).toBe(expectedRefund);

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.refundedAmount).toBe(expectedRefund);

    const after = await Booking.findById(booking._id);
    expect(after.status).toBe('cancelled');
    expect(after.lateFeeAmount).toBe(expectedFee);
  });
});
