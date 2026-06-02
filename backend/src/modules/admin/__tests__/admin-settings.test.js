const db = require('../../../test-utils/db');
const settings = require('../admin-settings.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(async () => {
  settings.reset();
  await db.clear();
});

test('returns defaults on first load', async () => {
  const s = await settings.get();
  expect(s.escrow.autoConfirmHours).toBe(48);
  expect(s.escrow.reminderHours).toEqual([24, 44]);
});

test('updates partial fields', async () => {
  await settings.update({ escrow: { autoConfirmHours: 48 } });
  const s = await settings.get();
  expect(s.escrow.autoConfirmHours).toBe(48);
  expect(s.escrow.reminderHours).toEqual([24, 44]);
});

test('cache returns updated value after reset', async () => {
  await settings.get();
  await settings.update({ vat: { rate: 0.20 } });
  const s = await settings.get();
  expect(s.vat.rate).toBe(0.20);
});
