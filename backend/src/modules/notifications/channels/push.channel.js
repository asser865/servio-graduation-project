async function send({ event, userId, template, payload }) {
  if (process.env.PUSH_PROVIDER) {
    try {
      const provider = require(`./push.${process.env.PUSH_PROVIDER}`);
      return provider.send({ event, userId, template, payload });
    } catch (_) { return null; }
  }
  return null;
}

module.exports = { send };
