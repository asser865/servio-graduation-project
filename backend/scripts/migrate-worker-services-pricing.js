/**
 * Migration: Convert worker.services from [ObjectId] to [{serviceId, startsFrom}]
 *
 * Reads each worker's existing services array (plain Service ObjectIds) and rewrites
 * it as a subdoc array pairing serviceId with startsFrom, defaulted from the
 * service's own basePrice. Already-migrated workers (subdoc shape detected) are
 * skipped so the script is safe to re-run.
 *
 * Usage:
 *   node scripts/migrate-worker-services-pricing.js
 *
 * Requires MONGODB_URI to be set in the environment (or .env file).
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const User = require('../src/modules/users/user.model');
const Service = require('../src/modules/services/service.model');

async function run() {
  await mongoose.connect(process.env.MONGODB_URI);
  const svcPrice = new Map((await Service.find().select('_id basePrice'))
    .map(s => [s._id.toString(), s.basePrice]));
  // Use the raw collection so we read the OLD [ObjectId] shape regardless of schema.
  const cursor = User.collection.find({ role: 'worker' });
  let updated = 0;
  for await (const doc of cursor) {
    const cur = Array.isArray(doc.services) ? doc.services : [];
    if (cur.length && cur[0] && cur[0].serviceId) continue; // already migrated
    const next = cur
      .map(id => (id && id.toString) ? id.toString() : null)
      .filter(Boolean)
      .map(idStr => ({ serviceId: new mongoose.Types.ObjectId(idStr), startsFrom: svcPrice.get(idStr) || 0 }));
    await User.collection.updateOne({ _id: doc._id }, { $set: { services: next } });
    updated++;
  }
  console.log(`Migrated ${updated} worker(s)`);
  await mongoose.disconnect();
}
run().catch(e => { console.error(e); process.exit(1); });
