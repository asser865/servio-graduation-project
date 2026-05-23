const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const DebtSettlement = require('../debt-settlement.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('creates settlement w/ pending_verification status', async () => {
  const s = await DebtSettlement.create({
    worker: new mongoose.Types.ObjectId(),
    debts: [new mongoose.Types.ObjectId()],
    totalAmount: 100,
    method: 'instapay',
    reference: 'IP-9X3Z2',
    proofUrl: '/uploads/x.jpg',
  });
  expect(s.status).toBe('pending_verification');
});

test('rejects amount<=0', async () => {
  await expect(
    DebtSettlement.create({
      worker: new mongoose.Types.ObjectId(),
      debts: [new mongoose.Types.ObjectId()],
      totalAmount: 0,
      method: 'instapay',
      reference: 'x',
    }),
  ).rejects.toThrow();
});
