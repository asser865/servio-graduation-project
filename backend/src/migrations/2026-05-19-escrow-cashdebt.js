'use strict';

// ─── Forward-only migration: escrow + cash-debt schema ───────────────────────
// Idempotent: safe to run multiple times. Adds defaults for new fields, seeds
// admin permissions, ensures AdminSettings singleton exists, backfills the
// invoice counter, and creates indexes for the new collections.
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');

async function up(db) {
  // 1. Payment: ensure status + refund fields exist with sane defaults
  await db.collection('payments').updateMany(
    { status: { $exists: false } },
    { $set: { status: 'pending', refundedAmount: 0, refunds: [] } }
  );

  // 2. User: existing admins get every permission (superadmin replaces this)
  let PERMS = [];
  try {
    PERMS = Object.values(require('../constants/permissions'));
  } catch (_) {
    PERMS = [
      'payments:release', 'payments:refund', 'payments:dispute', 'payments:emergency',
      'settlements:verify', 'settlements:reject',
      'payouts:approve', 'payouts:mark_paid',
      'credits:issue',
      'users:suspend',
      'settings:write',
    ];
  }
  await db.collection('users').updateMany(
    { role: 'admin', adminPermissions: { $exists: false } },
    { $set: { adminPermissions: PERMS } }
  );

  // 3. AdminSettings singleton — upsert defaults if missing.
  // Service queries by { key: 'global' }; schema marks `key` unique. Must match.
  await db.collection('adminsettings').updateOne(
    { key: 'global' },
    {
      $setOnInsert: {
        key: 'global',
        cancellation: {
          customerFreeWindowMinutes: 15,
          customerLateFeePercent: 20,
          workerStrikeWindowDays: 30,
          workerStrikesPerSuspension: 3,
          workerSuspensionDays: 7,
        },
        noShow: { customerNoShowFeePercent: 50 },
        escrow: { autoConfirmHours: 48, reminderHours: [24, 44] },
        vat: { rate: 0.14 },
      },
    },
    { upsert: true }
  );

  // 4. Invoice counter for current year
  await db.collection('counters').updateOne(
    { key: `invoice:${new Date().getFullYear()}` },
    { $setOnInsert: { seq: 0 } },
    { upsert: true }
  );

  // 5. Index audit (createIndex is idempotent in MongoDB)
  await db.collection('payments').createIndex({ status: 1, createdAt: -1 });
  await db.collection('cashdebts').createIndex({ worker: 1, status: 1 });
  await db.collection('debtsettlements').createIndex({ status: 1, submittedAt: -1 });
  await db.collection('payoutrequests').createIndex({ worker: 1, status: 1 });
  await db.collection('invoices').createIndex({ number: 1 }, { unique: true });
  await db.collection('customercredits').createIndex({ customer: 1, expiresAt: 1 });
  await db.collection('workerstrikes').createIndex({ worker: 1, expiresAt: 1 });
  await db.collection('notifications').createIndex({ userId: 1, isRead: 1, createdAt: -1 });

  console.log('Migration 2026-05-19-escrow-cashdebt: up complete');
}

async function down(_db) {
  console.warn('No down migration — this is a forward-only schema extension');
}

module.exports = { up, down };

if (require.main === module) {
  (async () => {
    const uri = process.env.MONGO_URI || process.env.MONGODB_URI;
    if (!uri) throw new Error('MONGO_URI env var is required.');
    await mongoose.connect(uri);
    await up(mongoose.connection.db);
    await mongoose.disconnect();
  })().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
