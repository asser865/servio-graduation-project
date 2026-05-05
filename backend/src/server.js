// ─── Purpose ──────────────────────────────────────────────────────────────────
// server.js is the entry point. It loads environment variables FIRST (before
// any other require so process.env is populated for all modules), connects to
// the database, then starts the HTTP server. It also handles graceful shutdown
// so in-flight requests complete before the process exits.
// ─────────────────────────────────────────────────────────────────────────────

// Load .env before anything else touches process.env
require('dotenv').config();

// Fix Node.js DNS bug with IPv6 local routers (querySrv ECONNREFUSED)
require('dns').setServers(['8.8.8.8', '8.8.4.4']);

const connectDB = require('./config/db');
const app       = require('./app');

const PORT = process.env.PORT || 5000;

// ── Bootstrap ─────────────────────────────────────────────────────────────────
const startServer = async () => {
  // Connect to MongoDB before accepting any requests.
  // connectDB() calls process.exit(1) on failure so we never reach app.listen
  // with a broken database connection.
  await connectDB();

  const server = app.listen(PORT, () => {
    console.log(
      `🚀 SERVIO API running in ${process.env.NODE_ENV} mode on port ${PORT}`
    );
  });

  // ── Graceful shutdown ─────────────────────────────────────────────────────
  // SIGTERM is sent by process managers (Docker, PM2, Kubernetes) when they
  // want to stop the service. We stop accepting new connections and let
  // existing requests finish (within a timeout) before exiting.
  const gracefulShutdown = (signal) => {
    console.log(`\n🛑 ${signal} received — shutting down gracefully…`);
    server.close(() => {
      console.log('✅ HTTP server closed. Goodbye.');
      process.exit(0);
    });

    // Force exit after 10 seconds if requests are still hanging
    setTimeout(() => {
      console.error('⚠️  Forced shutdown after timeout');
      process.exit(1);
    }, 10_000);
  };

  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT',  () => gracefulShutdown('SIGINT'));

  // ── Unhandled promise rejections ─────────────────────────────────────────
  // Catch any forgotten await calls or un-caught promise chains.
  process.on('unhandledRejection', (reason) => {
    console.error('💥 Unhandled Rejection:', reason);
    server.close(() => process.exit(1));
  });
};

startServer();
