const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Wallet = require('../wallet.model');
const PayoutRequest = require('../payout-request.model');
const svc = require('../payout-request.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('request: validates min amount + creates pending', async () => {
  const worker = new mongoose.Types.ObjectId();
  await Wallet.create({ worker, balance: 200 });
  const r = await svc.requestPayout({ workerId: worker, amount: 100, method: 'bank', details: { iban: 'EG' } });
  expect(r.status).toBe('pending');
  expect(r.amount).toBe(100);
});

test('request: rejects amount > balance', async () => {
  const worker = new mongoose.Types.ObjectId();
  await Wallet.create({ worker, balance: 50 });
  await expect(svc.requestPayout({ workerId: worker, amount: 100, method: 'bank' })).rejects.toThrow(/exceeds/i);
});

test('approve → pending → approved, no wallet change', async () => {
  const worker = new mongoose.Types.ObjectId();
  const admin = new mongoose.Types.ObjectId();
  await Wallet.create({ worker, balance: 500 });
  const p = await svc.requestPayout({ workerId: worker, amount: 200, method: 'bank' });
  const r = await svc.approvePayout({ payoutId: p._id, adminId: admin });
  expect(r.status).toBe('approved');
  const w = await Wallet.findOne({ worker });
  expect(w.balance).toBe(500);
});

test('mark-paid debits wallet atomically + sets transactionRef', async () => {
  const worker = new mongoose.Types.ObjectId();
  const admin = new mongoose.Types.ObjectId();
  await Wallet.create({ worker, balance: 500 });
  const p = await svc.requestPayout({ workerId: worker, amount: 200, method: 'bank' });
  await svc.approvePayout({ payoutId: p._id, adminId: admin });
  const r = await svc.markPayoutPaid({ payoutId: p._id, adminId: admin, transactionRef: 'NBE-9X3' });
  expect(r.status).toBe('paid');
  expect(r.transactionRef).toBe('NBE-9X3');
  const w = await Wallet.findOne({ worker });
  expect(w.balance).toBe(300);
});

test('reject leaves wallet untouched', async () => {
  const worker = new mongoose.Types.ObjectId();
  const admin = new mongoose.Types.ObjectId();
  await Wallet.create({ worker, balance: 500 });
  const p = await svc.requestPayout({ workerId: worker, amount: 200, method: 'bank' });
  const r = await svc.rejectPayout({ payoutId: p._id, adminId: admin, reason: 'invalid bank' });
  expect(r.status).toBe('rejected');
  const w = await Wallet.findOne({ worker });
  expect(w.balance).toBe(500);
});
