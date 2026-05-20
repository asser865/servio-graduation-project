'use strict';
require('dotenv').config();
const mongoose = require('mongoose');
const Booking  = require('../src/modules/bookings/booking.model');
const Service  = require('../src/modules/services/service.model');
const User     = require('../src/modules/users/user.model');
const Settings = require('../src/modules/admin/settings.model');
const { computeScheduledWindow } = require('../src/modules/bookings/availability.service');
const { resolveDurationMin }     = require('../src/modules/services/duration-fallback');

const ACTIVE = ['pending', 'accepted', 'en_route', 'arrived', 'in_progress'];

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  const settings = (await Settings.findOne({}).lean()) || {};
  const bufferMin = settings.travelBufferMin ?? 30;

  const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 3600 * 1000);
  const cursor = Booking.find({
    $or: [
      { status: { $in: ACTIVE } },
      { status: 'completed', updatedAt: { $gte: ninetyDaysAgo } },
    ],
    $and: [{ $or: [{ scheduledStart: { $exists: false } }, { scheduledStart: null }] }],
  }).cursor();

  let migrated = 0, skipped = 0;
  for (let b = await cursor.next(); b != null; b = await cursor.next()) {
    try {
      const dateStr = b.scheduledDate.toISOString().slice(0, 10);
      const service = b.service ? await Service.findById(b.service).lean() : null;
      const durationMin = resolveDurationMin(service || { category: b.serviceCategory });
      const worker = await User.findById(b.worker).select('timezone').lean();
      const { start, end } = computeScheduledWindow({
        scheduledDate: dateStr,
        scheduledTime: b.scheduledTime || '09:00',
        timezone: worker?.timezone || 'Africa/Cairo',
        durationMin,
        bufferMin,
      });
      b.scheduledStart       = start;
      b.scheduledEnd         = end;
      b.estimatedDurationMin = durationMin;
      b.travelBufferMin      = bufferMin;
      if (b.status === 'in_progress' && !b.actualStartedAt) {
        b.actualStartedAt   = start;
        b.estimatedFinishAt = new Date(start.getTime() + durationMin * 60_000);
      }
      await b.save();
      migrated++;
    } catch (err) {
      console.error(`Skip booking ${b._id}: ${err.message}`);
      skipped++;
    }
  }
  console.log(`Migrated ${migrated}, skipped ${skipped}`);
  await mongoose.disconnect();
}

main().catch(err => { console.error(err); process.exit(1); });
