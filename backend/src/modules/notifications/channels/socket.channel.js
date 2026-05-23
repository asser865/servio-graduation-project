let socketsModule;
try { socketsModule = require('../../../sockets'); } catch (_) { socketsModule = null; }

async function send({ event, userId, payload }) {
  if (!socketsModule || typeof socketsModule.getIO !== 'function') return null;
  try {
    const io = socketsModule.getIO();
    if (!io) return null;
    io.to(`user:${String(userId)}`).emit(event, payload);
  } catch (_) {
    return null;
  }
}

module.exports = { send };
