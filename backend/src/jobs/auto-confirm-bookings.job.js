const Booking = require('../modules/bookings/booking.model');
const settings = require('../modules/admin/admin-settings.service');

let notify;
try { notify = require('../modules/notifications/notify.service'); } catch (_) {
  notify = { sendToUser: async () => {} };
}

async function runOnce() {
  const now = new Date();
  const cfg = await settings.get();
  const totalMs = cfg.escrow.autoConfirmHours * 3600 * 1000;

  const all = await Booking.find({ status: 'awaiting_customer_confirmation' });
  let confirmed = 0, reminded = 0;

  for (const b of all) {
    const startMs = b.customerConfirmAutoAt ? b.customerConfirmAutoAt.getTime() - totalMs : null;
    const elapsedH = startMs ? (now - startMs) / 3600 / 1000 : 0;

    if (b.customerConfirmAutoAt && b.customerConfirmAutoAt < now) {
      const updated = await Booking.findOneAndUpdate(
        { _id: b._id, status: 'awaiting_customer_confirmation' },
        { $set: { status: 'pending_admin_review', customerConfirmedVia: 'system_auto' } },
        { returnDocument: 'after' }
      );
      if (updated) {
        confirmed++;
        await notify.sendToUser({ userId: updated.user, event: 'auto_confirmed' });
        await notify.sendToUser({ userId: updated.worker, event: 'pending_admin_review' });
      }
      continue;
    }

    for (const markH of cfg.escrow.reminderHours) {
      if (elapsedH >= markH && !b.confirmRemindersSent.includes(markH)) {
        await notify.sendToUser({ userId: b.user, event: `confirm_reminder_${markH}h`, bookingId: b._id });
        b.confirmRemindersSent.push(markH);
        await b.save();
        reminded++;
      }
    }
  }
  return { scanned: all.length, confirmed, reminded };
}

module.exports = { runOnce };
