require('express-async-errors');

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const os = require('os');
const { StatusCodes } = require('http-status-codes');

// ── Route modules ─────────────────────────────────────────────────────────────
const authRoutes      = require('./modules/auth/auth.routes');
const userRoutes      = require('./modules/users/user.routes');
const serviceRoutes   = require('./modules/services/service.routes');
const bookingRoutes   = require('./modules/bookings/booking.routes');
const reviewRoutes    = require('./modules/reviews/review.routes');
const aiRoutes        = require('./modules/ai/ai.routes');
const messageRoutes   = require('./modules/messages/message.routes');
const paymentRoutes   = require('./modules/payments/payment.routes');
const adminRoutes     = require('./modules/admin/audit.routes');
const uploadRoutes    = require('./modules/uploads/upload.routes');
const notifyRoutes         = require('./modules/notifications/notify.routes');
const notificationsRoutes  = require('./modules/notifications/notifications.routes');
const savedCardRoutes      = require('./modules/savedCards/savedCard.routes');
const platformRoutes  = require('./modules/platform/platform.routes');
const locationsRoutes = require('./modules/platform/locations.routes');
const favoritesRoutes = require('./modules/favorites/favorite.routes');
const supportIssueRoutes = require('./modules/support/support-issue.routes');

const { notFound, errorHandler } = require('./middleware/error.middleware');

const app = express();
const uploadRoot = process.env.SERVIO_UPLOAD_DIR
  ? path.resolve(process.env.SERVIO_UPLOAD_DIR)
  : path.join(os.tmpdir(), 'servio-uploads');

app.use(helmet());

const allowedOrigins = (process.env.CLIENT_URL || '*')
  .split(',')
  .map((origin) => origin.trim());

if (process.env.NODE_ENV === 'production' && allowedOrigins.includes('*')) {
  throw new Error('CLIENT_URL must be explicitly set in production - wildcard origin is not allowed with credentials.');
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

if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use('/uploads', (req, res, next) => {
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  next();
}, express.static(uploadRoot), (req, res) => {
  res.status(StatusCodes.NOT_FOUND).send('Upload not found');
});

app.get(['/health', '/api/v1/health'], (req, res) => {
  res.status(StatusCodes.OK).json({
    success: true,
    message: 'SERVIO API is running',
    environment: process.env.NODE_ENV,
    timestamp: new Date().toISOString(),
  });
});

const API_PREFIX = '/api/v1';

app.use(`${API_PREFIX}/auth`, authRoutes);
app.use(`${API_PREFIX}/users`, userRoutes);
app.use(`${API_PREFIX}/services`, serviceRoutes);
app.use(`${API_PREFIX}/bookings`, bookingRoutes);
app.use(`${API_PREFIX}/reviews`, reviewRoutes);
app.use(`${API_PREFIX}/ai`, aiRoutes);
app.use(`${API_PREFIX}/messages`, messageRoutes);
app.use(`${API_PREFIX}/payments`, paymentRoutes);
app.use(`${API_PREFIX}/admin`,       adminRoutes);
app.use(`${API_PREFIX}/uploads`,     uploadRoutes);
app.use(`${API_PREFIX}/notify`,         notifyRoutes);
app.use(`${API_PREFIX}/notifications`,  notificationsRoutes);
app.use(`${API_PREFIX}/saved-cards`, savedCardRoutes);
app.use(`${API_PREFIX}/platform-settings`, platformRoutes);
app.use(`${API_PREFIX}/locations`, locationsRoutes);
app.use(`${API_PREFIX}/favorites`, favoritesRoutes);
app.use(`${API_PREFIX}/support`, supportIssueRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
