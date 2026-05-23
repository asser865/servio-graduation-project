const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');

let io = null;

function init(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: (process.env.CLIENT_URL || '*').split(','), credentials: true },
  });

  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token
        || socket.handshake.headers?.authorization?.replace('Bearer ', '');
      if (!token) return next(new Error('missing token'));
      const payload = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = payload.id;
      socket.role = payload.role;
      next();
    } catch (err) {
      next(new Error('auth failed'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.userId}`);
    if (socket.role === 'admin') socket.join('admins');
  });

  return io;
}

function get() {
  if (!io) throw new Error('socket.io not initialized');
  return io;
}

module.exports = { init, get };
