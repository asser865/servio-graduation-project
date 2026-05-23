const AdminSettings = require('./admin-settings.model');

let cache = null;

async function get() {
  if (cache) return cache;
  let doc = await AdminSettings.findOne({ key: 'global' });
  if (!doc) doc = await AdminSettings.create({ key: 'global' });
  cache = doc.toObject();
  return cache;
}

async function update(patch, adminId) {
  const doc = await AdminSettings.findOneAndUpdate(
    { key: 'global' },
    { $set: flatten(patch), updatedBy: adminId },
    { returnDocument: 'after', upsert: true }
  );
  cache = doc.toObject();
  return cache;
}

function flatten(obj, prefix = '', out = {}) {
  for (const [k, v] of Object.entries(obj)) {
    const path = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date)) {
      flatten(v, path, out);
    } else {
      out[path] = v;
    }
  }
  return out;
}

function reset() { cache = null; }

module.exports = { get, update, reset };
