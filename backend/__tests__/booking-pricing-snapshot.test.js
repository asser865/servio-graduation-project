'use strict';

// Task 6: Price compute + snapshots (Type A specific-service path).
// Mirrors the mocked-model convention used by booking.service.test.js — the
// only existing createBooking test suite — rather than a real-DB suite,
// since createBooking has no real-DB fixtures anywhere in the repo and the
// mocked approach is the established, working pattern for this function.

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
const { createBooking } = require('../src/modules/bookings/booking.service.js');

const PLUMBING_SERVICE_ID = '664000000000000000000001';
const WORKER_ID           = '664000000000000000000010';
const USER_ID             = '664000000000000000000020';

function nextWeekday(targetDay) {
  const now = new Date();
  const todayUTC = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  const currentUTCDay = new Date(todayUTC).getUTCDay();
  const diff = (targetDay - currentUTCDay + 7) % 7 || 7;
  const resultUTC = new Date(todayUTC + diff * 86400000);
  return resultUTC.toISOString().split('T')[0];
}
const NEXT_MONDAY = nextWeekday(1);

const makeService = (overrides = {}) => ({
  _id:       { toString: () => PLUMBING_SERVICE_ID },
  title:     'Plumbing',
  category:  'plumbing',
  basePrice: 300,
  isActive:  true,
  seedRange: { min: 300, max: 700 },
  ...overrides,
});

// worker.services is now subdoc shape [{ serviceId, startsFrom }] (Tasks 4+5)
const makeWorker = (overrides = {}) => ({
  _id:          WORKER_ID,
  role:         'worker',
  isActive:     true,
  isVerified:   true,
  isAvailable:  true,
  availability: [{ day: 'monday', from: '09:00', to: '17:00' }],
  services:     [{ serviceId: { toString: () => PLUMBING_SERVICE_ID }, startsFrom: 350 }],
  categories:   ['plumbing'],
  ...overrides,
});

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
  SavedCard.findOne = jest.fn().mockResolvedValue(null);

  const mongoose = require('mongoose');
  jest.spyOn(mongoose, 'startSession').mockResolvedValue({
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    abortTransaction: jest.fn(),
    endSession: jest.fn(),
    inTransaction: () => true,
  });
});

describe('createBooking — Type A specific-service price snapshots', () => {
  test('booking snapshots startsFrom + seedRange + holdCeiling from worker/service', async () => {
    await createBooking(USER_ID, baseBookingData);

    const createdDoc = Booking.create.mock.calls[0][0][0];
    expect(createdDoc.startsFromSnapshot).toBe(350);
    expect(createdDoc.seedRangeSnapshot).toEqual({ min: 300, max: 700 });
    expect(createdDoc.holdCeiling).toBe(700);
    expect(createdDoc.totalPrice).toBe(350);
  });

  test('falls back to service.basePrice when worker has no per-service startsFrom entry (legacy-category match)', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({ services: [], categories: ['plumbing'] })
    );
    await createBooking(USER_ID, baseBookingData);

    const createdDoc = Booking.create.mock.calls[0][0][0];
    expect(createdDoc.startsFromSnapshot).toBe(300); // service.basePrice fallback
    expect(createdDoc.totalPrice).toBe(300);
  });

  test('honors a legitimate startsFrom of 0 (does not fall back to basePrice)', async () => {
    User.findOne = jest.fn().mockResolvedValue(
      makeWorker({ services: [{ serviceId: { toString: () => PLUMBING_SERVICE_ID }, startsFrom: 0 }] })
    );
    await createBooking(USER_ID, baseBookingData);

    const createdDoc = Booking.create.mock.calls[0][0][0];
    expect(createdDoc.startsFromSnapshot).toBe(0);
    expect(createdDoc.totalPrice).toBe(0);
  });

  test('unseeded band degrades gracefully: holdCeiling is 0 when service.seedRange.max is 0, no hard reject', async () => {
    Service.findOne = jest.fn().mockResolvedValue(makeService({ seedRange: { min: 0, max: 0 } }));
    const result = await createBooking(USER_ID, baseBookingData);

    expect(result).toBeDefined();
    const createdDoc = Booking.create.mock.calls[0][0][0];
    expect(createdDoc.holdCeiling).toBe(0);
    expect(createdDoc.seedRangeSnapshot).toEqual({ min: 0, max: 0 });
    expect(createdDoc.estimatedTotal).toBeGreaterThan(0); // estimate + fee still set
  });

  test('category-only legacy path stays unchanged: no snapshot fields set', async () => {
    await createBooking(USER_ID, {
      ...baseBookingData,
      serviceId: undefined,
      serviceCategory: 'plumbing',
    });

    const createdDoc = Booking.create.mock.calls[0][0][0];
    expect(createdDoc.startsFromSnapshot).toBeUndefined();
    expect(createdDoc.seedRangeSnapshot).toBeUndefined();
    expect(createdDoc.holdCeiling).toBeUndefined();
  });
});
