// ─── Purpose ──────────────────────────────────────────────────────────────────
// Establishes the Mongoose connection once at startup. Using a dedicated file
// keeps database logic out of server.js and makes it easy to swap DB providers.
// ─────────────────────────────────────────────────────────────────────────────

const mongoose = require('mongoose');
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

/**
 * connectDB — connects to MongoDB using the URI from environment variables.
 * - Exits the process on failure so the server never starts in a broken state.
 * - Logs the host on success for quick confirmation in logs.
 */
const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI);

    console.log(`✅ MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌ MongoDB connection error: ${error.message}`);
    // Exit with failure code — do not let the app run without a database
    process.exit(1);
  }
};

module.exports = connectDB;
