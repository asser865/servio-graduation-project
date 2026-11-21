// backend/src/modules/auth/__tests__/register-services-subdoc.test.js
//
// Regression test (review finding, Tasks 4+5 follow-up):
// Worker registration must persist `services` in the NEW subdoc shape
// [{ serviceId, startsFrom }], not the OLD flat-ObjectId shape.
// Passing flat ObjectIds straight into `User.create({ services })` throws
// a Mongoose CastError against the current `user.model.js` schema.

const mongoose = require('mongoose');
const db = require('../../../test-utils/db');
const User = require('../../users/user.model');
const Service = require('../../services/service.model');
const { registerUser } = require('../auth.service');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';
process.env.JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('worker registration with services persists [{serviceId, startsFrom}] subdocs', async () => {
  const service = await Service.create({
    title: 'Pipe Repair',
    description: 'Fix leaking pipes',
    category: 'plumbing',
    basePrice: 275,
    priceUnit: 'fixed',
    estimatedDurationMin: 60, // schema default(0) violates its own min(15) — must set explicitly
    createdBy: new mongoose.Types.ObjectId(),
  });

  const { user } = await registerUser({
    name: 'Ali Samir',
    email: `ali${Date.now()}@example.com`,
    password: 'Password1',
    role: 'worker',
    services: [service._id],
  });

  const saved = await User.findById(user._id);
  expect(saved.services).toHaveLength(1);
  expect(saved.services[0].serviceId.toString()).toBe(service._id.toString());
  expect(saved.services[0].startsFrom).toBe(service.basePrice);
});
