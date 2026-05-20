'use strict';
const {
  intervalsOverlap,
  computeScheduledWindow,
} = require('../src/modules/bookings/availability.service.js');

describe('intervalsOverlap', () => {
  const d = (s) => new Date(s);
  test('disjoint earlier → false', () => {
    expect(intervalsOverlap(d('2026-05-18T10:00Z'), d('2026-05-18T11:00Z'),
                            d('2026-05-18T12:00Z'), d('2026-05-18T13:00Z'))).toBe(false);
  });
  test('touching boundary (a.end == b.start) → false (open interval)', () => {
    expect(intervalsOverlap(d('2026-05-18T10:00Z'), d('2026-05-18T11:00Z'),
                            d('2026-05-18T11:00Z'), d('2026-05-18T12:00Z'))).toBe(false);
  });
  test('one-second overlap → true', () => {
    expect(intervalsOverlap(d('2026-05-18T10:00:00Z'), d('2026-05-18T11:00:01Z'),
                            d('2026-05-18T11:00:00Z'), d('2026-05-18T12:00:00Z'))).toBe(true);
  });
  test('fully contained → true', () => {
    expect(intervalsOverlap(d('2026-05-18T10:00Z'), d('2026-05-18T14:00Z'),
                            d('2026-05-18T11:00Z'), d('2026-05-18T12:00Z'))).toBe(true);
  });
});

describe('computeScheduledWindow', () => {
  test('combines date + HH:00 + tz → UTC instant; end = start + (duration + buffer)*60s', () => {
    const { start, end } = computeScheduledWindow({
      scheduledDate: '2026-05-18',
      scheduledTime: '14:00',
      timezone: 'Africa/Cairo',
      durationMin: 60,
      bufferMin: 30,
    });
    expect(start.toISOString()).toBe('2026-05-18T11:00:00.000Z');
    expect(end.toISOString()).toBe('2026-05-18T12:30:00.000Z');
  });
  test('rejects cross-day windows', () => {
    expect(() =>
      computeScheduledWindow({
        scheduledDate: '2026-05-18',
        scheduledTime: '23:00',
        timezone: 'Africa/Cairo',
        durationMin: 240,
        bufferMin: 30,
      })
    ).toThrow(/cross-day/i);
  });
});

const { computeBusyState } = require('../src/modules/bookings/availability.service.js');

describe('computeBusyState', () => {
  const SETTINGS = { extensionMinutes: 30, maxExtensionMultiplier: 2, stuckJobBufferMin: 120 };

  test('returns isBusy=false when no active execution-phase booking', () => {
    const out = computeBusyState({ active: [], now: new Date('2026-05-18T12:00Z'), settings: SETTINGS });
    expect(out.isBusy).toBe(false);
    expect(out.label).toBeNull();
  });

  test('returns isBusy=true and coarse remaining bucket', () => {
    const out = computeBusyState({
      active: [{
        _id: 'b1', status: 'in_progress',
        scheduledStart: new Date('2026-05-18T11:00Z'),
        scheduledEnd:   new Date('2026-05-18T12:30Z'),
        actualStartedAt:    new Date('2026-05-18T11:00Z'),
        estimatedFinishAt:  new Date('2026-05-18T12:00Z'),
        estimatedDurationMin: 60, extensionCount: 0, extensionLog: [],
      }],
      now: new Date('2026-05-18T11:30Z'),
      settings: SETTINGS,
    });
    expect(out.isBusy).toBe(true);
    expect(out.label).toBe('busy');
    expect(out.remainingMin).toBe(30);
    expect(out.busyUntil.toISOString()).toBe('2026-05-18T12:00:00.000Z');
  });

  test('auto-extends when finish elapsed and budget remains', () => {
    const out = computeBusyState({
      active: [{
        _id: 'b1', status: 'in_progress',
        scheduledStart: new Date('2026-05-18T11:00Z'),
        scheduledEnd:   new Date('2026-05-18T12:30Z'),
        actualStartedAt:    new Date('2026-05-18T11:00Z'),
        estimatedFinishAt:  new Date('2026-05-18T12:00Z'),
        estimatedDurationMin: 60, extensionCount: 0, extensionLog: [],
      }],
      now: new Date('2026-05-18T12:05Z'),
      settings: SETTINGS,
    });
    expect(out.extensionsApplied).toBe(1);
    expect(out.busyUntil.toISOString()).toBe('2026-05-18T12:30:00.000Z');
    expect(out.label).toBe('busy');
    expect(out.isOverrunning).toBe(true);
  });

  test('switches to finishing_up when budget exhausted', () => {
    const out = computeBusyState({
      active: [{
        _id: 'b1', status: 'in_progress',
        scheduledStart:    new Date('2026-05-18T11:00Z'),
        scheduledEnd:      new Date('2026-05-18T12:30Z'),
        actualStartedAt:   new Date('2026-05-18T11:00Z'),
        estimatedFinishAt: new Date('2026-05-18T13:00Z'),
        estimatedDurationMin: 60, extensionCount: 1,
        extensionLog: [{ at: new Date('2026-05-18T12:00Z'), addedMin: 30 }],
      }],
      now: new Date('2026-05-18T13:05Z'),
      settings: SETTINGS,
    });
    expect(out.label).toBe('finishing_up');
    expect(out.remainingMin).toBeNull();
  });
});

const { getWorkerBusyStateFromDB } = require('../src/modules/bookings/availability.service.js');

describe('getWorkerBusyStateFromDB', () => {
  test('persists pending extension to DB', async () => {
    const Booking  = require('../src/modules/bookings/booking.model.js');
    const Settings = require('../src/modules/admin/settings.model.js');
    jest.spyOn(Booking, 'find').mockReturnValue({
      lean: () => Promise.resolve([{
        _id: 'b1', status: 'in_progress',
        scheduledStart:    new Date(Date.now() - 60 * 60_000),
        scheduledEnd:      new Date(Date.now() - 10 * 60_000),
        actualStartedAt:   new Date(Date.now() - 60 * 60_000),
        estimatedFinishAt: new Date(Date.now() - 10 * 60_000),
        estimatedDurationMin: 60, extensionCount: 0, extensionLog: [],
      }]),
    });
    jest.spyOn(Settings, 'findOne').mockReturnValue({
      lean: () => Promise.resolve({ extensionMinutes: 30, maxExtensionMultiplier: 2, stuckJobBufferMin: 120 }),
    });
    jest.spyOn(Booking, 'updateOne').mockResolvedValue({ acknowledged: true });

    const out = await getWorkerBusyStateFromDB('664000000000000000000010');
    expect(out.isBusy).toBe(true);
    expect(Booking.updateOne).toHaveBeenCalled();
  });
});
