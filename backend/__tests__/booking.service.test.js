'use strict';

jest.mock('../src/modules/users/user.model.js');
jest.mock('../src/modules/services/service.model.js');
jest.mock('../src/modules/bookings/booking.model.js');
jest.mock('../src/modules/savedCards/savedCard.model.js');
jest.mock('../src/modules/admin/settings.model.js');

const User    = require('../src/modules/users/user.model.js');
const Service = require('../src/modules/services/service.model.js');
const Booking = require('../src/modules/bookings/booking.model.js');
const SavedCard = require('../src/modules/savedCards/savedCard.model.js');
const Settings = require('../src/modules/admin/settings.model.js');
const { createBooking, rescheduleBooking, updateBookingStatus } = require('../src/modules/bookings/booking.service.js');

const PLUMBING_SERVICE_ID = '664000000000000000000001';
const HVAC_SERVICE_ID     = '664000000000000000000002';
const WORKER_ID           = '664000000000000000000010';
const USER_ID             = '664000000000000000000020';
const CARD_ID             = '664000000000000000000030';

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
  paymentMethod: 'cash',
};

beforeEach(() => {
  jest.clearAllMocks();
  jest.restoreAllMocks();
  User.findOne    = jest.fn().mockResolvedValue(makeWorker());
  Service.findOne = jest.fn().mockResolvedValue(makeService());
  Booking.findOne = jest.fn().mockReturnValue({
    session: () => Promise.resolve(null),
  });
  Settings.findOne = jest.fn().mockResolvedValue({ commissionRate: 10, cashPaymentsEnabled: true, travelBufferMin: 30 });
  Booking.create  = jest.fn().mockImplementation(async (input) => {
    const isArrayInput = Array.isArray(input);
    const doc = isArrayInput ? input[0] : input;
    const result = {
      ...doc,
      _id: 'booking123',
      populate: jest.fn().mockResolvedValue({ _id: 'booking123', status: 'pending', ...doc }),
    };
    return isArrayInput ? [result] : result;
  });
  SavedCard.findOne = jest.fn().mockResolvedValue({
    _id: CARD_ID,
    userId: USER_ID,
    last4: '4242',
    expiry: '12/30',
    cardType: 'visa',
    label: 'Personal',
  });

  const mongoose = require('mongoose');
  jest.spyOn(mongoose, 'startSession').mockResolvedValue({
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    abortTransaction: jest.fn(),
    endSession: jest.fn(),
    inTransaction: () => true,
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
      [expect.objectContaining({
        user: USER_ID,
        worker: WORKER_ID,
        service: PLUMBING_SERVICE_ID,
        paymentMethod: 'cash',
      })],
      expect.objectContaining({ session: expect.anything() })
    );
  });
});

describe('createBooking â€” payment validation', () => {
  test('creates booking with cash without a saved card', async () => {
    await createBooking(USER_ID, baseBookingData);
    expect(SavedCard.findOne).not.toHaveBeenCalled();
    expect(Booking.create).toHaveBeenCalledWith(
      [expect.objectContaining({
        paymentMethod: 'cash',
        savedCard: undefined,
      })],
      expect.objectContaining({ session: expect.anything() })
    );
  });

  test('creates booking with a saved card owned by the customer', async () => {
    await createBooking(USER_ID, {
      ...baseBookingData,
      paymentMethod: 'card',
      savedCardId: CARD_ID,
    });

    expect(SavedCard.findOne).toHaveBeenCalledWith({
      _id: CARD_ID,
      userId: USER_ID,
    });
    expect(Booking.create).toHaveBeenCalledWith(
      [expect.objectContaining({
        paymentMethod: 'card',
        savedCard: CARD_ID,
        paymentMeta: {
          last4: '4242',
          cardType: 'visa',
          label: 'Personal',
        },
      })],
      expect.objectContaining({ session: expect.anything() })
    );
  });

  test('fails card booking when no saved card ID is supplied', async () => {
    await expect(createBooking(USER_ID, {
      ...baseBookingData,
      paymentMethod: 'card',
    })).rejects.toMatchObject({
      statusCode: 400,
      message: expect.stringContaining('saved card is required'),
    });
    expect(Booking.create).not.toHaveBeenCalled();
  });

  test('fails card booking when saved card is not owned by customer', async () => {
    SavedCard.findOne = jest.fn().mockResolvedValue(null);
    await expect(createBooking(USER_ID, {
      ...baseBookingData,
      paymentMethod: 'card',
      savedCardId: CARD_ID,
    })).rejects.toMatchObject({
      statusCode: 403,
      message: expect.stringContaining('Saved card not found'),
    });
    expect(Booking.create).not.toHaveBeenCalled();
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
    Booking.findOne = jest.fn().mockReturnValue({
      session: () => Promise.resolve({ _id: 'existing-conflict' }),
    });
    await expect(createBooking(USER_ID, baseBookingData))
      .rejects.toMatchObject({ statusCode: 409, message: expect.stringMatching(/already|overlap/i) });
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
    expect(Booking.create.mock.calls[0][0][0]).toEqual(
      expect.objectContaining({ worker: WORKER_ID, scheduledTime: '10:00', address: '12 Tahrir St, Cairo', paymentMethod: 'cash' })
    );
  });

  test('snapshots platform fee and demo card metadata at creation time', async () => {
    Settings.findOne = jest.fn().mockResolvedValue({ commissionRate: 12.5, cashPaymentsEnabled: true });
    await createBooking(USER_ID, {
      ...baseBookingData,
      paymentMethod: 'online',
      paymentMeta: { last4: '4242', cardType: 'visa', expiry: '12/30', label: 'Demo Visa', cvv: '123' },
    });
    expect(Booking.create.mock.calls[0][0][0]).toEqual(
      expect.objectContaining({
        paymentMethod: 'online',
        paymentStatus: 'demo_pending',
        platformFeeRate: 12.5,
        platformFeeAmount: 37.5,
        estimatedTotal: 337.5,
        paymentMeta: expect.objectContaining({ last4: '4242', cardType: 'visa', expiry: '12/30', label: 'Demo Visa' }),
      })
    );
    expect(Booking.create.mock.calls[0][0][0].paymentMeta.cvv).toBeUndefined();
  });
});

