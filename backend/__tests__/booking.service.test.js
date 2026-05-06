'use strict';

jest.mock('../src/modules/users/user.model.js');
jest.mock('../src/modules/services/service.model.js');
jest.mock('../src/modules/bookings/booking.model.js');

const User    = require('../src/modules/users/user.model.js');
const Service = require('../src/modules/services/service.model.js');
const Booking = require('../src/modules/bookings/booking.model.js');
const { createBooking } = require('../src/modules/bookings/booking.service.js');

const PLUMBING_SERVICE_ID = '664000000000000000000001';
const HVAC_SERVICE_ID     = '664000000000000000000002';
const WORKER_ID           = '664000000000000000000010';
const USER_ID             = '664000000000000000000020';

// Compute next occurrence of a given weekday (0=Sun, 1=Mon, ...) using UTC to
// match the service layer which uses getUTCDay() for schedule validation.
function nextWeekday(targetDay) {
  const now = new Date();
  // Work entirely in UTC milliseconds to avoid local-timezone date shifts
  const todayUTC = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const currentUTCDay = new Date(todayUTC).getUTCDay();
  const diff = (targetDay - currentUTCDay + 7) % 7 || 7;
  const resultUTC = new Date(todayUTC + diff * 86400000);
  return resultUTC.toISOString().split('T')[0]; // YYYY-MM-DD
}
const NEXT_MONDAY  = nextWeekday(1);
const NEXT_TUESDAY = nextWeekday(2);

const makeService = (overrides = {}) => ({
  _id:       { toString: () => PLUMBING_SERVICE_ID },
  title:     'Plumbing',
  category:  'plumbing',
  basePrice: 300,
  isActive:  true,
  ...overrides,
});

// Updated: includes isAvailable + availability so new validation chain passes
const makeWorker = (overrides = {}) => ({
  _id:          WORKER_ID,
  role:         'worker',
  isActive:     true,
  isVerified:   true,
  isAvailable:  true,
  availability: [{ day: 'monday', from: '09:00', to: '17:00' }],
  services:     [{ toString: () => PLUMBING_SERVICE_ID }],
  categories:   ['plumbing'],
  ...overrides,
});

// Updated: near-future weekday + scheduledTime so new validation chain passes
const baseBookingData = {
  workerId:      WORKER_ID,
  serviceId:     PLUMBING_SERVICE_ID,
  scheduledDate: NEXT_MONDAY,
  scheduledTime: '10:00',
  address:       '12 Tahrir St, Cairo',
};

beforeEach(() => {
  jest.clearAllMocks();
  User.findOne    = jest.fn().mockResolvedValue(makeWorker());
  Service.findOne = jest.fn().mockResolvedValue(makeService());
  Booking.findOne = jest.fn().mockResolvedValue(null);
  Booking.create  = jest.fn().mockResolvedValue({
    ...baseBookingData,
    _id: 'booking123',
    populate: jest.fn().mockResolvedValue({ _id: 'booking123', status: 'pending' }),
  });
});

// ── Worker-service validation (existing 6 tests — preserved) ─────────────────
describe('createBooking — worker-service validation', () => {
  test('succeeds when worker.services contains the selected service ID', async () => {
    const result = await createBooking(USER_ID, baseBookingData);
    expect(result).toBeDefined();
    expect(Booking.create).toHaveBeenCalledTimes(1);
  });

  test('succeeds via legacy categories when worker.services is empty', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({ services: [], categories: ['plumbing'] })
    );
    const result = await createBooking(USER_ID, baseBookingData);
    expect(result).toBeDefined();
    expect(Booking.create).toHaveBeenCalledTimes(1);
  });

  test('fails when worker does not support the selected service', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({ services: [{ toString: () => HVAC_SERVICE_ID }], categories: ['hvac'] })
    );
    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: 400,
      message:    expect.stringContaining('does not support this service'),
    });
    expect(Booking.create).not.toHaveBeenCalled();
  });

  test('fails when worker is not found', async () => {
    User.findOne = jest.fn().mockResolvedValue(null);
    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: 404,
      message:    expect.stringContaining('Worker not found'),
    });
  });

  test('fails when service is not found', async () => {
    Service.findOne = jest.fn().mockResolvedValue(null);
    await expect(createBooking(USER_ID, baseBookingData)).rejects.toMatchObject({
      statusCode: 404,
      message:    expect.stringContaining('Service not found'),
    });
  });

  test('booking is created with correct user, worker, service fields', async () => {
    await createBooking(USER_ID, baseBookingData);
    expect(Booking.create).toHaveBeenCalledWith(
      expect.objectContaining({ user: USER_ID, worker: WORKER_ID, service: PLUMBING_SERVICE_ID })
    );
  });
});

