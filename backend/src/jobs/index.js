const cron = require('node-cron');
const autoConfirm = require('./auto-confirm-bookings.job');
const disputeSla = require('./dispute-sla.job');

async function runAutoConfirm() {
  try {
    const r = await autoConfirm.runOnce();
    if (r.confirmed || r.repaired) {
      console.log(`[auto-confirm] confirmed=${r.confirmed} repaired=${r.repaired} scanned=${r.scanned}`);
    }
  } catch (err) {
    console.error('[auto-confirm] error:', err);
  }
}

function start() {
  if (process.env.NODE_ENV === 'test') return;
  runAutoConfirm();
  cron.schedule('*/15 * * * *', runAutoConfirm);
  disputeSla.start();
}

module.exports = { start, runAutoConfirm };
