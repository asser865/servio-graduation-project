const db = require('../../../test-utils/db');
const AdminAction = require('../admin-action.model');
const service = require('../admin-action.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('records immutable action', async () => {
  await service.record({
    adminId: '64b7a7a7a7a7a7a7a7a7a7a7',
    actionType: 'payment_release',
    targetType: 'payment',
    targetId: '64b7a7a7a7a7a7a7a7a7a7a8',
    details: { amount: 102 },
    ipAddress: '127.0.0.1',
  });
  const rows = await AdminAction.find({});
  expect(rows).toHaveLength(1);
  expect(rows[0].actionType).toBe('payment_release');
});

test('rejects unknown actionType', async () => {
  await expect(service.record({
    adminId: '64b7a7a7a7a7a7a7a7a7a7a7',
    actionType: 'bogus',
    targetType: 'payment',
    targetId: '64b7a7a7a7a7a7a7a7a7a7a8',
  })).rejects.toThrow();
});

test('list paginates and filters by actionType', async () => {
  for (let i = 0; i < 5; i++) {
    await service.record({
      adminId: '64b7a7a7a7a7a7a7a7a7a7a7',
      actionType: i % 2 === 0 ? 'payment_release' : 'payment_refund',
      targetType: 'payment',
      targetId: '64b7a7a7a7a7a7a7a7a7a7a8',
    });
  }
  const res = await service.list({ actionType: 'payment_release', limit: 10 });
  expect(res.data).toHaveLength(3);
  expect(res.meta.total).toBe(3);
});
