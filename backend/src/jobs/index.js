const cron = require('node-cron');
const autoConfirm = require('./auto-confirm-bookings.job');
const disputeSla = require('./dispute-sla.job');

function start() {
  if (process.env.NODE_ENV === 'test') return;
  cron.schedule('*/15 * * * *', async () => {
    try {
      const r = await autoConfirm.runOnce();
      if (r.confirmed) console.log(`[auto-confirm] confirmed=${r.confirmed} scanned=${r.scanned}`);
    } catch (err) {
      console.error('[auto-confirm] error:', err);
    }
  });
  disputeSla.start();
}

module.exports = { start };
