const { get } = require('./index');

function safe(fn) {
  try { fn(); } catch (_) { /* sockets not initialized in tests */ }
}

function emitSettlementSubmitted({ settlement }) {
  safe(() => get().to('admins').emit('settlement:submitted', { settlementId: settlement._id, workerId: settlement.worker }));
}

function emitSettlementVerified({ settlement }) {
  safe(() => {
    const io = get();
    io.to(`user:${settlement.worker}`).emit('settlement:verified', { settlementId: settlement._id });
    io.to('admins').emit('settlement:verified', { settlementId: settlement._id });
  });
}

function emitSettlementRejected({ settlement }) {
  safe(() => get().to(`user:${settlement.worker}`).emit('settlement:rejected', { settlementId: settlement._id, reason: settlement.rejectionReason }));
}

function emitPayoutRequested({ payout }) {
  safe(() => get().to('admins').emit('payout:requested', { payoutId: payout._id, amount: payout.amount }));
}

function emitPayoutDecided({ payout }) {
  safe(() => get().to(`user:${payout.worker}`).emit(`payout:${payout.status}`, { payoutId: payout._id, amount: payout.amount }));
}

function emitDebtBlocked({ workerId, totalOutstanding }) {
  safe(() => get().to(`user:${workerId}`).emit('debt:blocked', { totalOutstanding }));
}

module.exports = {
  emitSettlementSubmitted,
  emitSettlementVerified,
  emitSettlementRejected,
  emitPayoutRequested,
  emitPayoutDecided,
  emitDebtBlocked,
};
