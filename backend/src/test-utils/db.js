const { MongoMemoryReplSet } = require('mongodb-memory-server');
const mongoose = require('mongoose');

let mongo;

async function connect() {
  mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 } });
  await mongoose.connect(mongo.getUri());
}

async function disconnect() {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}

async function clear() {
  const collections = mongoose.connection.collections;
  for (const key in collections) await collections[key].deleteMany({});
  try { require('../modules/admin/admin-settings.service').reset(); } catch (_) {}
}

module.exports = { connect, disconnect, clear };
