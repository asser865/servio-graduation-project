const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Booking = require('../booking.model');
const Payment = require('../../payments/payment.model');
const SavedCard = require('../../savedCards/savedCard.model');
const Service = require('../../services/service.model');
const AdminAction = require('../../admin/admin-action.model');
const Wallet = require('../../payments/wallet.model');
const CashDebt = require('../../payments/cash-debt.model');
const svc = require('../completion-outcome.service');
const paymentService = require('../../payments/payment.service');
const { money } = require('../../../utils/rounding');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function makeService(inspectionFee = 150) {
  return Service.create({
    title: 'Inspection Service',
    description: 'A service with an inspection/callout fee',
    category: 'plumbing',
    basePrice: 100,
    estimatedDurationMin: 30,
    priceUnit: 'fixed',
    serviceType: 'inspection',
    inspectionFee,
    createdBy: id(),
  });
}

function bookingBase(extra = {}) {
  return {
    user: id(),
    worker: id(),
    serviceCategory: 'plumbing',
    scheduledDate: new Date(Date.now() + 86400000),
    address: '1 Test St',
    status: 'in_progress',
    platformFeeRate: 10,
    ...extra,
  };
}

describe('completionOutcomeService.submit — customer_declined_work (Task 13 callout fee)', () => {
  test('missing declineReason is rejected', async () => {
    const service = await makeService(150);
    const b = await Booking.create(bookingBase({ service: service._id, paymentMethod: 'cash' }));

    await expect(
      svc.submit(b._id, b.worker, { outcome: 'customer_declined_work' })
    ).rejects.toThrow(/decline reason is required/i);

    const after = await Booking.findById(b._id);
    expect(after.status).toBe('in_progress');
  });

  test('cash booking: no-op capture, terminal customer_declined', async () => {
    const service = await makeService(150);
    const b = await Booking.create(bookingBase({ service: service._id, paymentMethod: 'cash' }));

    const out = await svc.submit(b._id, b.worker, {
      outcome: 'customer_declined_work',
      declineReason: 'Customer changed their mind after inspection.',
    });

    expect(out.status).toBe('customer_declined');
    expect(out.completionOutcome.outcome).toBe('customer_declined_work');

    const payment = await Payment.findOne({ booking: b._id });
    expect(payment).toBeNull();
  });

  test('online held payment: settles exactly money(service.inspectionFee), releases payment, audits callout_fee_captured', async () => {
    const service = await makeService(150);
    const user = id();
    const worker = id();
    const card = await SavedCard.create({ userId: user, last4: '4242', expiry: '12/30', cardType: 'visa' });

    const booking = await Booking.create({
      user,
      worker,
      service: service._id,
      serviceCategory: 'plumbing',
      scheduledDate: new Date(Date.now() + 86400000),
      address: '1 Test St',
      status: 'pending',
      paymentMethod: 'online',
      estimatedTotal: 330,
      totalPrice: 300,
      platformFeeAmount: 30,
      holdCeiling: 700,
      platformFeeRate: 10,
    });

    await paymentService.holdPayment(booking._id, user, { savedCardId: card._id });
    await Booking.findByIdAndUpdate(booking._id, { status: 'in_progress' });

    const out = await svc.submit(booking._id, worker, {
      outcome: 'customer_declined_work',
      declineReason: 'Job site inaccessible; customer declined to proceed after inspection.',
    });

    expect(out.status).toBe('customer_declined');
    expect(out.paymentStatus).toBe('released');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.capturedAmount).toBe(money(150));

    // MONEY-LEAK REGRESSION GUARD: a declined booking has NO labor invoice
    // (booking.subtotal/platformFee/grandTotal are unset), so the worker earning
    // must be derived from what was actually CAPTURED (the inspectionFee, 150),
    // not fall through to the original held estimate (payment.workerEarning was
    // seeded to booking.totalPrice = 300 at hold time). Before the fix this
    // over-credited the worker by 150 (the full original estimate) for a job that
    // never happened beyond the callout.
    expect(payment.workerEarning).toBe(150);

    const actions = await AdminAction.find({ targetType: 'payment', targetId: payment._id, actionType: 'callout_fee_captured' });
    expect(actions.length).toBe(1);
    expect(actions[0].details.bookingId.toString()).toBe(booking._id.toString());
  });

  test('inspectionFee = 0: terminal customer_declined, nothing captured, payment stays held', async () => {
    const service = await makeService(0);
    const user = id();
    const worker = id();
    const card = await SavedCard.create({ userId: user, last4: '4242', expiry: '12/30', cardType: 'visa' });

    const booking = await Booking.create({
      user,
      worker,
      service: service._id,
      serviceCategory: 'plumbing',
      scheduledDate: new Date(Date.now() + 86400000),
      address: '1 Test St',
      status: 'pending',
      paymentMethod: 'online',
      estimatedTotal: 330,
      totalPrice: 300,
      platformFeeAmount: 30,
      holdCeiling: 700,
      platformFeeRate: 10,
    });

    await paymentService.holdPayment(booking._id, user, { savedCardId: card._id });
    await Booking.findByIdAndUpdate(booking._id, { status: 'in_progress' });

    const out = await svc.submit(booking._id, worker, {
      outcome: 'customer_declined_work',
      declineReason: 'Customer declined; no inspection fee configured.',
    });

    expect(out.status).toBe('customer_declined');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('held');
    expect(payment.capturedAmount).toBeFalsy();
  });

  test('no service on booking: terminal customer_declined, nothing captured', async () => {
    const user = id();
    const worker = id();
    const card = await SavedCard.create({ userId: user, last4: '4242', expiry: '12/30', cardType: 'visa' });

    const booking = await Booking.create({
      user,
      worker,
      serviceCategory: 'plumbing',
      scheduledDate: new Date(Date.now() + 86400000),
      address: '1 Test St',
      status: 'pending',
      paymentMethod: 'online',
      estimatedTotal: 330,
      totalPrice: 300,
      platformFeeAmount: 30,
      holdCeiling: 700,
      platformFeeRate: 10,
    });

    await paymentService.holdPayment(booking._id, user, { savedCardId: card._id });
    await Booking.findByIdAndUpdate(booking._id, { status: 'in_progress' });

    const out = await svc.submit(booking._id, worker, {
      outcome: 'customer_declined_work',
      declineReason: 'Customer declined; booking has no service ref.',
    });

    expect(out.status).toBe('customer_declined');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('held');
    expect(payment.capturedAmount).toBeFalsy();
  });

  test('PRODUCT BUG: no cash debt — worker wallet is credited the full callout earning', async () => {
    const service = await makeService(150);
    const user = id();
    const worker = id();
    const card = await SavedCard.create({ userId: user, last4: '4242', expiry: '12/30', cardType: 'visa' });

    const booking = await Booking.create({
      user,
      worker,
      service: service._id,
      serviceCategory: 'plumbing',
      scheduledDate: new Date(Date.now() + 86400000),
      address: '1 Test St',
      status: 'pending',
      paymentMethod: 'online',
      estimatedTotal: 330,
      totalPrice: 300,
      platformFeeAmount: 30,
      holdCeiling: 700,
      platformFeeRate: 10,
    });

    await paymentService.holdPayment(booking._id, user, { savedCardId: card._id });
    await Booking.findByIdAndUpdate(booking._id, { status: 'in_progress' });

    // Sanity: holdPayment pre-creates the wallet (pendingBalance), but balance is
    // still 0 and there's definitely no cash debt yet.
    const walletBeforeSubmit = await Wallet.findOne({ worker });
    expect(walletBeforeSubmit.balance).toBe(0);
    expect(await CashDebt.findOne({ worker })).toBeNull();

    const out = await svc.submit(booking._id, worker, {
      outcome: 'customer_declined_work',
      declineReason: 'Job site inaccessible; customer declined to proceed after inspection.',
    });

    expect(out.status).toBe('customer_declined');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.workerEarning).toBe(150); // no platformFee on a declined booking (no invoice)

    // THE BUG: settleToAmount settles debts (none here) but never credited the
    // wallet with the remainder. The worker MUST receive the full callout
    // earning of 150 since there is no debt to offset.
    const wallet = await Wallet.findOne({ worker });
    expect(wallet).not.toBeNull();
    expect(wallet.balance).toBe(150);
  });

  test('PRODUCT BUG (debt-offset): outstanding cash debt is paid first, remainder credited to wallet', async () => {
    const service = await makeService(150);
    const user = id();
    const worker = id();
    const card = await SavedCard.create({ userId: user, last4: '4242', expiry: '12/30', cardType: 'visa' });

    const booking = await Booking.create({
      user,
      worker,
      service: service._id,
      serviceCategory: 'plumbing',
      scheduledDate: new Date(Date.now() + 86400000),
      address: '1 Test St',
      status: 'pending',
      paymentMethod: 'online',
      estimatedTotal: 330,
      totalPrice: 300,
      platformFeeAmount: 30,
      holdCeiling: 700,
      platformFeeRate: 10,
    });

    // Worker owes 50 from a prior cash-paid booking's platform fee.
    const priorBooking = await Booking.create(bookingBase({ service: service._id, paymentMethod: 'cash', worker }));
    await CashDebt.create({
      worker,
      booking: priorBooking._id,
      amount: 50,
      debtType: 'platform_fee',
      status: 'outstanding',
    });

    await paymentService.holdPayment(booking._id, user, { savedCardId: card._id });
    await Booking.findByIdAndUpdate(booking._id, { status: 'in_progress' });

    const out = await svc.submit(booking._id, worker, {
      outcome: 'customer_declined_work',
      declineReason: 'Customer declined after inspection; worker has an outstanding cash debt.',
    });

    expect(out.status).toBe('customer_declined');

    const payment = await Payment.findOne({ booking: booking._id });
    expect(payment.status).toBe('released');
    expect(payment.workerEarning).toBe(150);

    // Debt-first: 50 of the 150 callout earning pays down the debt...
    const debt = await CashDebt.findOne({ worker, booking: priorBooking._id });
    expect(debt.status).toBe('paid');
    expect(debt.paidAmount).toBe(50);
    expect(debt.remaining).toBe(0);

    // ...and the remaining 100 is credited to the worker's wallet.
    const wallet = await Wallet.findOne({ worker });
    expect(wallet).not.toBeNull();
    expect(wallet.balance).toBe(100);
  });

  test('claimable from arrived status too', async () => {
    const service = await makeService(150);
    const b = await Booking.create(bookingBase({ service: service._id, paymentMethod: 'cash', status: 'arrived' }));

    const out = await svc.submit(b._id, b.worker, {
      outcome: 'customer_declined_work',
      declineReason: 'Declined on arrival before any work started.',
    });

    expect(out.status).toBe('customer_declined');
  });
});
