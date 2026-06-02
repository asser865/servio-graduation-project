const mongoose = require('mongoose');
const request = require('supertest');
const db = require('../../../test-utils/db');
const app = require('../../../app');
const { generateToken } = require('../../auth/auth.service');
const User = require('../../users/user.model');
const Booking = require('../../bookings/booking.model');
const CashDebt = require('../cash-debt.model');
const Payment = require('../payment.model');
const PayoutRequest = require('../payout-request.model');
const historyService = require('../earnings-history.service');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

function id() { return new mongoose.Types.ObjectId(); }

async function createBooking(worker, overrides = {}) {
  return Booking.create({
    user: id(),
    worker,
    service: id(),
    serviceCategory: 'Plumbing',
    serviceName: 'Leak repair',
    scheduledDate: new Date('2026-05-10T08:00:00.000Z'),
    address: 'Nasr City, Cairo',
    status: 'completed',
    paymentMethod: 'card',
    ...overrides,
  });
}

describe('earningsHistoryService', () => {
  test('returns paginated withdrawals and applies status filters', async () => {
    const worker = id();
    await PayoutRequest.create([
      { worker, amount: 120, payoutMethod: 'bank', status: 'paid', transactionRef: 'BANK-120' },
      { worker, amount: 80, payoutMethod: 'instapay', status: 'pending' },
    ]);

    const result = await historyService.listWorkerHistory(worker, {
      category: 'withdrawals',
      status: 'paid',
      page: 1,
      limit: 1,
    });

    expect(result.category).toBe('withdrawals');
    expect(result.meta).toEqual({ page: 1, limit: 1, total: 1 });
    expect(result.items[0]).toMatchObject({
      amount: 120,
      method: 'bank',
      status: 'paid',
      receipt: 'BANK-120',
    });
  });

  test('returns pending, released, and disputed payment history with plain statuses', async () => {
    const worker = id();
    const user = id();
    const heldBooking = await createBooking(worker, { serviceName: 'Valve install' });
    const releasedBooking = await createBooking(worker, { serviceName: 'Pipe repair' });
    const disputedBooking = await createBooking(worker, { serviceName: 'Drain repair' });

    await Payment.create([
      { booking: heldBooking._id, user, worker, amount: 100, workerEarning: 90, status: 'held', skipFeeCalc: true, heldAt: new Date('2026-05-01') },
      { booking: releasedBooking._id, user, worker, amount: 200, workerEarning: 180, status: 'released', skipFeeCalc: true, heldAt: new Date('2026-05-02'), releasedAt: new Date('2026-05-04') },
      { booking: disputedBooking._id, user, worker, amount: 300, workerEarning: 270, status: 'disputed', skipFeeCalc: true, heldAt: new Date('2026-05-03') },
    ]);

    const result = await historyService.listWorkerHistory(worker, { category: 'releases' });

    expect(result.meta.total).toBe(3);
    expect(result.items.map(item => item.status).sort()).toEqual([
      'needs_review',
      'released',
      'waiting_for_release',
    ]);
    expect(result.items.map(item => item.job)).toEqual(expect.arrayContaining([
      'Valve install',
      'Pipe repair',
      'Drain repair',
    ]));
  });

  test('returns only paid fee history with settlement details and date filters', async () => {
    const worker = id();
    const oldBooking = await createBooking(worker, { serviceName: 'Old repair' });
    const recentBooking = await createBooking(worker, { serviceName: 'Recent repair' });
    await CashDebt.create([
      { worker, booking: oldBooking._id, amount: 20, paidAmount: 20, remaining: 0, status: 'paid', paidAt: new Date('2026-04-01'), settlementMethod: 'auto_offset' },
      { worker, booking: recentBooking._id, amount: 35, paidAmount: 35, remaining: 0, status: 'paid', paidAt: new Date('2026-05-15'), settlementMethod: 'wallet_balance' },
      { worker, booking: id(), amount: 15, remaining: 15, status: 'outstanding' },
    ]);

    const result = await historyService.listWorkerHistory(worker, {
      category: 'fees',
      from: '2026-05-01',
      to: '2026-05-15',
    });

    expect(result.meta.total).toBe(1);
    expect(result.items[0]).toMatchObject({
      job: 'Recent repair',
      amount: 35,
      method: 'wallet_balance',
      status: 'paid',
    });
  });

  test.each([
    [{ category: 'unknown' }, /category/],
    [{ category: 'fees', limit: 0 }, /integer/],
    [{ category: 'releases', status: 'paid' }, /Unsupported/],
    [{ category: 'withdrawals', from: 'not-a-date' }, /valid date/],
    [{ category: 'withdrawals', from: '2026-06-01', to: '2026-05-01' }, /before/],
  ])('rejects invalid query %j', async (params, message) => {
    await expect(historyService.listWorkerHistory(id(), params)).rejects.toThrow(message);
  });
});

describe('GET /api/v1/payments/earnings/history', () => {
  test('allows workers and rejects customer accounts', async () => {
    const worker = await User.create({
      name: 'Worker One',
      email: 'worker-history@example.com',
      password: 'password123',
      role: 'worker',
    });
    const customer = await User.create({
      name: 'Customer One',
      email: 'customer-history@example.com',
      password: 'password123',
      role: 'user',
    });

    const workerResponse = await request(app)
      .get('/api/v1/payments/earnings/history?category=withdrawals')
      .set('Authorization', `Bearer ${generateToken(worker._id, worker.role)}`);
    const customerResponse = await request(app)
      .get('/api/v1/payments/earnings/history?category=withdrawals')
      .set('Authorization', `Bearer ${generateToken(customer._id, customer.role)}`);

    expect(workerResponse.status).toBe(200);
    expect(workerResponse.body.data).toMatchObject({
      category: 'withdrawals',
      items: [],
      meta: { page: 1, limit: 10, total: 0 },
    });
    expect(customerResponse.status).toBe(403);
  });
});
