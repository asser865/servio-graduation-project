'use strict';
const { resolveDurationMin, CATEGORY_DURATION_DEFAULTS } = require('../src/modules/services/duration-fallback.js');

describe('resolveDurationMin', () => {
  test('returns service.estimatedDurationMin when set', () => {
    expect(resolveDurationMin({ estimatedDurationMin: 75, category: 'plumbing' })).toBe(75);
  });
  test('falls back to category default when service missing duration', () => {
    expect(resolveDurationMin({ estimatedDurationMin: 0, category: 'electrical' })).toBe(60);
  });
  test('falls back to 60 when category unknown', () => {
    expect(resolveDurationMin({ estimatedDurationMin: null, category: 'space-travel' })).toBe(60);
  });
  test('accepts bare category string', () => {
    expect(resolveDurationMin({ category: 'renovation' })).toBe(240);
  });
  test('exposes the table for admin UI', () => {
    expect(CATEGORY_DURATION_DEFAULTS.plumbing).toBe(90);
  });
});
