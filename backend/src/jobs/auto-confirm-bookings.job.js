const Booking = require('../modules/bookings/booking.model');
const settings = require('../modules/admin/admin-settings.service');
const autoFeeDebt = require('../modules/payments/auto-fee-debt.service');
const enhancedReview = require('../modules/finance/enhanced-review.service');

let notify;
try { notify = require('../modules/notifications/notify.service'); } catch (_) {
  notify = { sendToUser: async () => {} };
}

async function runOnce() {
  const now = new Date();
  const cfg = await settings.get();
  const totalMs = cfg.escrow.autoConfirmHours * 3600 * 1000;

  const all = await Booking.find({ status: 'awaiting_customer_confirmation' });
  let confirmed = 0, reminded = 0, safeguarded = 0;

  for (const b of all) {
    const confirmAt = confirmationDeadline(b, totalMs);
    const startMs = confirmAt ? confirmAt.getTime() - totalMs : null;
    const elapsedH = startMs ? (now - startMs) / 3600 / 1000 : 0;

    if (confirmAt && confirmAt < now) {
      const review = await enhancedReview.shouldBlock(b);
      const updated = await Booking.findOneAndUpdate(
        { _id: b._id, status: 'awaiting_customer_confirmation' },
        { $set: {
          status: 'pending_admin_review',
          ...(review.blocked
            ? { enhancedReviewReason: review.reason }
            : {
              customerConfirmedAt: now,
              customerConfirmedVia: 'system_auto',
              customerFeedback: {
                action: 'system_auto_confirmed',
                submittedAt: now,
                confirmedVia: 'system_auto',
              },
            }),
        } },
        { returnDocument: 'after' }
      );
      if (updated) {
        if (review.blocked) {
          safeguarded++;
          await notify.sendToUser({ userId: updated.worker, event: 'pending_admin_review' });
          continue;
        }
        confirmed++;
        let finalBooking = updated;
        if (updated.paymentMethod === 'cash') {
          const result = await autoFeeDebt.createIfClean(updated._id);
          finalBooking = result.booking || updated;
        }
        await notify.sendToUser({ userId: updated.user, event: 'auto_confirmed' });
        await notify.sendToUser({
          userId: updated.worker,
          event: finalBooking.status === 'completed' ? 'cash_fee_debt_created' : 'pending_admin_review',
        });
      }
      continue;
    }

    for (const markH of cfg.escrow.reminderHours) {
      if (elapsedH >= markH && !list(b.confirmRemindersSent).includes(markH)) {
        await notify.sendToUser({ userId: b.user, event: `confirm_reminder_${markH}h`, bookingId: b._id });
        if (!Array.isArray(b.confirmRemindersSent)) b.confirmRemindersSent = [];
        b.confirmRemindersSent.push(markH);
        await b.save();
        reminded++;
      }
    }
  }
  const repaired = await repairStrandedCashConfirmations();
  return { scanned: all.length, confirmed, reminded, safeguarded, repaired };
}

async function repairStrandedCashConfirmations() {
  const stranded = await Booking.find({
    status: 'pending_admin_review',
    paymentMethod: 'cash',
    customerConfirmedAt: { $exists: true },
    'customerFeedback.action': { $ne: 'reported_issue' },
    $or: [
      { enhancedReviewReason: { $exists: false } },
      { enhancedReviewReason: null },
    ],
  });

  let repaired = 0;
  for (const booking of stranded) {
    const result = await autoFeeDebt.createIfClean(booking._id);
    if (result.booking?.status === 'completed') repaired++;
  }
  return repaired;
}

function confirmationDeadline(booking, totalMs) {
  if (booking.customerConfirmAutoAt) return new Date(booking.customerConfirmAutoAt);
  if (booking.completionOutcome?.submittedAt) {
    return new Date(new Date(booking.completionOutcome.submittedAt).getTime() + totalMs);
  }
  return null;
}

function list(value) {
  return Array.isArray(value) ? value : [];
}

module.exports = { runOnce, confirmationDeadline, repairStrandedCashConfirmations };