describe('rescheduleBooking', () => {
  const makeExistingBooking = (overrides = {}) => ({
    _id: { toString: () => '664000000000000000000030' },
    user: { toString: () => USER_ID },
    worker: { toString: () => WORKER_ID },
    status: 'pending',
    ...overrides,
  });

  test('updates schedule for the booking owner when slot is valid', async () => {
    const populated = { _id: '664000000000000000000030', scheduledTime: '11:00' };
    const populateChain = {
      populate: jest.fn().mockReturnThis(),
      then: (resolve) => resolve(populated),
    };
    Booking.findById = jest.fn()
      .mockResolvedValueOnce(makeExistingBooking())
      .mockReturnValueOnce(populateChain);
    Booking.findByIdAndUpdate = jest.fn().mockResolvedValue({ _id: '664000000000000000000030' });
    Booking.findOne = jest.fn().mockReturnValue({
      session: () => Promise.resolve(null),
    });

    const result = await rescheduleBooking(
      '664000000000000000000030',
      { scheduledDate: NEXT_MONDAY, scheduledTime: '11:00' },
      USER_ID,
      'user'
    );

    expect(result).toBe(populated);
    expect(Booking.findOne).toHaveBeenCalledWith(expect.objectContaining({
      worker: expect.anything(),
      status: expect.objectContaining({ $in: expect.arrayContaining(['pending', 'accepted', 'en_route', 'arrived', 'in_progress']) }),
    }));
    expect(Booking.findByIdAndUpdate).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ scheduledTime: '11:00' }),
      expect.objectContaining({ new: true, runValidators: true })
    );
  });

  test('rejects reschedule after technician is en route', async () => {
    Booking.findById = jest.fn().mockResolvedValue(makeExistingBooking({ status: 'en_route' }));

    await expect(rescheduleBooking(
      '664000000000000000000030',
      { scheduledDate: NEXT_MONDAY, scheduledTime: '11:00' },
      USER_ID,
      'user'
    )).rejects.toMatchObject({
      statusCode: 400,
      message: expect.stringContaining('can no longer be rescheduled'),
    });
  });
});

describe('createBooking overlap enforcement', () => {
  test('rejects booking whose window overlaps an active booking', async () => {
    Booking.findOne = jest.fn().mockReturnValue({
      session: () => Promise.resolve({
        _id: 'existing',
        scheduledStart: new Date('2026-05-18T11:00:00Z'),
        scheduledEnd:   new Date('2026-05-18T12:30:00Z'),
      }),
    });
    Service.findOne = jest.fn().mockResolvedValue(makeService({ estimatedDurationMin: 60 }));
    Settings.findOne = jest.fn().mockResolvedValue({
      commissionRate: 10, cashPaymentsEnabled: true, travelBufferMin: 30,
    });

    await expect(createBooking(USER_ID, {
      ...baseBookingData,
      scheduledTime: '14:00',
    })).rejects.toThrow(/already|overlap/i);
  });

  test('allows non-overlapping booking', async () => {
    Booking.findOne = jest.fn().mockReturnValue({
      session: () => Promise.resolve(null),
    });
    Service.findOne = jest.fn().mockResolvedValue(makeService({ estimatedDurationMin: 30 }));
    Settings.findOne = jest.fn().mockResolvedValue({
      commissionRate: 10, cashPaymentsEnabled: true, travelBufferMin: 30,
    });

    const result = await createBooking(USER_ID, {
      ...baseBookingData,
      scheduledTime: '13:00',
    });
    expect(result).toBeDefined();
    expect(Booking.create).toHaveBeenCalledTimes(1);
    const createArgs = Booking.create.mock.calls[0][0][0];
    expect(createArgs.scheduledStart).toBeInstanceOf(Date);
    expect(createArgs.scheduledEnd).toBeInstanceOf(Date);
    expect(createArgs.estimatedDurationMin).toBe(30);
    expect(createArgs.travelBufferMin).toBe(30);
  });
});

