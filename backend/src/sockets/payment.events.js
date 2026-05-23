const { get } = require('./index');

function emitPaymentReleased({ payment, booking }) {
  try {
    const io = get();
    io.to(`user:${booking.user}`).emit('payment:released', { bookingId: booking._id, amount: payment.amount });
    io.to(`user:${booking.worker}`).emit('payment:released', { bookingId: booking._id, amount: payment.amount });
    io.to('admins').emit('payment:released', { bookingId: booking._id, paymentId: payment._id, amount: payment.amount });
  } catch (err) { /* no socket in test */ }
}

function emitPaymentPendingReview({ booking }) {
  try {
    const io = get();
    io.to(`user:${booking.worker}`).emit('payment:pending_review', { bookingId: booking._id });
    io.to('admins').emit('payment:pending_review', { bookingId: booking._id });
  } catch (err) {}
}

function emitDisputeOpened({ dispute, booking }) {
  try {
    const io = get();
    io.to(`user:${booking.worker}`).emit('dispute:opened', { bookingId: booking._id, disputeId: dispute._id });
    io.to('admins').emit('dispute:opened', { bookingId: booking._id, disputeId: dispute._id });
  } catch (err) {}
}

module.exports = { emitPaymentReleased, emitPaymentPendingReview, emitDisputeOpened };
