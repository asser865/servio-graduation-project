'use strict';

const request = require('supertest');

jest.mock('../src/middleware/auth.middleware', () => ({
  protect: (req, res, next) => {
    req.user = { id: '664000000000000000000010', role: 'worker', email: 'worker@example.com' };
    next();
  },
}));

jest.mock('../src/middleware/role.middleware', () => ({
  authorize: (...roles) => (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    next();
  },
}));

jest.mock('../src/modules/payments/payment.service', () => ({
  updateWorkerPayoutSettings: jest.fn(),
}));

const paymentService = require('../src/modules/payments/payment.service');
const app = require('../src/app');

describe('payment settings routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('PATCH /payments/settings parses JSON body before controller runs', async () => {
    const wallet = {
      _id: 'wallet123',
      payoutMethod: 'instapay',
      payoutSchedule: 'monthly',
      payoutDetails: { walletNumber: '01000000000' },
    };

    paymentService.updateWorkerPayoutSettings.mockResolvedValue(wallet);

    const payload = {
      payoutMethod: 'instapay',
      payoutSchedule: 'monthly',
      payoutDetails: { walletNumber: '01000000000' },
    };

    const res = await request(app)
      .patch('/api/v1/payments/settings')
      .send(payload)
      .expect(200);

    expect(paymentService.updateWorkerPayoutSettings).toHaveBeenCalledWith(
      '664000000000000000000010',
      payload
    );
    expect(res.body.data).toEqual(wallet);
  });

  test('PATCH /payments/settings rejects an empty body', async () => {
    const res = await request(app)
      .patch('/api/v1/payments/settings')
      .send({})
      .expect(400);

    expect(paymentService.updateWorkerPayoutSettings).not.toHaveBeenCalled();
    expect(res.body.message).toBe('At least one payout setting is required.');
  });
});
