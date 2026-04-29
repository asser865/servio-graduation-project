const AuditLog = require('./audit.model');

/**
 * Fire-and-forget audit event logger.
 * Never throws — logging must never crash a main operation.
 *
 * @param {object} opts
 * @param {object} [opts.req]        - Express request (extracts actor + IP automatically)
 * @param {string} opts.type         - 'auth'|'user'|'booking'|'service'|'settings'|'finance'|'system'
 * @param {string} opts.action       - Human-readable action description
 * @param {string} [opts.target]     - What was affected (name/ID of target resource)
 * @param {string} [opts.status]     - 'ok'|'warn'|'fail'
 * @param {string} [opts.actorEmail] - Override actor email (for failed logins where req.user is absent)
 */
function logEvent({ req, type, action, target = '', status = 'ok', actorEmail }) {
  const actor = {
    id:    req?.user?.id    || null,
    email: actorEmail || req?.user?.email || 'unknown',
    role:  req?.user?.role  || 'unknown',
  };

  const getClientIp = (r) => {
    const forwarded = r.headers['x-forwarded-for'];
    if (process.env.TRUST_PROXY === 'true' && forwarded) {
      return forwarded.split(',')[0].trim();
    }
    return r.connection?.remoteAddress || r.socket?.remoteAddress || 'unknown';
  };
  const ip = req ? getClientIp(req) : '';

  AuditLog.create({ actor, type, action, target, ip, status })
    .catch(err => console.error('[AuditLog] write failed:', err.message));
}

module.exports = { logEvent };
