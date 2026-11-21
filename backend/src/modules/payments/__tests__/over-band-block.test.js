const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../../bookings/booking.model');

// I7 verify-first: grep -rn "autoApprove" src --include=*.js shows
// autoApproveEnabled/autoApproveMaxAmount are declared in
// admin-settings.model.js but never read by any service or job — there is
// no auto-release shortcut to guard. This is a regression test proving the
// existing chain (auto-confirm job -> enhancedReview.shouldBlock) already
// blocks an over-band (flaggedForReview) booking from auto-releasing, even
// when its grandTotal is well within the (unused) autoApproveMaxAmount.

jest.mock('../../notifications/notify.service', () => ({
  sendToUser: jest.fn().mockResolvedValue(),
}));

const job = require('../../../jobs/auto-confirm-bookings.job');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function baseBooking(overrides = {}) {
  return {
    user: new mongoose.Types.ObjectId(),
    worker: new mongoose.Types.ObjectId(),
    service: new mongoose.Types.ObjectId(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '123 Test',
    paymentMethod: 'online',
    totalPrice: 40,
    grandTotal: 40,
    platformFeeAmount: 8,
    ...overrides,
  };
}

test('over-band booking flagged for review still routes to pending_admin_review on auto-confirm, never auto-releases', async () => {
  const past = new Date(Date.now() - 60 * 1000);

  // grandTotal (40) is below the default autoApproveMaxAmount (50), so if an
  // auto-release shortcut existed and were unguarded, this booking would be
  // a prime candidate to slip through. It must not.
  const booking = await Booking.create(
    baseBooking({
      status: 'awaiting_customer_confirmation',
      customerConfirmAutoAt: past,
      flaggedForReview: true,
    })
  );

  const result = await job.runOnce();

  expect(result.safeguarded).toBe(1);
  expect(result.confirmed).toBe(0);

  const after = await Booking.findById(booking._id);
  expect(after.status).toBe('pending_admin_review');
  expect(after.enhancedReviewReason).toBe('SAFEGUARD_BLOCK');
  expect(after.customerConfirmedAt).toBeUndefined();
  expect(after.customerConfirmedVia).toBeUndefined();
});
