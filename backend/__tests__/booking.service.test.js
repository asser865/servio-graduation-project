/**
 * Unit tests for booking.service.js — worker-service validation logic.
 *
 * All Mongoose model methods are mocked so no real database connection is needed.
 */

'use strict';

const { StatusCodes } = require('http-status-codes');

// ── Mock Mongoose models before requiring the service ────────────────────────
jest.mock('../src/modules/bookings/booking.model');
jest.mock('../src/modules/services/service.model');
jest.mock('../src/modules/users/user.model');

const Booking = require('../src/modules/bookings/booking.model');
const Service = require('../src/modules/services/service.model');
const User    = require('../src/modules/users/user.model');

const { createBooking } = require('../src/modules/bookings/booking.service');

// ── Helpers ──────────────────────────────────────────────────────────────────

const PLUMBING_SERVICE_ID = '664000000000000000000001';
const HVAC_SERVICE_ID     = '664000000000000000000002';
const WORKER_ID           = '664000000000000000000010';
const USER_ID             = '664000000000000000000020';

const makeService = (overrides = {}) => ({
  _id:      { toString: () => PLUMBING_SERVICE_ID },
  title:    'Plumbing',
  category: 'plumbing',
  basePrice: 300,
  isActive:  true,
  ...overrides,
});

const makeWorker = (overrides = {}) => ({
  _id:        { toString: () => WORKER_ID },
  role:       'worker',
  isActive:   true,
  isVerified: true,
  services:   [{ toString: () => PLUMBING_SERVICE_ID }],
  categories: ['plumbing'],
  ...overrides,
});

const baseBookingData = {
  workerId:      WORKER_ID,
  serviceId:     PLUMBING_SERVICE_ID,
  scheduledDate: '2026-07-01T10:00:00.000Z',
  address:       '12 Tahrir St, Cairo',
};

beforeEach(() => {
  jest.clearAllMocks();

  // Default: Booking.create returns a booking-like object that supports .populate()
  Booking.create = jest.fn().mockResolvedValue({
    populate: jest.fn().mockResolvedValue({ _id: 'booking1', status: 'pending' }),
  });
});

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('createBooking — worker-service validation', () => {
  test('succeeds when worker.services contains the selected service ID', async () => {
    User.findOne = jest.fn().mockResolvedValue(makeWorker());
    Service.findOne = jest.fn().mockResolvedValue(makeService());

    const result = await createBooking(USER_ID, baseBookingData);
    expect(result).toBeDefined();
    expect(Booking.create).toHaveBeenCalledTimes(1);
  });

  test('succeeds via legacy categories when worker.services is empty', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({ services: [], categories: ['plumbing'] })
    );
    Service.findOne = jest.fn().mockResolvedValue(makeService({ category: 'plumbing' }));

    const result = await createBooking(USER_ID, baseBookingData);
    expect(result).toBeDefined();
    expect(Booking.create).toHaveBeenCalledTimes(1);
  });

  test('fails when worker does not support the selected service', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({
        services:   [{ toString: () => HVAC_SERVICE_ID }],
        categories: ['hvac'],
      })
    );
    Service.findOne = jest.fn().mockResolvedValue(makeService({ category: 'plumbing' }));

    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: StatusCodes.BAD_REQUEST,
      message:    expect.stringContaining('does not support this service'),
    });
    expect(Booking.create).not.toHaveBeenCalled();
  });

  test('fails when worker is not found', async () => {
    User.findOne = jest.fn().mockResolvedValue(null);
    Service.findOne = jest.fn().mockResolvedValue(makeService());

    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: StatusCodes.NOT_FOUND,
      message:    expect.stringContaining('Worker not found'),
    });
  });

  test('fails when service is not found', async () => {
    User.findOne = jest.fn().mockResolvedValue(makeWorker());
    Service.findOne = jest.fn().mockResolvedValue(null);

    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: StatusCodes.NOT_FOUND,
      message:    expect.stringContaining('Service not found'),
    });
  });

  test('booking is created with correct user, worker, service fields', async () => {
    User.findOne = jest.fn().mockResolvedValue(makeWorker());
    Service.findOne = jest.fn().mockResolvedValue(makeService());

    await createBooking(USER_ID, baseBookingData);

    expect(Booking.create).toHaveBeenCalledWith(
      expect.objectContaining({
        user:    USER_ID,
        worker:  WORKER_ID,
        service: PLUMBING_SERVICE_ID,
      })
    );
  });
});
