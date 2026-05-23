const express = require('express');
const supertest = require('supertest');
const { paginated, single } = require('../envelope.middleware');

test('paginated wraps list result', async () => {
  const app = express();
  app.get('/items', (req, res) => paginated(res, { items: [{ id: 1 }], page: 1, limit: 20, total: 1 }));
  const r = await supertest(app).get('/items');
  expect(r.body).toEqual({
    data: [{ id: 1 }],
    meta: { page: 1, limit: 20, total: 1, totalPages: 1 },
  });
});

test('single wraps doc', async () => {
  const app = express();
  app.get('/x', (req, res) => single(res, { id: 1, name: 'a' }));
  const r = await supertest(app).get('/x');
  expect(r.body).toEqual({ data: { id: 1, name: 'a' } });
});
