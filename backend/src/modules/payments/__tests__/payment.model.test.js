const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const Payment = require('../payment.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('stores gateway intent + charge ids', async () => {
  const p = await Payment.create({
    booking:         new mongoose.Types.ObjectId(),
    user:            new mongoose.Types.ObjectId(),
    worker:          new mongoose.Types.ObjectId(),
    amount:          120,
    currency:        'EGP',
    status:          'held',
    gatewayIntentId: 'demo_pi_abc',
    gatewayChargeId: 'demo_ch_xyz',
  });
  expect(p.gatewayIntentId).toBe('demo_pi_abc');
  expect(p.refundAttempts).toBe(0);
});
