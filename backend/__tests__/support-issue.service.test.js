'use strict';

jest.mock('../src/modules/bookings/booking.model');
jest.mock('../src/modules/support/support-issue.model');
jest.mock('../src/modules/payments/dispute.service', () => ({
  openDispute: jest.fn(),
}));
jest.mock('../src/modules/notifications/notification.service', () => ({
  notifySupportIssueOpened: jest.fn().mockResolvedValue(undefined),
  notifySupportIssueUpdated: jest.fn().mockResolvedValue(undefined),
  notifySupportIssueResolved: jest.fn().mockResolvedValue(undefined),
}));

const Booking = require('../src/modules/bookings/booking.model');
const SupportIssue = require('../src/modules/support/support-issue.model');
const disputeService = require('../src/modules/payments/dispute.service');
const supportIssueService = require('../src/modules/support/support-issue.service');

const BOOKING_ID = '664000000000000000000001';
const USER_ID = '664000000000000000000002';
const WORKER_ID = '664000000000000000000003';
const ADMIN_ID = '664000000000000000000004';

function makeBooking(overrides = {}) {
  return {
    _id: BOOKING_ID,
    user: { toString: () => USER_ID },
    worker: { toString: () => WORKER_ID },
    status: 'accepted',
    updatedAt: new Date(),
    save: jest.fn().mockResolvedValue(true),
    ...overrides,
  };
}

function queryResult(value) {
  return {
    populate: jest.fn().mockReturnThis(),
    sort: jest.fn().mockReturnThis(),
    skip: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    then: (resolve) => resolve(value),
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  Booking.findById = jest.fn().mockResolvedValue(makeBooking());
  SupportIssue.findOne = jest.fn().mockResolvedValue(null);
  SupportIssue.create = jest.fn().mockImplementation(async (data) => ({ _id: 'issue1', ...data }));
  SupportIssue.findById = jest.fn().mockReturnValue(queryResult({
    _id: 'issue1',
    booking: makeBooking(),
    customer: { _id: USER_ID, name: 'Customer' },
    worker: { _id: WORKER_ID, name: 'Worker' },
    type: 'late',
    status: 'open',
    priority: 'high',
    description: 'Technician is late and I need help from support.',
    evidence: [],
    save: jest.fn().mockResolvedValue(true),
  }));
  SupportIssue.find = jest.fn().mockReturnValue(queryResult([]));
  SupportIssue.countDocuments = jest.fn().mockResolvedValue(0);
});

describe('supportIssueService.createIssue', () => {
  test('creates late support issue without changing booking or payment state', async () => {
    const issue = await supportIssueService.createIssue(USER_ID, {
      bookingId: BOOKING_ID,
      type: 'late',
      description: 'Technician is late and I need help from support.',
      evidence: ['https://example.com/proof.jpg'],
    });

    expect(SupportIssue.create).toHaveBeenCalledWith(expect.objectContaining({
      booking: BOOKING_ID,
      customer: USER_ID,
      worker: expect.any(Object),
      type: 'late',
      priority: 'high',
      evidence: ['https://example.com/proof.jpg'],
    }));
    expect(disputeService.openDispute).not.toHaveBeenCalled();
    expect(issue._id).toBe('issue1');
  });

  test('blocks support issue for someone else booking', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeBooking({ user: { toString: () => 'other-user' } }));

    await expect(supportIssueService.createIssue(USER_ID, {
      bookingId: BOOKING_ID,
      type: 'late',
      description: 'Technician is late and I need help from support.',
    })).rejects.toMatchObject({ statusCode: 403 });
  });

  test('marks safety issue urgent during work', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeBooking({ status: 'in_progress' }));

    await supportIssueService.createIssue(USER_ID, {
      bookingId: BOOKING_ID,
      type: 'safety',
      description: 'There is a safety issue happening during the work.',
    });

    expect(SupportIssue.create).toHaveBeenCalledWith(expect.objectContaining({
      type: 'safety',
      priority: 'urgent',
    }));
  });

  test('allows completed booking issue inside 48 hours', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeBooking({
      status: 'completed',
      updatedAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
    }));

    await supportIssueService.createIssue(USER_ID, {
      bookingId: BOOKING_ID,
      type: 'post_completion',
      description: 'I found a problem after the completed service.',
    });

    expect(SupportIssue.create).toHaveBeenCalledWith(expect.objectContaining({ type: 'post_completion' }));
  });

  test('rejects completed booking issue after 48 hours', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeBooking({
      status: 'completed',
      updatedAt: new Date(Date.now() - 72 * 60 * 60 * 1000),
    }));

    await expect(supportIssueService.createIssue(USER_ID, {
      bookingId: BOOKING_ID,
      type: 'post_completion',
      description: 'I found a problem after the completed service.',
    })).rejects.toMatchObject({ statusCode: 400 });
  });
});

describe('supportIssueService.escalateToDispute', () => {
  test('escalates only completion-review support issue to dispute', async () => {
    const issue = {
      _id: 'issue1',
      booking: { _id: BOOKING_ID, status: 'awaiting_customer_confirmation' },
      customer: { _id: USER_ID },
      worker: { _id: WORKER_ID },
      type: 'other',
      description: 'The completed service needs payment review.',
      evidence: [],
      save: jest.fn().mockResolvedValue(true),
    };
    SupportIssue.findById = jest.fn().mockReturnValue(queryResult(issue));
    disputeService.openDispute.mockResolvedValue({ _id: 'dispute1' });

    const result = await supportIssueService.escalateToDispute('issue1', ADMIN_ID);

    expect(disputeService.openDispute).toHaveBeenCalledWith(
      BOOKING_ID,
      USER_ID,
      'The completed service needs payment review.',
      [],
      'other'
    );
    expect(issue.status).toBe('closed');
    expect(result.dispute._id).toBe('dispute1');
  });
});
