/**
 * Migration: Backfill coverageAreaSlugs + coverageMatchSlugs for existing workers.
 *
 * Resolves each worker's free-text coverageAreas (and falls back to serviceArea
 * / locationLabel when coverageAreas is empty) against the canonical Egypt
 * locations taxonomy, then writes the canonical slugs and the expanded match
 * set used by hierarchical worker discovery.
 *
 * Safe to re-run. Workers whose coverage strings don't resolve are listed at
 * the end so the taxonomy can be extended with missing aliases.
 *
 * Usage:
 *   node scripts/backfill-coverage-slugs.js [--dry]
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const mongoose                   = require('mongoose');
const User                       = require('../src/modules/users/user.model');
const { resolveSlug, expandCoverage } = require('../src/utils/locationsTaxonomy');

const DRY = process.argv.includes('--dry');

function deriveInputs(worker) {
  if (Array.isArray(worker.coverageAreas) && worker.coverageAreas.length) {
    return worker.coverageAreas;
  }
  // Legacy fallback: split serviceArea / locationLabel on commas.
  const fallback = [worker.serviceArea, worker.locationLabel]
    .filter(Boolean)
    .join(',')
    .split(/[,/\n]+/)
    .map((s) => s.trim())
    .filter(Boolean);
  return fallback;
}

async function run() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log(`Connected to MongoDB${DRY ? ' (dry run)' : ''}`);

  const workers = await User.find({ role: 'worker' })
    .select('_id name coverageAreas serviceArea locationLabel coverageAreaSlugs coverageMatchSlugs');
  console.log(`Scanning ${workers.length} worker(s)…`);

  let updated = 0;
  const unresolved = new Map(); // raw input -> count

  for (const worker of workers) {
    const inputs = deriveInputs(worker);
    if (!inputs.length) continue;

    const { slugs, matchSlugs } = expandCoverage(inputs);

    inputs.forEach((raw) => {
      if (!resolveSlug(raw)) {
        unresolved.set(raw, (unresolved.get(raw) || 0) + 1);
      }
    });

    const sameSlugs   = arraysEqualUnordered(worker.coverageAreaSlugs || [], slugs);
    const sameMatches = arraysEqualUnordered(worker.coverageMatchSlugs || [], matchSlugs);
    if (sameSlugs && sameMatches) continue;

    if (DRY) {
      console.log(`  [dry] ${worker.name} (${worker._id}): slugs=${slugs.join(',')} match=${matchSlugs.length}`);
    } else {
      worker.coverageAreaSlugs  = slugs;
      worker.coverageMatchSlugs = matchSlugs;
      // If coverageAreas was empty but we derived inputs from legacy fields, persist them too.
      if (!Array.isArray(worker.coverageAreas) || worker.coverageAreas.length === 0) {
        worker.coverageAreas = inputs;
      }
      await worker.save({ validateModifiedOnly: true });
      console.log(`  Updated ${worker.name} (${worker._id}) → ${slugs.length} slug(s)`);
    }
    updated++;
  }

  console.log(`\nBackfill complete. ${updated} worker(s) ${DRY ? 'would be ' : ''}updated.`);

  if (unresolved.size) {
    console.log('\nUnresolved inputs (consider adding to taxonomy aliases):');
    [...unresolved.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 50)
      .forEach(([raw, count]) => console.log(`  × ${count}\t${raw}`));
  }

  await mongoose.disconnect();
}

function arraysEqualUnordered(a, b) {
  if (a.length !== b.length) return false;
  const set = new Set(a);
  return b.every((x) => set.has(x));
}

run().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
