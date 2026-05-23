const getGateway = require('../index');

test('factory returns demo gateway by default', () => {
  process.env.PAYMENT_GATEWAY = 'demo';
  const gw = getGateway();
  expect(gw.id).toBe('demo');
});

test('demo.authorize returns held intent', async () => {
  const gw = getGateway();
  const r = await gw.authorize({ amount: 100, currency: 'EGP', customerId: 'c1' });
  expect(r.status).toBe('authorized');
  expect(r.intentId).toMatch(/^demo_pi_/);
});

test('demo.capture transitions to captured', async () => {
  const gw = getGateway();
  const a = await gw.authorize({ amount: 100, currency: 'EGP', customerId: 'c1' });
  const c = await gw.capture({ intentId: a.intentId });
  expect(c.status).toBe('captured');
  expect(c.chargeId).toMatch(/^demo_ch_/);
});

test('demo.refund returns refund record', async () => {
  const gw = getGateway();
  const r = await gw.refund({ chargeId: 'demo_ch_x', amount: 50, reason: 'test' });
  expect(r.status).toBe('refunded');
  expect(r.refundId).toMatch(/^demo_rf_/);
});

test('stripe gateway raises NotImplemented', () => {
  process.env.PAYMENT_GATEWAY = 'stripe';
  const gw = getGateway();
  expect(gw.id).toBe('stripe');
  return expect(gw.authorize({ amount: 1, currency: 'EGP', customerId: 'c' }))
    .rejects.toThrow('NotImplemented');
});