// ── 3a: Worker gate ───────────────────────────────────────────────────────────
describe('createBooking — worker gate', () => {
  test('throws 400 when worker.isAvailable is false', async () => {
    User.findOne = jest.fn().mockResolvedValue(makeWorker({ isAvailable: false }));
    await expect(createBooking(USER_ID, baseBookingData))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('not currently accepting') });
  });
});

// ── 3b: Date range ────────────────────────────────────────────────────────────
describe('createBooking — date range', () => {
  test('throws 400 for a past date', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: '2020-01-01' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('today or in the future') });
  });

  test('throws 400 for a date more than 30 days ahead', async () => {
    const future = new Date();
    future.setDate(future.getDate() + 31);
    const futureStr = future.toISOString().split('T')[0];
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: futureStr }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('30 days in advance') });
  });
});

// ── 3c: Time provided ─────────────────────────────────────────────────────────
describe('createBooking — time provided', () => {
  test('throws 400 when scheduledTime is empty', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('time slot must be selected') });
  });
});

// ── 3d: Slot alignment ────────────────────────────────────────────────────────
describe('createBooking — slot alignment', () => {
  test('throws 400 for half-hour slot (09:30)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '09:30' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('Invalid time slot') });
  });

  test('throws 400 for out-of-range hour (99:00)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '99:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('Invalid time slot') });
  });
});

// ── Same-day past-time ────────────────────────────────────────────────────────
describe('createBooking — same-day past-time', () => {
  test('throws 400 when booking today at a slot that has already passed', async () => {
    // Worker with full-day schedule so only the same-day check fires (not working-hours)
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({
        availability: ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']
          .map(day => ({ day, from: '00:00', to: '23:00' })),
      })
    );
    // Use local date (not UTC) to match the service's same-day check which uses local midnight
    const now = new Date();
    const todayStr = now.getFullYear() + '-' +
      String(now.getMonth() + 1).padStart(2, '0') + '-' +
      String(now.getDate()).padStart(2, '0');
    // '00:00' is always <= current hour (tests never run at exactly local midnight)
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: todayStr, scheduledTime: '00:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('already started or passed') });
  });
});

// ── 3e: Day in schedule ───────────────────────────────────────────────────────
describe('createBooking — day in schedule', () => {
  test('throws 400 when the selected day is not in worker schedule', async () => {
    // baseWorker only has Monday; Tuesday is not in schedule
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledDate: NEXT_TUESDAY }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('not available on this day') });
  });
});

// ── 3f: Within working hours ─────────────────────────────────────────────────
describe('createBooking — working hours', () => {
  test('throws 400 when time is before working hours (08:00, window 09:00–17:00)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '08:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('outside technician') });
  });

  test('throws 400 when time equals toHour (17:00 with window ending 17:00)', async () => {
    await expect(createBooking(USER_ID, { ...baseBookingData, scheduledTime: '17:00' }))
      .rejects.toMatchObject({ statusCode: 400, message: expect.stringContaining('outside technician') });
  });
});

// ── 3g: Double-booking ───────────────────────────────────────────────────────
describe('createBooking — double-booking', () => {
  test('throws 409 when same worker+date+time slot is already booked', async () => {
    Booking.findOne = jest.fn().mockResolvedValue({ _id: 'existing-booking' });
    await expect(createBooking(USER_ID, baseBookingData))
      .rejects.toMatchObject({ statusCode: 409, message: expect.stringContaining('already booked') });
  });

  test('throws 409 on duplicate-key error (race condition safeguard)', async () => {
    const dupErr = Object.assign(new Error('duplicate key'), { code: 11000 });
    Booking.create = jest.fn().mockRejectedValue(dupErr);
    await expect(createBooking(USER_ID, baseBookingData))
      .rejects.toMatchObject({ statusCode: 409, message: expect.stringContaining('already booked') });
  });
});

// ── Success path ─────────────────────────────────────────────────────────────
describe('createBooking — success', () => {
  test('creates booking when all validation passes', async () => {
    await createBooking(USER_ID, baseBookingData);
    expect(Booking.create).toHaveBeenCalledWith(
      expect.objectContaining({ worker: WORKER_ID, scheduledTime: '10:00', address: '12 Tahrir St, Cairo' })
    );
  });
});
