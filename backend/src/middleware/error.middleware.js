// ─── Purpose ──────────────────────────────────────────────────────────────────
// Global error middleware.  All errors thrown anywhere in the application —
// whether from route handlers, services, or mongoose operations — funnel here.
// We normalise known error shapes into ApiError instances before responding, so
// the client always receives the consistent { success, message, errors } shape.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const ApiError        = require('../utils/ApiError');
const ApiResponse     = require('../utils/ApiResponse');

// ── notFound ─────────────────────────────────────────────────────────────────
// Catches every request that did not match a registered route and converts it
// into a structured 404 error that flows through errorHandler below.
const notFound = (req, res, next) => {
  next(new ApiError(StatusCodes.NOT_FOUND, `Route ${req.originalUrl} not found`));
};

// ── errorHandler ─────────────────────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  let error = err;

  // ── Mongoose CastError (invalid ObjectId) ─────────────────────────────────
  // Happens when ":id" in the URL is not a valid MongoDB ObjectId.
  // Convert it to a 400 with a user-friendly message.
  if (err.name === 'CastError') {
    error = new ApiError(
      StatusCodes.BAD_REQUEST,
      `Invalid ${err.path}: ${err.value}`
    );
  }

  // ── Mongoose Duplicate Key (code 11000) ───────────────────────────────────
  // Fired when inserting a document that violates a unique index (e.g. email).
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue)[0];
    error = new ApiError(
      StatusCodes.CONFLICT,
      `${field} already exists. Please use a different value.`
    );
  }

  // ── Mongoose Validation Error ─────────────────────────────────────────────
  // Occurs when Mongoose schema validation fails (e.g. required field missing).
  if (err.name === 'ValidationError') {
    const messages = Object.values(err.errors).map((e) => e.message);
    error = new ApiError(StatusCodes.BAD_REQUEST, messages.join(', '));
  }

  // ── JWT Errors ────────────────────────────────────────────────────────────
  // JsonWebTokenError = token is malformed or the secret is wrong.
  if (err.name === 'JsonWebTokenError') {
    error = new ApiError(StatusCodes.UNAUTHORIZED, 'Invalid token. Please log in again.');
  }

  // TokenExpiredError = the token's exp timestamp has passed.
  if (err.name === 'TokenExpiredError') {
    error = new ApiError(StatusCodes.UNAUTHORIZED, 'Token expired. Please log in again.');
  }

  // ── Ensure we always have an ApiError-shaped object ──────────────────────
  if (!(error instanceof ApiError)) {
    error = new ApiError(
      error.statusCode || StatusCodes.INTERNAL_SERVER_ERROR,
      error.message    || 'Internal server error',
      error.errors     || [],
      false            // non-operational = programmer error
    );
  }

  // ── Hide stack traces in production ──────────────────────────────────────
  if (process.env.NODE_ENV === 'development') {
    console.error('❌ ERROR:', err);
  }

  return ApiResponse.error(
    res,
    error.statusCode,
    error.message,
    error.errors
  );
};

module.exports = { notFound, errorHandler };
