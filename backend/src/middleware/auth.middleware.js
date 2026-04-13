// ─── Purpose ──────────────────────────────────────────────────────────────────
// protect() extracts and verifies the JWT from the Authorization header.
// Attaching the decoded payload to req.user allows downstream middleware
// (authorize, controllers) to know who is making the request without
// hitting the database on every call — the token itself carries id + role.
// ─────────────────────────────────────────────────────────────────────────────

const jwt            = require('jsonwebtoken');
const { StatusCodes } = require('http-status-codes');
const ApiError        = require('../utils/ApiError');

/**
 * protect — verifies the Bearer token from the Authorization header.
 * Attaches { id, role } to req.user on success.
 * Throws ApiError(401) if token is missing, malformed, or expired
 * (JWT errors are caught by error.middleware.js and converted automatically).
 */
const protect = (req, res, next) => {
  const authHeader = req.headers.authorization;

  // Token must be in format: "Bearer <token>"
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new ApiError(
      StatusCodes.UNAUTHORIZED,
      'Access denied. No token provided.'
    );
  }

  const token = authHeader.split(' ')[1];

  // jwt.verify throws JsonWebTokenError / TokenExpiredError on failure;
  // error.middleware.js converts those into clean 401 ApiErrors.
  const decoded = jwt.verify(token, process.env.JWT_SECRET);

  // Attach decoded payload { id, role } so controllers can use req.user
  req.user = decoded;
  next();
};

module.exports = { protect };
