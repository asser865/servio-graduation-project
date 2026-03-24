// ─── Purpose ──────────────────────────────────────────────────────────────────
// app.js is the Express application factory — it wires up all middleware and
// routes but does NOT start listening. This separation lets tests import the app
// without binding to a port, and lets server.js handle the listen/shutdown cycle.
// ─────────────────────────────────────────────────────────────────────────────

// Make every async route handler automatically pass errors to next()
// IMPORTANT: must be required before express and route files
require('express-async-errors');

const express    = require('express');
const helmet     = require('helmet');
const cors       = require('cors');
const morgan     = require('morgan');
const { StatusCodes } = require('http-status-codes');

// ── Route modules ─────────────────────────────────────────────────────────────
const authRoutes     = require('./modules/auth/auth.routes');
const userRoutes     = require('./modules/users/user.routes');
const serviceRoutes  = require('./modules/services/service.routes');
const bookingRoutes  = require('./modules/bookings/booking.routes');
const reviewRoutes   = require('./modules/reviews/review.routes');
const aiRoutes       = require('./modules/ai/ai.routes');

// ── Global error middleware ───────────────────────────────────────────────────
const { notFound, errorHandler } = require('./middleware/error.middleware');

const app = express();

// ── Security headers ─────────────────────────────────────────────────────────
// helmet sets ~15 HTTP response headers that protect against common web
// vulnerabilities (clickjacking, XSS, MIME sniffing, etc.)
app.use(helmet());

// ── CORS ──────────────────────────────────────────────────────────────────────
// Allow the React web client and Flutter app to call this API.
// In production, restrict origin to the actual deployed client URL.
app.use(
  cors({
    origin: process.env.CLIENT_URL || '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

// ── Request logging ───────────────────────────────────────────────────────────
// 'dev' format prints coloured one-liners: "GET /api/v1/auth/login 200 14ms"
// Skip in test environments so test output stays clean.
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// ── Body parsing ──────────────────────────────────────────────────────────────
// Parse incoming JSON request bodies (max 10 MB to prevent payload attacks).
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Health check ──────────────────────────────────────────────────────────────
// Simple endpoint for load balancers / uptime monitors to verify the service
// is running without touching the database.
app.get(['/health', '/api/v1/health'], (req, res) => {
  res.status(StatusCodes.OK).json({
    success: true,
    message: 'SERVIO API is running',
    environment: process.env.NODE_ENV,
    timestamp: new Date().toISOString(),
  });
});

// ── API routes ────────────────────────────────────────────────────────────────
// All routes are versioned under /api/v1 so future breaking changes can be
// introduced as /api/v2 without breaking existing clients.
const API_PREFIX = '/api/v1';

app.use(`${API_PREFIX}/auth`,     authRoutes);
app.use(`${API_PREFIX}/users`,    userRoutes);
app.use(`${API_PREFIX}/services`, serviceRoutes);
app.use(`${API_PREFIX}/bookings`, bookingRoutes);
app.use(`${API_PREFIX}/reviews`,  reviewRoutes);
app.use(`${API_PREFIX}/ai`,       aiRoutes);

// ── 404 + error handlers ──────────────────────────────────────────────────────
// These MUST be last — any unmatched route hits notFound first, then the thrown
// ApiError propagates to errorHandler.
app.use(notFound);
app.use(errorHandler);

module.exports = app;
