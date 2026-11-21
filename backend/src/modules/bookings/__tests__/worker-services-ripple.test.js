// backend/src/modules/bookings/__tests__/worker-services-ripple.test.js
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const User = require('../../users/user.model');
const Service = require('../../services/service.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('worker discovery query matches by services.serviceId', async () => {
  const svc = await Service.create({
    title: 'Pipe', description: 'd', category: 'plumbing', basePrice: 300,
    priceUnit: 'fixed', estimatedDurationMin: 60, createdBy: new mongoose.Types.ObjectId(),
  });
  await User.create({
    name: 'T', email: `t${Date.now()}@x.com`, password: 'x12345678', role: 'worker',
    services: [{ serviceId: svc._id, startsFrom: 300 }],
  });
  const found = await User.find({ 'services.serviceId': svc._id });
  expect(found).toHaveLength(1);
});
