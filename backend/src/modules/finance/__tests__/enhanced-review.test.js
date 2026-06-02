const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../../bookings/booking.model');
const Dispute = require('../../payments/dispute.model');
const SupportIssue = require('../../support/support-issue.model');
const enhancedReview = require('../enhanced-review.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() {
  return new mongoose.Types.ObjectId();
}

async function createBooking(overrides = {}) {
  return Booking.create({
    user: id(),
    worker: id(),
    service: id(),
    serviceCategory: 'Cleaning',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '123 Test St',
    paymentMethod: 'online',
    totalPrice: 500,
    ...overrides,
  });
}

test('blocks bookings at the high-value threshold', async () => {
  const booking = await createBooking({ totalPrice: 5000 });
  await expect(enhancedReview.shouldBlock(booking)).resolves.toMatchObject({
    blocked: true,
    reason: 'HIGH_VALUE',
  });
});

test('blocks bookings with an active dispute', async () => {
  const booking = await createBooking();
  await Dispute.create({
    booking: booking._id,
    raisedBy: booking.user,
    raisedByRole: 'user',
    reason: 'The customer provided a sufficiently detailed dispute reason.',
  });
  await expect(enhancedReview.shouldBlock(booking)).resolves.toMatchObject({
    blocked: true,
    reason: 'SAFEGUARD_BLOCK',
    signal: 'active_dispute',
  });
});

test('blocks bookings with an active support issue', async () => {
  const booking = await createBooking();
  await SupportIssue.create({
    booking: booking._id,
    customer: booking.user,
    worker: booking.worker,
    type: 'post_completion',
    description: 'The customer provided a sufficiently detailed support issue.',
  });
  await expect(enhancedReview.shouldBlock(booking)).resolves.toMatchObject({
    blocked: true,
    reason: 'SAFEGUARD_BLOCK',
    signal: 'active_support_issue',
  });
});

test('blocks bookings in an active refusal investigation', async () => {
  const booking = await createBooking({ status: 'refusal_under_investigation' });
  await expect(enhancedReview.shouldBlock(booking)).resolves.toMatchObject({
    blocked: true,
    reason: 'SAFEGUARD_BLOCK',
    signal: 'active_investigation',
  });
});

test('blocks bookings with unresolved risk flags', async () => {
  const booking = await createBooking({ riskFlags: [{ code: 'manual-risk-review' }] });
  await expect(enhancedReview.shouldBlock(booking)).resolves.toMatchObject({
    blocked: true,
    reason: 'SAFEGUARD_BLOCK',
    signal: 'unresolved_risk_flag',
  });
});

test('allows routine low-value booking without safeguards', async () => {
  const booking = await createBooking();
  await expect(enhancedReview.shouldBlock(booking)).resolves.toEqual({ blocked: false });
});
