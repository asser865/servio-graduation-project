const db = require('../../../test-utils/db');
const Booking = require('../booking.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

const baseFixture = () => ({
  user: '64b7a7a7a7a7a7a7a7a7a7a7',
  worker: '64b7a7a7a7a7a7a7a7a7a7a8',
  service: '64b7a7a7a7a7a7a7a7a7a7a9',
  serviceCategory: 'plumbing',
  scheduledDate: new Date('2026-06-01'),
  address: '12 Test St',
  paymentMethod: 'online',
  totalPrice: 100,
  platformFeeAmount: 18,
});

test('accepts new status awaiting_customer_confirmation', async () => {
  const b = await Booking.create({ ...baseFixture(), status: 'awaiting_customer_confirmation' });
  expect(b.status).toBe('awaiting_customer_confirmation');
});

test('accepts new status pending_admin_review', async () => {
  const b = await Booking.create({ ...baseFixture(), status: 'pending_admin_review' });
  expect(b.status).toBe('pending_admin_review');
});

test('accepts new no-show / re-pool statuses', async () => {
  for (const s of ['cancelled_no_show', 'customer_no_show', 'worker_no_show', 're_pooling']) {
    const b = await Booking.create({ ...baseFixture(), status: s });
    expect(b.status).toBe(s);
  }
});

test('rejects unknown status', async () => {
  await expect(Booking.create({ ...baseFixture(), status: 'bogus' })).rejects.toThrow();
});

test('stamps completedAt on status=completed', async () => {
  const b = await Booking.create({ ...baseFixture(), status: 'pending' });
  b.status = 'completed';
  await b.save();
  expect(b.completedAt).toBeInstanceOf(Date);
});

test('stamps releasedAt when status set to released via paymentStatus', async () => {
  const b = await Booking.create({ ...baseFixture(), status: 'completed' });
  b.paymentStatus = 'released';
  await b.save();
  expect(b.releasedAt).toBeInstanceOf(Date);
});

test('customerConfirmedVia accepts enum values', async () => {
  const b = await Booking.create({ ...baseFixture(), customerConfirmedVia: 'system_auto' });
  expect(b.customerConfirmedVia).toBe('system_auto');
});
