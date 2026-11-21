const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const settings = require('../admin-settings.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('settings expose pricing.overBandMultiplier default 1.5', async () => {
  const cfg = await settings.get();
  expect(cfg.pricing).toBeDefined();
  expect(cfg.pricing.overBandMultiplier).toBe(1.5);
});
