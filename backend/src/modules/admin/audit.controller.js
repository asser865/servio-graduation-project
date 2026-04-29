const { StatusCodes } = require('http-status-codes');
const AuditLog        = require('./audit.model');
const ApiResponse     = require('../../utils/ApiResponse');

const getLogs = async (req, res) => {
  const { type, status, days, page = 1, limit = 20, q } = req.query;

  const filter = {};
  if (type)   filter.type   = type;
  if (status) filter.status = status;
  if (days) {
    const cutoff = new Date(Date.now() - Number(days) * 86400000);
    filter.createdAt = { $gte: cutoff };
  }
  if (q) {
    const re = new RegExp(q, 'i');
    filter.$or = [
      { 'actor.email': re },
      { action: re },
      { target: re },
      { ip: re },
    ];
  }

  const skip = (Number(page) - 1) * Number(limit);
  const [logs, total] = await Promise.all([
    AuditLog.find(filter).sort({ createdAt: -1 }).skip(skip).limit(Number(limit)),
    AuditLog.countDocuments(filter),
  ]);

  // Stat counts for the badge pills (always over all data, ignoring filters)
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const [todayCount, failCount] = await Promise.all([
    AuditLog.countDocuments({ createdAt: { $gte: today } }),
    AuditLog.countDocuments({ status: 'fail' }),
  ]);

  return ApiResponse.success(res, StatusCodes.OK, 'Audit logs retrieved.', {
    logs,
    pagination: { total, page: Number(page), limit: Number(limit), totalPages: Math.ceil(total / Number(limit)) },
    stats: { total: await AuditLog.estimatedDocumentCount(), todayCount, failCount },
  });
};

const deleteLog = async (req, res) => {
  const { id } = req.params;
  const log = await AuditLog.findByIdAndDelete(id);
  
  if (!log) {
    return ApiResponse.error(res, StatusCodes.NOT_FOUND, 'Audit log entry not found.');
  }

  return ApiResponse.success(res, StatusCodes.OK, 'Audit log entry deleted successfully.');
};

module.exports = { getLogs, deleteLog };
