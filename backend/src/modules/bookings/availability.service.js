'use strict';

function intervalsOverlap(aStart, aEnd, bStart, bEnd) {
  return aStart < bEnd && bStart < aEnd;
}

function computeScheduledWindow({ scheduledDate, scheduledTime, timezone, durationMin, bufferMin }) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(scheduledDate)) {
    throw new Error('scheduledDate must be YYYY-MM-DD');
  }
  if (!/^(0[0-9]|1[0-9]|2[0-3]):00$/.test(scheduledTime)) {
    throw new Error('scheduledTime must be HH:00');
  }
  const [y, m, d] = scheduledDate.split('-').map(Number);
  const hour = parseInt(scheduledTime, 10);

  const wall = new Date(Date.UTC(y, m - 1, d, hour, 0, 0));
  const tzOffsetMin = getTimezoneOffsetMin(timezone, wall);
  const start = new Date(wall.getTime() - tzOffsetMin * 60_000);
  const end   = new Date(start.getTime() + (durationMin + bufferMin) * 60_000);

  if (start.getUTCDate() !== end.getUTCDate() ||
      start.getUTCMonth() !== end.getUTCMonth() ||
      start.getUTCFullYear() !== end.getUTCFullYear()) {
    throw new Error('Booking window may not span a cross-day UTC boundary in v1');
  }

  return { start, end };
}

function getTimezoneOffsetMin(timezone, when) {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hour12:   false,
    year:     'numeric', month: '2-digit', day: '2-digit',
    hour:     '2-digit', minute: '2-digit', second: '2-digit',
  });
  const parts = Object.fromEntries(dtf.formatToParts(when).filter(p => p.type !== 'literal').map(p => [p.type, p.value]));
  const asUTC = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
  return Math.round((asUTC - when.getTime()) / 60_000);
}

const BUSY_STATUSES = ['en_route', 'arrived', 'in_progress'];

function bucketRemainingMin(diffMs) {
  if (diffMs <= 0) return 0;
  const m = Math.ceil(diffMs / 60_000);
  for (const b of [15, 30, 45, 60, 90, 120]) if (m <= b) return b;
  return 120;
}

function endOrInfinity(d) { return d || new Date(8640000000000000); }

/**
 * Reads-only: given the worker's currently-active bookings, current time, and
 * platform settings, returns the busy state. Applies auto-extension lazily —
 * if `in_progress` is past its estimatedFinishAt and extension budget remains,
 * a new extension entry is computed (not yet persisted; caller decides).
 */
function computeBusyState({ active, now, settings }) {
  const current = (active || []).find(b => {
    if (!BUSY_STATUSES.includes(b.status)) return false;
    const end = b.estimatedFinishAt || b.scheduledEnd;
    const maxBudget = (settings.maxExtensionMultiplier - 1) * (b.estimatedDurationMin || 0);
    const hardEnd = end
      ? new Date(end.getTime() + (maxBudget + (settings.stuckJobBufferMin || 0)) * 60_000)
      : endOrInfinity(null);
    return b.scheduledStart && b.scheduledStart <= now && now < hardEnd;
  });

  if (!current) {
    return { isBusy: false, label: null, busyUntil: null, remainingMin: null,
             isOverrunning: false, extensionCount: 0, extensionsApplied: 0,
             pendingExtension: null, bookingId: null };
  }

  const logExtended = (current.extensionLog || []).reduce((s, e) => s + e.addedMin, 0);
  let totalExtended = logExtended;
  if (current.actualStartedAt && current.estimatedFinishAt && current.estimatedDurationMin) {
    const baselineFinishMs = current.actualStartedAt.getTime() + current.estimatedDurationMin * 60_000;
    const extendedByMin = Math.max(0, Math.round((current.estimatedFinishAt.getTime() - baselineFinishMs) / 60_000));
    totalExtended = Math.max(totalExtended, extendedByMin);
  }
  const budget = (settings.maxExtensionMultiplier - 1) * current.estimatedDurationMin - totalExtended;
  let busyUntil = current.estimatedFinishAt || current.scheduledEnd;
  let extensionsApplied = 0;
  let pendingExtension = null;
  let isOverrunning = false;
  let label = 'busy';

  if (current.status === 'in_progress' && busyUntil && busyUntil < now) {
    isOverrunning = true;
    if (budget >= settings.extensionMinutes) {
      const addMin = settings.extensionMinutes;
      busyUntil = new Date(busyUntil.getTime() + addMin * 60_000);
      pendingExtension = { at: new Date(now), addedMin: addMin };
      extensionsApplied = 1;
    } else if (budget > 0) {
      busyUntil = new Date(busyUntil.getTime() + budget * 60_000);
      pendingExtension = { at: new Date(now), addedMin: budget };
      extensionsApplied = 1;
    } else {
      label = 'finishing_up';
    }
  }

  const remainingMs = busyUntil ? busyUntil - now : 0;
  return {
    isBusy:           true,
    label,
    busyUntil,
    remainingMin:     label === 'finishing_up' ? null : bucketRemainingMin(remainingMs),
    isOverrunning,
    extensionCount:   (current.extensionCount || 0) + extensionsApplied,
    extensionsApplied,
    pendingExtension,
    bookingId:        current._id,
  };
}

async function getWorkerBusyStateFromDB(workerId) {
  const Booking  = require('./booking.model.js');
  const Settings = require('../admin/settings.model.js');

  const [settings, active] = await Promise.all([
    Settings.findOne({}).lean(),
    Booking.find({
      worker: workerId,
      status: { $in: BUSY_STATUSES },
    }).lean(),
  ]);

  const state = computeBusyState({
    active,
    now: new Date(),
    settings: settings || { extensionMinutes: 30, maxExtensionMultiplier: 2, stuckJobBufferMin: 120 },
  });

  if (state.pendingExtension && state.bookingId) {
    await Booking.updateOne(
      { _id: state.bookingId },
      {
        $set:   { estimatedFinishAt: state.busyUntil },
        $inc:   { extensionCount: 1 },
        $push:  { extensionLog: state.pendingExtension },
      }
    );
    console.info(JSON.stringify({
      event: 'bookings.extension_applied',
      bookingId: String(state.bookingId),
      addedMin: state.pendingExtension.addedMin,
      extensionCount: state.extensionCount,
    }));
  }

  if (state.isBusy && state.label === 'finishing_up') {
    const stuckThreshold = (settings?.stuckJobBufferMin ?? 120) * 60_000;
    const overshoot = state.busyUntil ? Date.now() - state.busyUntil.getTime() : 0;
    if (overshoot > stuckThreshold) {
      await Booking.updateOne(
        { _id: state.bookingId, needsAdminReview: { $ne: true } },
        { $set: { needsAdminReview: true } }
      );
    }
  }

  const { pendingExtension: _p, ...publicState } = state;
  return publicState;
}

module.exports = { intervalsOverlap, computeScheduledWindow, getTimezoneOffsetMin, computeBusyState, BUSY_STATUSES, getWorkerBusyStateFromDB };
