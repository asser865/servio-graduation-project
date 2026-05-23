const db = require('../db');

beforeAll(db.connect);
afterAll(db.disconnect);
afterEach(db.clear);

test('connects to in-memory mongo', () => {
  const mongoose = require('mongoose');
  expect(mongoose.connection.readyState).toBe(1);
});
