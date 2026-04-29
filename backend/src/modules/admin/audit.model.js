const mongoose = require('mongoose');

const auditSchema = new mongoose.Schema(
  {
    actor: {
      id:    { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      email: { type: String, default: 'unknown' },
      role:  { type: String, default: 'unknown' },
    },
    type:   { type: String, enum: ['auth','user','booking','service','settings','finance','system'], required: true },
    action: { type: String, required: true },
    target: { type: String, default: '' },
    ip:     { type: String, default: '' },
    status: { type: String, enum: ['ok','warn','fail'], default: 'ok' },
  },
  {
    timestamps: true,
  }
);

// Auto-delete logs older than 90 days
auditSchema.index({ createdAt: 1 }, { expireAfterSeconds: 90 * 24 * 60 * 60 });
auditSchema.index({ type: 1, createdAt: -1 });

module.exports = mongoose.model('AuditLog', auditSchema);