describe('createBooking transactional guard', () => {
  test('starts a session and aborts on conflict mid-transaction', async () => {
    const mongoose = require('mongoose');
    const mockSession = {
      startTransaction: jest.fn(),
      commitTransaction: jest.fn(),
      abortTransaction:  jest.fn(),
      endSession:        jest.fn(),
      inTransaction:     () => true,
    };
    jest.spyOn(mongoose, 'startSession').mockResolvedValue(mockSession);

    // Make Booking.findOne(...).session(...) return an existing booking
    Booking.findOne = jest.fn().mockReturnValue({
      session: () => Promise.resolve({
        _id: 'existing',
        scheduledStart: new Date('2026-05-18T11:00:00Z'),
        scheduledEnd:   new Date('2026-05-18T12:30:00Z'),
      }),
    });
    Service.findOne = jest.fn().mockResolvedValue(makeService({ estimatedDurationMin: 60 }));

    await expect(createBooking(USER_ID, {
      ...baseBookingData,
      scheduledTime: '14:00',
    })).rejects.toThrow(/already|overlap/i);

    expect(mockSession.startTransaction).toHaveBeenCalled();
    expect(mockSession.abortTransaction).toHaveBeenCalled();
    expect(mockSession.endSession).toHaveBeenCalled();
  });
});

describe('worker accept-time duration override', () => {
  const makeBookingDoc = () => ({
    _id:                  'b1',
    status:               'pending',
    worker:               { toString: () => WORKER_ID },
    user:                 { toString: () => USER_ID },
    paymentMethod:        'cash',
    scheduledDate:        new Date(NEXT_MONDAY + 'T00:00:00Z'),
    scheduledTime:        '14:00',
    estimatedDurationMin: 60,
    travelBufferMin:      30,
    scheduledStart:       new Date('2026-05-18T11:00:00Z'),
    scheduledEnd:         new Date('2026-05-18T12:30:00Z'),
    save:                 jest.fn().mockResolvedValue(true),
  });

  test('applies override and rechecks overlap', async () => {
    const booking = makeBookingDoc();
    Booking.findById = jest.fn().mockResolvedValue(booking);
    Booking.findOne  = jest.fn().mockReturnValue({ session: jest.fn().mockResolvedValue(null) });
    // Also stub the non-session findOne used directly by override collision check
    const realFindOne = Booking.findOne;
    Booking.findOne = jest.fn().mockResolvedValue(null);
    Booking.findByIdAndUpdate = jest.fn().mockResolvedValue({ _id: 'b1', status: 'accepted' });

    await updateBookingStatus('b1', 'accepted', WORKER_ID, 'worker', { estimatedDurationMin: 120 });

    expect(booking.estimatedDurationMin).toBe(120);
    expect(booking.scheduledEnd.toISOString()).toBe('2026-05-18T13:30:00.000Z');
    expect(booking.save).toHaveBeenCalled();
  });

  test('rejects override that would collide with a later booking', async () => {
    const booking = makeBookingDoc();
    Booking.findById = jest.fn().mockResolvedValue(booking);
    Booking.findOne  = jest.fn().mockResolvedValue({ _id: 'b2' }); // simulate collision

    await expect(
      updateBookingStatus('b1', 'accepted', WORKER_ID, 'worker', { estimatedDurationMin: 120 })
    ).rejects.toThrow(/overlap|conflict|already/i);
  });
});

describe('in_progress lifecycle stamps', () => {
  test('stamps actualStartedAt and estimatedFinishAt on transition', async () => {
    const booking = {
      _id:                  'b1',
      status:               'arrived',
      worker:               { toString: () => WORKER_ID },
      user:                 { toString: () => USER_ID },
      paymentMethod:        'cash',
      estimatedDurationMin: 60,
      travelBufferMin:      30,
      actualStartedAt:      null,
      estimatedFinishAt:    null,
      save: jest.fn().mockResolvedValue(true),
    };
    Booking.findById = jest.fn().mockResolvedValue(booking);
    Booking.findByIdAndUpdate = jest.fn().mockResolvedValue({ _id: 'b1', status: 'in_progress' });

    const before = Date.now();
    await updateBookingStatus('b1', 'in_progress', WORKER_ID, 'worker', {});

    expect(booking.actualStartedAt).toBeInstanceOf(Date);
    expect(booking.actualStartedAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(booking.estimatedFinishAt.getTime() - booking.actualStartedAt.getTime()).toBe(60 * 60_000);
    expect(booking.save).toHaveBeenCalled();
  });
});
