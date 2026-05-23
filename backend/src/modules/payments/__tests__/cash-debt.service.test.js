const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const CashDebt = require('../cash-debt.model');
const Wallet = require('../wallet.model');
const DebtSettlement = require('../debt-settlement.model');
const svc = require('../cash-debt.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

describe('getWorkerDebtSummary', () => {
  test('returns totals + counts', async () => {
    const worker = new mongoose.Types.ObjectId();
    await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 30,
      remaining: 30,
      status: 'outstanding',
      createdAt: new Date(Date.now() - 12 * 86400e3),
    });
    await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 25,
      remaining: 5,
      status: 'partially_paid',
    });
    await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 22,
      remaining: 22,
      status: 'outstanding',
    });
    const s = await svc.getWorkerDebtSummary(worker);
    expect(s.totalOutstanding).toBe(57);
    expect(s.count).toBe(3);
    expect(s.outstandingCount).toBe(2);
    expect(s.partialCount).toBe(1);
  });
});

describe('settleByWallet', () => {
  test('debits wallet + pays oldest debts first', async () => {
    const worker = new mongoose.Types.ObjectId();
    await Wallet.create({ worker, balance: 100, pendingBalance: 0 });
    const a = await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 30,
      remaining: 30,
      status: 'outstanding',
      createdAt: new Date(Date.now() - 5e9),
    });
    const b = await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 25,
      remaining: 25,
      status: 'outstanding',
    });
    const result = await svc.settleByWallet({ workerId: worker, amount: 40 });
    expect(result.amountApplied).toBe(40);
    const w = await Wallet.findOne({ worker });
    expect(w.balance).toBe(60);
    const aAfter = await CashDebt.findById(a._id);
    expect(aAfter.status).toBe('paid');
    expect(aAfter.remaining).toBe(0);
    expect(aAfter.settlementMethod).toBe('wallet_balance');
    const bAfter = await CashDebt.findById(b._id);
    expect(bAfter.status).toBe('partially_paid');
    expect(bAfter.remaining).toBe(15);
  });

  test('rejects wallet underfunded', async () => {
    const worker = new mongoose.Types.ObjectId();
    await Wallet.create({ worker, balance: 10 });
    await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 50,
      remaining: 50,
      status: 'outstanding',
    });
    await expect(svc.settleByWallet({ workerId: worker, amount: 30 })).rejects.toThrow(/underfunded|wallet/i);
  });

  test('rejects amount > outstanding', async () => {
    const worker = new mongoose.Types.ObjectId();
    await Wallet.create({ worker, balance: 1000 });
    await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 20,
      remaining: 20,
      status: 'outstanding',
    });
    await expect(svc.settleByWallet({ workerId: worker, amount: 100 })).rejects.toThrow(/exceeds/i);
  });
});

describe('submitManualSettlement', () => {
  test('creates pending_verification doc', async () => {
    const worker = new mongoose.Types.ObjectId();
    const a = await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 100,
      remaining: 100,
      status: 'outstanding',
    });
    const s = await svc.submitManualSettlement({
      workerId: worker,
      amount: 100,
      method: 'instapay',
      reference: 'IP-1',
      proofUrl: '/u/p.jpg',
    });
    expect(s.status).toBe('pending_verification');
    expect(s.debts.map(String)).toContain(String(a._id));
  });

  test('rejects unsupported method', async () => {
    const worker = new mongoose.Types.ObjectId();
    await expect(
      svc.submitManualSettlement({
        workerId: worker,
        amount: 50,
        method: 'wallet_balance',
        reference: 'x',
      }),
    ).rejects.toThrow();
  });
});

describe('verify/reject Settlement', () => {
  test('verify marks debts paid + settlement verified', async () => {
    const worker = new mongoose.Types.ObjectId();
    const admin = new mongoose.Types.ObjectId();
    const debt = await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 80,
      remaining: 80,
      status: 'outstanding',
    });
    const s = await svc.submitManualSettlement({
      workerId: worker,
      amount: 80,
      method: 'instapay',
      reference: 'XREF',
    });
    const result = await svc.verifyManualSettlement({ settlementId: s._id, adminId: admin });
    expect(result.settlement.status).toBe('verified');
    const after = await CashDebt.findById(debt._id);
    expect(after.status).toBe('paid');
    expect(after.remaining).toBe(0);
    expect(after.settlementMethod).toBe('instapay');
  });

  test('reject marks rejected, debts untouched', async () => {
    const worker = new mongoose.Types.ObjectId();
    const admin = new mongoose.Types.ObjectId();
    const debt = await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 80,
      remaining: 80,
      status: 'outstanding',
    });
    const s = await svc.submitManualSettlement({
      workerId: worker,
      amount: 80,
      method: 'instapay',
      reference: 'XREF',
    });
    await svc.rejectManualSettlement({ settlementId: s._id, adminId: admin, reason: 'no proof' });
    const after = await CashDebt.findById(debt._id);
    expect(after.status).toBe('outstanding');
    expect(after.remaining).toBe(80);
  });

  test('idempotent verify (second call throws)', async () => {
    const worker = new mongoose.Types.ObjectId();
    const admin = new mongoose.Types.ObjectId();
    await CashDebt.create({
      worker,
      booking: new mongoose.Types.ObjectId(),
      amount: 50,
      remaining: 50,
      status: 'outstanding',
    });
    const s = await svc.submitManualSettlement({
      workerId: worker,
      amount: 50,
      method: 'instapay',
      reference: 'XREF',
    });
    await svc.verifyManualSettlement({ settlementId: s._id, adminId: admin });
    await expect(svc.verifyManualSettlement({ settlementId: s._id, adminId: admin })).rejects.toThrow(/already/i);
  });
});
