jest.mock('../cash-debt.model', () => ({
  aggregate: jest.fn(),
}));

jest.mock('../debt-settlement.model', () => ({
  find: jest.fn(),
}));

jest.mock('../../users/user.model', () => ({
  find: jest.fn(),
}));

const CashDebt = require('../cash-debt.model');
const DebtSettlement = require('../debt-settlement.model');
const User = require('../../users/user.model');
const controller = require('../payment.controller');

test('grouped cash debts include recovery progress and pending settlement methods', async () => {
  const workerId = 'worker-1';
  const oldest = new Date('2026-05-01T10:00:00.000Z');
  const latest = new Date('2026-05-03T10:00:00.000Z');
  const submittedAt = new Date('2026-05-04T10:00:00.000Z');

  CashDebt.aggregate.mockResolvedValue([{
    _id: workerId,
    totalOwed: 75,
    originalTotal: 100,
    amountRecovered: 25,
    debtCount: 2,
    oldest,
    latest,
    statuses: ['outstanding', 'partially_paid'],
    debtTypes: ['platform_fee'],
  }]);
  User.find.mockReturnValue({
    select: jest.fn().mockResolvedValue([{ _id: workerId, name: 'Test Worker', email: 'worker@example.com' }]),
  });
  DebtSettlement.find.mockReturnValue({
    select: jest.fn().mockResolvedValue([
      { worker: workerId, totalAmount: 50, method: 'instapay', submittedAt },
      { worker: workerId, totalAmount: 25, method: 'bank_transfer', submittedAt },
    ]),
  });
  const res = { json: jest.fn(value => value) };

  await controller.adminListCashDebtsGrouped({}, res);

  expect(res.json).toHaveBeenCalledWith({
    data: [{
      workerId,
      worker: { _id: workerId, name: 'Test Worker', email: 'worker@example.com' },
      totalOwed: 75,
      originalTotal: 100,
      amountRecovered: 25,
      debtCount: 2,
      oldest,
      latest,
      statusMix: ['outstanding', 'partially_paid'],
      debtTypes: ['platform_fee'],
      pendingSettlementCount: 2,
      pendingSettlementAmount: 75,
      pendingSettlementMethods: ['instapay', 'bank_transfer'],
      latestSettlementAt: submittedAt,
    }],
  });
});
