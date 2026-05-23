const { TEMPLATES } = require('./templates');
const NotificationPreference = require('./preferences.model');

const defaultChannels = {
  email:    require('./channels/email.channel'),
  'in-app': require('./channels/in-app.channel'),
  push:     require('./channels/push.channel'),
  socket:   require('./channels/socket.channel'),
};

const overrides = {};

function _setChannelOverride(name, impl) {
  if (impl === null || impl === undefined) {
    delete overrides[name];
  } else {
    overrides[name] = impl;
  }
}

function _clearOverrides() {
  for (const k of Object.keys(overrides)) delete overrides[k];
}

function resolveRecipientId(payload) {
  return payload?.userId || payload?.customer || payload?.worker || payload?.user || payload?.recipient || null;
}

function channelKeyToPref(name) {
  if (name === 'in-app') return 'inApp';
  return name;
}

async function dispatch(event, payload = {}) {
  const template = TEMPLATES[event];
  if (!template) return { dispatched: false, reason: 'no_template' };

  const userId = resolveRecipientId(payload);
  if (!userId) return { dispatched: false, reason: 'no_recipient' };

  let pref = null;
  try {
    pref = await NotificationPreference.findOne({ user: userId });
  } catch (_) { /* preferences are optional */ }

  const channels = template.channels || ['in-app'];
  const results  = [];

  for (const ch of channels) {
    const prefKey  = channelKeyToPref(ch);
    const enabled  = pref?.channels?.[prefKey] ?? true;
    if (!enabled) {
      results.push({ channel: ch, sent: false, reason: 'pref_disabled' });
      continue;
    }
    const impl = overrides[ch] || defaultChannels[ch];
    if (!impl) {
      results.push({ channel: ch, sent: false, reason: 'no_impl' });
      continue;
    }
    try {
      await impl.send({ event, userId, template, payload });
      results.push({ channel: ch, sent: true });
    } catch (err) {
      results.push({ channel: ch, sent: false, error: err?.message || 'send_failed' });
    }
  }

  return { dispatched: true, channels: results };
}

function safeDispatch(event, payload) {
  return dispatch(event, payload).catch((err) => {
    try { console.error(`[notify] dispatch ${event} failed:`, err?.message || err); } catch (_) {}
    return { dispatched: false, error: err?.message || 'unknown' };
  });
}

module.exports = { dispatch, safeDispatch, _setChannelOverride, _clearOverrides, TEMPLATES };
