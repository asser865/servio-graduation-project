// backend/src/modules/users/__tests__/worker-services-pricing.test.js
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const User = require('../user.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('worker.services stores serviceId + startsFrom subdocs', async () => {
  const sid = new mongoose.Types.ObjectId();
  const u = await User.create({
    name: 'Tech', email: `t${Date.now()}@x.com`, password: 'x12345678', role: 'worker',
    services: [{ serviceId: sid, startsFrom: 350 }],
  });
  expect(u.services[0].serviceId.toString()).toBe(sid.toString());
  expect(u.services[0].startsFrom).toBe(350);
});
