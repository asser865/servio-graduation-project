const Notification = require('../notification.model');

async function send({ event, userId, template, payload }) {
  const title = typeof template.title === 'function' ? template.title(payload) : (template.title || event);
  const body  = typeof template.body  === 'function' ? template.body(payload)  : (template.body  || '');
  return Notification.create({
    userId,
    type:         template.type || 'system',
    title:        String(title).slice(0, 120),
    body:         String(body || event).slice(0, 280),
    referenceId:  payload?.bookingId ? String(payload.bookingId) : null,
    referenceUrl: payload?.url || null,
  });
}

module.exports = { send };
