/**
 * Migration: Populate worker.services from worker.categories
 *
 * For each worker who has categories but no services, find the matching
 * Service documents by category and assign their ObjectIds to worker.services.
 *
 * This is a non-destructive migration — categories are NOT removed.
 *
 * Usage:
 *   node scripts/migrate-worker-services.js
 *
 * Requires MONGODB_URI to be set in the environment (or .env file).
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const mongoose = require('mongoose');
const User     = require('../src/modules/users/user.model');
const Service  = require('../src/modules/services/service.model');

async function run() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to MongoDB');

  // Fetch all active services once — avoid N+1 queries
  const services = await Service.find({ isActive: true }).select('_id category');

  // Build a map: category string -> array of service ObjectIds
  const categoryToServiceIds = {};
  for (const svc of services) {
    if (!categoryToServiceIds[svc.category]) {
      categoryToServiceIds[svc.category] = [];
    }
    categoryToServiceIds[svc.category].push(svc._id);
  }

  // Find workers who still have an empty services array but have categories
  const workers = await User.find({ role: 'worker', services: { $size: 0 } });
  console.log(`Found ${workers.length} worker(s) to migrate`);

  let updated = 0;
  for (const worker of workers) {
    if (!Array.isArray(worker.categories) || worker.categories.length === 0) continue;

    const matchingServiceIds = [];
    for (const cat of worker.categories) {
      const ids = categoryToServiceIds[cat];
      if (ids) matchingServiceIds.push(...ids);
    }

    if (matchingServiceIds.length === 0) continue;

    // Deduplicate (a worker might have multiple matching services per category)
    const uniqueIds = [...new Map(matchingServiceIds.map((id) => [id.toString(), id])).values()];

    worker.services = uniqueIds;
    await worker.save({ validateModifiedOnly: true });
    updated++;
    console.log(`  Updated worker ${worker.name} (${worker._id}) → ${uniqueIds.length} service(s)`);
  }

  console.log(`\nMigration complete. Updated ${updated} worker(s).`);
  await mongoose.disconnect();
}

run().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
