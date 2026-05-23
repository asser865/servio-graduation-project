let mailer;
try { mailer = require('../../../utils/email'); } catch (_) { mailer = null; }

const User = require('../../users/user.model');

async function send({ event, userId, template, payload }) {
  if (!mailer || typeof mailer.sendEmail !== 'function') return null;
  const user = await User.findById(userId).select('email name');
  if (!user?.email) return null;

  const title = typeof template.title === 'function' ? template.title(payload) : (template.title || event);
  const body  = typeof template.body  === 'function' ? template.body(payload)  : (template.body  || '');

  return mailer.sendEmail({
    to:      user.email,
    subject: String(title).slice(0, 200),
    html:    `<p>Hi ${user.name || ''},</p><p>${body}</p>`,
    text:    body,
  });
}

module.exports = { send };
