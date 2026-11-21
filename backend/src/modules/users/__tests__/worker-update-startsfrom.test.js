// backend/src/modules/users/__tests__/worker-update-startsfrom.test.js
//
// Task 16: the worker-profile UPDATE endpoint must accept and persist
// services: [{ serviceId, startsFrom }] subdocs (not just a flat array of
// ObjectIds), and the worker read paths (GET /me, GET /workers/:id) must
// expose services[].startsFrom in the response.
const supertest = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';

const app = require('../../../app');
const User = require('../user.model');
const Service = require('../../services/service.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

async function makeWorker() {
  const u = await User.create({
    name: 'Tech',
    email: `t${Date.now()}_${Math.random().toString(36).slice(2, 7)}@x.com`,
    password: 'Password123!',
    role: 'worker',
    isActive: true,
  });
  const token = jwt.sign({ id: u._id, role: u.role, authVersion: u.authVersion ?? 0 }, process.env.JWT_SECRET);
  return { user: u, token };
}

async function makeService(overrides = {}) {
  return Service.create({
    title: 'Pipe Repair',
    description: 'Fix leaky pipes',
    category: 'plumbing',
    basePrice: 100,
    priceUnit: 'fixed',
    estimatedDurationMin: 30,
    createdBy: new mongoose.Types.ObjectId(),
    ...overrides,
  });
}

describe('worker profile update — services[].startsFrom', () => {
  test('PATCH /me accepts services:[{serviceId, startsFrom}] and persists the custom startsFrom', async () => {
    const { user, token } = await makeWorker();
    const service = await makeService();

    const r = await supertest(app)
      .patch('/api/v1/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ services: [{ serviceId: service._id.toString(), startsFrom: 350 }] });

    expect(r.status).toBe(200);

    // Response body must expose the persisted startsFrom (read serializer).
    const returnedServices = r.body.data.services || r.body.data.user?.services;
    expect(Array.isArray(returnedServices)).toBe(true);
    expect(returnedServices).toHaveLength(1);
    expect(returnedServices[0].startsFrom).toBe(350);

    // DB must hold the custom startsFrom, not the service's basePrice default.
    const persisted = await User.findById(user._id);
    expect(persisted.services).toHaveLength(1);
    expect(persisted.services[0].serviceId.toString()).toBe(service._id.toString());
    expect(persisted.services[0].startsFrom).toBe(350);
  });

  test('GET /me exposes services[].startsFrom after the update', async () => {
    const { user, token } = await makeWorker();
    const service = await makeService();

    await User.findByIdAndUpdate(user._id, {
      services: [{ serviceId: service._id, startsFrom: 275 }],
    });

    const r = await supertest(app)
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${token}`);

    expect(r.status).toBe(200);
    expect(r.body.data.services[0].startsFrom).toBe(275);
  });

  test('GET /workers/:id exposes services[].startsFrom for a verified worker', async () => {
    const { user } = await makeWorker();
    const service = await makeService();

    await User.findByIdAndUpdate(user._id, {
      isVerified: true,
      isActive: true,
      services: [{ serviceId: service._id, startsFrom: 420 }],
    });

    const r = await supertest(app).get(`/api/v1/users/workers/${user._id}`);

    expect(r.status).toBe(200);
    expect(r.body.data.worker.services[0].startsFrom).toBe(420);
  });
});
