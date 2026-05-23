'use strict';

jest.mock('../src/modules/bookings/booking.model');
jest.mock('../src/modules/payments/payment.model');
jest.mock('../src/modules/payments/dispute.model');
jest.mock('../src/modules/payments/cash-debt.model');
jest.mock('../src/modules/payments/transaction.model');
jest.mock('../src/modules/payments/payment.service', () => ({
  refundPayment: jest.fn(),
  releaseHeldPayment: jest.fn(),
}));
jest.mock('../src/modules/notifications/notification.service', () => ({
  notifyDisputeOpened: jest.fn().mockResolvedValue(undefined),
  notifyDisputeResolved: jest.fn(),
}));

const Booking = require('../src/modules/bookings/booking.model');
const Payment = require('../src/modules/payments/payment.model');
const Dispute = require('../src/modules/payments/dispute.model');
const CashDebt = require('../src/modules/payments/cash-debt.model');
const Transaction = require('../src/modules/payments/transaction.model');
const paymentService = require('../src/modules/payments/payment.service');
const disputeService = require('../src/modules/payments/dispute.service');

const BOOKING_ID = '664000000000000000000001';
const USER_ID = '664000000000000000000002';
const WORKER_ID = '664000000000000000000003';
const ADMIN_ID = '664000000000000000000004';

function makeBooking(overrides = {}) {
  return {
    _id: BOOKING_ID,
    user: { toString: () => USER_ID },
    worker: { toString: () => WORKER_ID },
    status: 'awaiting_customer_confirmation',
    paymentMethod: 'online',
    platformFeeAmount: 40,
    save: jest.fn().mockResolvedValue(true),
    ...overrides,
  };
}

function queryResult(value) {
  return {
    populate: jest.fn().mockReturnThis(),
    then: (resolve) => resolve(value),
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  Booking.findById = jest.fn().mockResolvedValue(makeBooking());
  Booking.findByIdAndUpdate = jest.fn().mockResolvedValue(true);
  Payment.findOne = jest.fn().mockResolvedValue({
    _id: 'payment1',
    status: 'held',
    amount: 440,
    currency: 'egp',
    save: jest.fn().mockResolvedValue(true),
  });
  Dispute.findOne = jest.fn().mockResolvedValue(null);
  Dispute.create = jest.fn().mockImplementation(async (data) => ({
    _id: 'dispute1',
    ...data,
    toObject: () => ({ _id: 'dispute1', ...data }),
  }));
  Transaction.create = jest.fn().mockResolvedValue(true);
});

describe('disputeService.openDispute', () => {
  test('opens online dispute and marks booking/payment as disputed', async () => {
    const dispute = await disputeService.openDispute(
      BOOKING_ID,
      USER_ID,
      'The service was left incomplete and needs support review.',
      ['https://example.com/evidence.jpg'],
      'incomplete'
    );

    expect(Payment.findOne).toHaveBeenCalledWith({ booking: BOOKING_ID });
    expect(Booking.findByIdAndUpdate).toHaveBeenCalledWith(BOOKING_ID, {
      status: 'disputed',
      paymentStatus: 'disputed',
    });
    expect(Transaction.create).toHaveBeenCalledWith(expect.objectContaining({ type: 'dispute' }));
    expect(Dispute.create).toHaveBeenCalledWith(expect.objectContaining({
      booking: BOOKING_ID,
      payment: 'payment1',
      category: 'incomplete',
      evidence: expect.arrayContaining([
        expect.objectContaining({ url: 'https://example.com/evidence.jpg' }),
      ]),
    }));
    expect(dispute._id).toBe('dispute1');
  });

  test('opens cash dispute without requiring payment', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeBooking({ paymentMethod: 'cash' }));

    await disputeService.openDispute(
      BOOKING_ID,
      USER_ID,
      'The technician did not finish the work and I need support.',
      [],
      'quality'
    );

    expect(Payment.findOne).not.toHaveBeenCalled();
    expect(Transaction.create).not.toHaveBeenCalled();
    expect(Booking.findByIdAndUpdate).toHaveBeenCalledWith(BOOKING_ID, {
      status: 'disputed',
      paymentStatus: 'disputed',
    });
  });

  test('rejects duplicate active dispute', async () => {
    Dispute.findOne = jest.fn().mockResolvedValue({ _id: 'existing' });

    await expect(
      disputeService.openDispute(BOOKING_ID, USER_ID, 'The job has a serious issue that needs review.')
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  test('rejects non-disputable booking status', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeBooking({ status: 'completed' }));

    await expect(
      disputeService.openDispute(BOOKING_ID, USER_ID, 'The job has a serious issue that needs review.')
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  test('rejects during-work operational issues as payment disputes', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeBooking({ status: 'in_progress' }));

    await expect(
      disputeService.openDispute(BOOKING_ID, USER_ID, 'The technician is late or there is an operational issue.')
    ).rejects.toMatchObject({ statusCode: 400 });
  });
});

