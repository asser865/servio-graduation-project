async function recordIncident(workerId, payload) {
  console.log('[trust] incident', workerId, payload);
}

module.exports = { recordIncident };
