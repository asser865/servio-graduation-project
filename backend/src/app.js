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
const path       = require('path');
const os         = require('os');
const { StatusCodes } = require('http-status-codes');

// ── Route modules ─────────────────────────────────────────────────────────────
const authRoutes     = require('./modules/auth/auth.routes');
const userRoutes     = require('./modules/users/user.routes');
const serviceRoutes  = require('./modules/services/service.routes');
const bookingRoutes  = require('./modules/bookings/booking.routes');
const reviewRoutes   = require('./modules/reviews/review.routes');
const aiRoutes       = require('./modules/ai/ai.routes');
const messageRoutes  = require('./modules/messages/message.routes');
const paymentRoutes  = require('./modules/payments/payment.routes');
const adminRoutes    = require('./modules/admin/audit.routes');
const uploadRoutes   = require('./modules/uploads/upload.routes');
const notifyRoutes   = require('./modules/notifications/notify.routes');

// ── Global error middleware ───────────────────────────────────────────────────
const { notFound, errorHandler } = require('./middleware/error.middleware');

const app = express();
const uploadRoot = process.env.SERVIO_UPLOAD_DIR
  ? path.resolve(process.env.SERVIO_UPLOAD_DIR)
  : path.join(os.tmpdir(), 'servio-uploads');

// ── Security headers ─────────────────────────────────────────────────────────
// helmet sets ~15 HTTP response headers that protect against common web
// vulnerabilities (clickjacking, XSS, MIME sniffing, etc.)
app.use(helmet());

// ── CORS ──────────────────────────────────────────────────────────────────────
// Allow the React web client and Flutter app to call this API.
// In production, restrict origin to the actual deployed client URL.
const allowedOrigins = (process.env.CLIENT_URL || '*')
  .split(',')
  .map(o => o.trim());

if (process.env.NODE_ENV === 'production' && allowedOrigins.includes('*')) {
  throw new Error('CLIENT_URL must be explicitly set in production — wildcard origin is not allowed with credentials.');
}

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`CORS: origin ${origin} not allowed`));
      }
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  })
);

// ── Request logging ───────────────────────────────────────────────────────────
// 'dev' format prints coloured one-liners: "GET /api/v1/auth/login 200 14ms"
// Skip in test environments so test output stays clean.
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// ── Payment routes (BEFORE express.json) ─────────────────────────────────────
// ⚠️  CRITICAL ORDER: The payment router MUST be registered here, BEFORE the
// global express.json() middleware below.
//
// Reason: The Stripe webhook route (/payments/webhook) uses express.raw() to
// receive the request body as a raw Buffer. If express.json() middleware runs
// first on that route, the Buffer is parsed into a JS object. This invalidates
// the Stripe cryptographic signature, and ALL webhook events get rejected.
//
// The payment router applies express.raw() ONLY to the /webhook sub-route,
// so all other payment routes still receive parsed JSON bodies normally.
app.use(`/api/v1/payments`, paymentRoutes);

// ── Body parsing ──────────────────────────────────────────────────────────────
// Parse incoming JSON request bodies. Verification uploads are currently sent as
// small metadata payloads only. Actual files go through the upload route below.
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Public file access for uploaded technician documents.
// New uploads live outside the repo by default so dev file-watchers do not
// reload the frontend while signup is still waiting for /auth/register.
// Cross-Origin-Resource-Policy must be cross-origin so that the frontend
// (served from a different port by the dev live-server) can load these images.
app.use('/uploads', (req, res, next) => {
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  next();
}, express.static(uploadRoot));

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
app.use(`${API_PREFIX}/messages`, messageRoutes);
app.use(`${API_PREFIX}/admin`,    adminRoutes);
app.use(`${API_PREFIX}/uploads`,  uploadRoutes);
app.use(`${API_PREFIX}/notify`,   notifyRoutes);
// Note: payment routes are already mounted above express.json() for webhook support

// ── 404 + error handlers ──────────────────────────────────────────────────────
// These MUST be last — any unmatched route hits notFound first, then the thrown
// ApiError propagates to errorHandler.
app.use(notFound);
app.use(errorHandler);

module.exports = app;
