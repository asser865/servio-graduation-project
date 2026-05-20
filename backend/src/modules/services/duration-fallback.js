'use strict';

const CATEGORY_DURATION_DEFAULTS = Object.freeze({
  plumbing:       90,
  electrical:     60,
  hvac:          120,
  carpentry:      90,
  appliance:      75,
  handyman:       60,
  renovation:    240,
  painting:      180,
  flooring:      240,
  drywall:       180,
  roofing:       240,
  cleaning:      120,
  'pest-control': 60,
  landscaping:   180,
  installation:  120,
  other:          60,
});

const DEFAULT_DURATION_MIN = 60;

function resolveDurationMin(serviceOrCategory) {
  const explicit = serviceOrCategory && serviceOrCategory.estimatedDurationMin;
  if (Number.isFinite(explicit) && explicit > 0) return explicit;
  const category = serviceOrCategory && serviceOrCategory.category;
  return CATEGORY_DURATION_DEFAULTS[category] || DEFAULT_DURATION_MIN;
}

module.exports = { resolveDurationMin, CATEGORY_DURATION_DEFAULTS, DEFAULT_DURATION_MIN };
