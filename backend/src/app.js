require('express-async-errors');

const fs = require('fs');
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const { StatusCodes } = require('http-status-codes');
const { resolveUploadRoot } = require('./config/uploadPath');

// ── Route modules ─────────────────────────────────────────────────────────────
const authRoutes      = require('./modules/auth/auth.routes');
const userRoutes      = require('./modules/users/user.routes');
const serviceRoutes   = require('./modules/services/service.routes');
const bookingRoutes   = require('./modules/bookings/booking.routes');
const reviewRoutes    = require('./modules/reviews/review.routes');
const aiRoutes        = require('./modules/ai/ai.routes');
const aiMobileRoutes  = require('./modules/ai/ai.mobile.routes');
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
const supportIssueRoutes      = require('./modules/support/support-issue.routes');
const problemReportRoutes     = require('./modules/support/problem-report.routes');
const contactMessageRoutes    = require('./modules/support/contact-message.routes');
const financeBulkActionRoutes = require('./modules/finance/bulk-action.routes');

const { notFound, errorHandler } = require('./middleware/error.middleware');

const app = express();
const uploadRoot = resolveUploadRoot();

app.use(helmet());

const productionOrigins = [
  'https://servio-frontend.vercel.app',
  'https://servio-frontend-staging.vercel.app',
];

const allowedOrigins = [
  ...(process.env.CLIENT_URL || '*').split(',').map((origin) => origin.trim()),
  ...productionOrigins,
];

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

// Ensure upload folders exist on disk
if (!fs.existsSync(path.join(uploadRoot, 'avatar'))) {
  fs.mkdirSync(path.join(uploadRoot, 'avatar'), { recursive: true });
}

// Fallback dynamic middleware for missing user avatar files to prevent 404 image load exceptions
app.get('/uploads/avatar/:filename', (req, res, next) => {
  const filePath = path.join(uploadRoot, 'avatar', req.params.filename);
  if (!fs.existsSync(filePath)) {
    // Redirects to a beautiful themed initial placeholder matching Servio neutralWarm (#e3d5ca) and accent (#9a8c73) branding colors
    return res.redirect('https://ui-avatars.com/api/?name=S&background=e3d5ca&color=9a8c73');
  }
  next();
});

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
app.use(`${API_PREFIX}/mobile/ai`, aiMobileRoutes);
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
app.use(`${API_PREFIX}/reports`, problemReportRoutes);
app.use(`${API_PREFIX}/contact`, contactMessageRoutes);
app.use(`${API_PREFIX}/finance`, financeBulkActionRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
