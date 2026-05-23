const supertest = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const db = require('../../../test-utils/db');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';

const app = require('../../../app');
const User = require('../../users/user.model');
const NotificationPreference = require('../preferences.model');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

async function makeUser(role = 'user') {
  const u = await User.create({
    name: 'Test',
    email: `t${Date.now()}_${Math.random().toString(36).slice(2,7)}@x.com`,
    password: 'Password123!',
    role,
    isActive: true,
  });
  const token = jwt.sign({ id: u._id, role: u.role, authVersion: u.authVersion ?? 0 }, process.env.JWT_SECRET);
  return { user: u, token };
}

describe('notification preferences routes', () => {
  test('GET returns defaults when no record exists', async () => {
    const { token } = await makeUser();
    const r = await supertest(app)
      .get('/api/v1/notifications/preferences')
      .set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(200);
    expect(r.body.data.channels.email).toBe(true);
    expect(r.body.data.channels.inApp).toBe(true);
    expect(r.body.data.channels.push).toBe(true);
    expect(r.body.data.channels.sms).toBe(false);
  });

  test('PUT upserts and updates one channel', async () => {
    const { user, token } = await makeUser();
    const r = await supertest(app)
      .put('/api/v1/notifications/preferences')
      .set('Authorization', `Bearer ${token}`)
      .send({ channels: { email: false } });
    expect(r.status).toBe(200);
    expect(r.body.data.channels.email).toBe(false);
    expect(r.body.data.channels.inApp).toBe(true);

    const persisted = await NotificationPreference.findOne({ user: user._id });
    expect(persisted.channels.email).toBe(false);
    expect(persisted.channels.inApp).toBe(true);
  });

  test('PUT rejects missing channels body', async () => {
    const { token } = await makeUser();
    const r = await supertest(app)
      .put('/api/v1/notifications/preferences')
      .set('Authorization', `Bearer ${token}`)
      .send({});
    expect(r.status).toBe(400);
  });

  test('PUT ignores unknown channel keys', async () => {
    const { user, token } = await makeUser();
    const r = await supertest(app)
      .put('/api/v1/notifications/preferences')
      .set('Authorization', `Bearer ${token}`)
      .send({ channels: { email: false, bogus: true } });
    expect(r.status).toBe(200);
    expect(r.body.data.channels.bogus).toBeUndefined();
    const persisted = await NotificationPreference.findOne({ user: user._id });
    expect(persisted.channels.email).toBe(false);
  });

  test('GET requires auth', async () => {
    const r = await supertest(app).get('/api/v1/notifications/preferences');
    expect(r.status).toBe(401);
  });
});
