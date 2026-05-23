const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const dispatcher = require('../dispatcher');
const Wallet = require('../../payments/wallet.model');
const payoutSvc = require('../../payments/payout-request.service');
const customerCreditSvc = require('../../payments/customer-credit.service');
const cashDebtSvc = require('../../payments/cash-debt.service');
const CashDebt = require('../../payments/cash-debt.model');
const DebtSettlement = require('../../payments/debt-settlement.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(async () => {
  dispatcher._clearOverrides();
  await db.clear();
});

function uid() { return new mongoose.Types.ObjectId(); }

function captureDispatches() {
  const events = [];
  const noop = { send: async () => 'ok' };
  for (const ch of ['email', 'in-app', 'push', 'socket']) dispatcher._setChannelOverride(ch, noop);
  // wrap by re-overriding to record
  for (const ch of ['email', 'in-app', 'push', 'socket']) {
    dispatcher._setChannelOverride(ch, { send: async ({ event, userId, payload }) => { events.push({ channel: ch, event, userId, payload }); } });
  }
  return events;
}

describe('dispatcher wired into services', () => {
  test('payout.approved fires on approvePayout', async () => {
    const events = captureDispatches();
    const worker = uid();
    const admin = uid();
    await Wallet.create({ worker, balance: 500 });
    const p = await payoutSvc.requestPayout({ workerId: worker, amount: 200, method: 'bank' });
    await payoutSvc.approvePayout({ payoutId: p._id, adminId: admin });
    await new Promise((r) => setTimeout(r, 100));
    const approved = events.filter((e) => e.event === 'payout.approved');
    expect(approved.length).toBeGreaterThan(0);
    expect(String(approved[0].userId)).toBe(String(worker));
  });

  test('payout.paid fires on markPayoutPaid', async () => {
    const events = captureDispatches();
    const worker = uid();
    const admin = uid();
    await Wallet.create({ worker, balance: 500 });
    const p = await payoutSvc.requestPayout({ workerId: worker, amount: 200, method: 'bank' });
    await payoutSvc.approvePayout({ payoutId: p._id, adminId: admin });
    await payoutSvc.markPayoutPaid({ payoutId: p._id, adminId: admin, transactionRef: 'TR-1' });
    await new Promise((r) => setTimeout(r, 100));
    const paid = events.filter((e) => e.event === 'payout.paid');
    expect(paid.length).toBeGreaterThan(0);
  });

  test('credit.issued fires on issueCredit', async () => {
    const events = captureDispatches();
    const customer = uid();
    await customerCreditSvc.issueCredit({
      customer, amount: 100, source: 'apology', reason: 'apology', issuedBy: uid(),
    });
    await new Promise((r) => setTimeout(r, 100));
    const issued = events.filter((e) => e.event === 'credit.issued');
    expect(issued.length).toBeGreaterThan(0);
    expect(String(issued[0].userId)).toBe(String(customer));
  });

  test('settlement.verified fires on verifyManualSettlement', async () => {
    const events = captureDispatches();
    const worker = uid();
    const admin = uid();
    const debt = await CashDebt.create({ worker, booking: uid(), amount: 50 });
    const settlement = await DebtSettlement.create({
      worker, debts: [debt._id], totalAmount: 50, method: 'bank_transfer',
      reference: 'REF-1', proofUrl: 'http://x', status: 'pending_verification',
    });
    await cashDebtSvc.verifyManualSettlement({ settlementId: settlement._id, adminId: admin });
    await new Promise((r) => setTimeout(r, 100));
    const verified = events.filter((e) => e.event === 'settlement.verified');
    expect(verified.length).toBeGreaterThan(0);
    expect(String(verified[0].userId)).toBe(String(worker));
  });

  test('settlement.rejected fires on rejectManualSettlement', async () => {
    const events = captureDispatches();
    const worker = uid();
    const admin = uid();
    const debt = await CashDebt.create({ worker, booking: uid(), amount: 50 });
    const settlement = await DebtSettlement.create({
      worker, debts: [debt._id], totalAmount: 50, method: 'bank_transfer',
      reference: 'REF-2', proofUrl: 'http://x', status: 'pending_verification',
    });
    await cashDebtSvc.rejectManualSettlement({ settlementId: settlement._id, adminId: admin, reason: 'bad proof' });
    await new Promise((r) => setTimeout(r, 100));
    const rejected = events.filter((e) => e.event === 'settlement.rejected');
    expect(rejected.length).toBeGreaterThan(0);
  });

  test('notification failure does not break business call', async () => {
    for (const ch of ['email', 'in-app', 'push', 'socket']) {
      dispatcher._setChannelOverride(ch, { send: async () => { throw new Error('boom'); } });
    }
    const customer = uid();
    const credit = await customerCreditSvc.issueCredit({
      customer, amount: 25, source: 'admin_grant', issuedBy: uid(),
    });
    expect(credit._id).toBeDefined();
    expect(credit.amount).toBe(25);
  });
});
