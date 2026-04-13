// ─── Purpose ──────────────────────────────────────────────────────────────────
// ApiError — a custom Error subclass that carries an HTTP status code and an
// optional array of field-level validation errors. Marking errors as
// isOperational = true lets the global error handler distinguish "expected"
// errors (bad input, not found, unauthorized) from true bugs.
// ─────────────────────────────────────────────────────────────────────────────

class ApiError extends Error {
  /**
   * @param {number}   statusCode   - HTTP status code (e.g. 400, 401, 404)
   * @param {string}   message      - Human-readable error message
   * @param {Array}    errors       - Optional array of field-level errors
   *                                  (from express-validator results)
   * @param {boolean}  isOperational - false = programmer error → log & crash
   */
  constructor(statusCode, message, errors = [], isOperational = true) {
    super(message);

    this.name       = 'ApiError';
    this.statusCode = statusCode;
    this.errors     = errors;
    this.isOperational = isOperational;

    // Preserve the original stack trace for debugging
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = ApiError;