describe('disputeService.markDisputeReviewing', () => {
  test('moves an active dispute into review', async () => {
    const dispute = {
      _id: 'dispute1',
      status: 'open',
      history: [],
      save: jest.fn().mockResolvedValue(true),
    };
    Dispute.findById = jest.fn().mockReturnValue(queryResult(dispute));

    await disputeService.markDisputeReviewing('dispute1');

    expect(dispute.status).toBe('reviewing');
    expect(dispute.save).toHaveBeenCalled();
  });

  test('does not reopen a resolved dispute for review', async () => {
    const dispute = {
      _id: 'dispute1',
      status: 'resolved_refund',
      save: jest.fn().mockResolvedValue(true),
    };
    Dispute.findById = jest.fn().mockReturnValue(queryResult(dispute));

    await expect(disputeService.markDisputeReviewing('dispute1')).rejects.toMatchObject({ statusCode: 400 });
    expect(dispute.save).not.toHaveBeenCalled();
  });
});

describe('disputeService.resolveDispute', () => {
  test('resolves cash dispute as refund without touching payment service', async () => {
    const booking = makeBooking({ paymentMethod: 'cash', status: 'disputed' });
    const dispute = {
      _id: 'dispute1',
      status: 'open',
      booking,
      payment: null,
      history: [],
      internalNotes: [],
      save: jest.fn().mockResolvedValue(true),
    };
    Dispute.findById = jest.fn().mockReturnValue(queryResult(dispute));

    await disputeService.resolveDispute('dispute1', ADMIN_ID, {
      resolution: 'Customer evidence accepted.',
      decision: 'refund',
    });

    expect(paymentService.refundPayment).not.toHaveBeenCalled();
    expect(booking.status).toBe('cancelled');
    expect(booking.paymentStatus).toBe('not_required');
    expect(dispute.status).toBe('resolved_refund');
    expect(dispute.decision).toBe('refund');
    expect(dispute.save).toHaveBeenCalled();
  });

  test('resolves online dispute as refund through payment service', async () => {
    const booking = makeBooking({ status: 'disputed' });
    const dispute = {
      _id: 'dispute1',
      status: 'open',
      booking,
      payment: { _id: { toString: () => 'payment1' }, amount: 440 },
      history: [],
      internalNotes: [],
      save: jest.fn().mockResolvedValue(true),
    };
    Dispute.findById = jest.fn().mockReturnValue(queryResult(dispute));
    paymentService.refundPayment.mockResolvedValue(true);

    await disputeService.resolveDispute('dispute1', ADMIN_ID, {
      resolution: 'Refund approved.',
      decision: 'refund',
    });

    expect(paymentService.refundPayment).toHaveBeenCalledWith('payment1', ADMIN_ID, 'Refund approved.');
    expect(dispute.status).toBe('resolved_refund');
  });
});
