const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const CashDebt = require('../cash-debt.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('accepts settlementMethod enum', async () => {
  const d = await CashDebt.create({
    worker: new mongoose.Types.ObjectId(),
    booking: new mongoose.Types.ObjectId(),
    amount: 30,
    remaining: 30,
    status: 'outstanding',
    settlementMethod: 'instapay',
  });
  expect(d.settlementMethod).toBe('instapay');
});

test('rejects unknown settlementMethod', async () => {
  await expect(
    CashDebt.create({
      worker: new mongoose.Types.ObjectId(),
      booking: new mongoose.Types.ObjectId(),
      amount: 30,
      remaining: 30,
      status: 'outstanding',
      settlementMethod: 'bogus',
    }),
  ).rejects.toThrow();
});

test('remaining defaults to amount on create', async () => {
  const d = await CashDebt.create({
    worker: new mongoose.Types.ObjectId(),
    booking: new mongoose.Types.ObjectId(),
    amount: 75,
    status: 'outstanding',
  });
  expect(d.remaining).toBe(75);
});
