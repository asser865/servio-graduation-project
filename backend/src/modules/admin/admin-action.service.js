const AdminAction = require('./admin-action.model');

async function record({ adminId, actionType, targetType, targetId, details = {}, ipAddress, session }) {
  const doc = new AdminAction({
    admin:      adminId,
    actionType,
    targetType,
    targetId,
    details,
    ipAddress,
  });
  await doc.save({ session });
  return doc;
}

async function list({ adminId, actionType, from, to, limit = 20, page = 1 } = {}) {
  const q = {};
  if (adminId)    q.admin = adminId;
  if (actionType) q.actionType = actionType;
  if (from || to) {
    q.createdAt = {};
    if (from) q.createdAt.$gte = new Date(from);
    if (to)   q.createdAt.$lte = new Date(to);
  }
  const total = await AdminAction.countDocuments(q);
  const data  = await AdminAction.find(q)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(Math.min(limit, 100));
  return { data, meta: { page, limit, total, totalPages: Math.ceil(total / limit) } };
}

module.exports = { record, list };
