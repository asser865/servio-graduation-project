'use strict';

const mongoose = require('mongoose');

const AUTO_CONFIRM_HOURS = 48;
const REMINDER_HOURS = [24, 44];
const AUTO_CONFIRM_MS = AUTO_CONFIRM_HOURS * 60 * 60 * 1000;

async function up(db) {
  await db.collection('adminsettings').updateOne(
    { key: 'global' },
    {
      $set: {
        'escrow.autoConfirmHours': AUTO_CONFIRM_HOURS,
        'escrow.reminderHours': REMINDER_HOURS,
      },
    },
    { upsert: true }
  );

  const waiting = db.collection('bookings').find({
    status: 'awaiting_customer_confirmation',
    $or: [
      { customerConfirmAutoAt: { $exists: false } },
      { customerConfirmAutoAt: null },
    ],
    'completionOutcome.submittedAt': { $type: 'date' },
  });

  let backfilled = 0;
  for await (const booking of waiting) {
    await db.collection('bookings').updateOne(
      { _id: booking._id, customerConfirmAutoAt: booking.customerConfirmAutoAt ?? null },
      { $set: { customerConfirmAutoAt: new Date(booking.completionOutcome.submittedAt.getTime() + AUTO_CONFIRM_MS) } }
    );
    backfilled += 1;
  }

  console.log(`Migration 2026-06-01-payments-overhaul: updated settings and backfilled ${backfilled} booking(s)`);
}

async function down(_db) {
  console.warn('No down migration - the 48-hour confirmation policy is forward-only');
}

module.exports = { up, down };

if (require.main === module) {
  (async () => {
    const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
    if (!uri) throw new Error('MONGO_URI env var is required.');
    await mongoose.connect(uri);
    await up(mongoose.connection.db);
    await mongoose.disconnect();
  })().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
