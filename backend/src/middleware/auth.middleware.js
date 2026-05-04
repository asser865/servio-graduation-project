// ─── Purpose ──────────────────────────────────────────────────────────────────
// protect() extracts and verifies the JWT from the Authorization header.
// Attaching the decoded payload to req.user allows downstream middleware
// (authorize, controllers) to know who is making the request without
// hitting the database on every call — the token itself carries id + role.
// ─────────────────────────────────────────────────────────────────────────────

const jwt            = require('jsonwebtoken');
const { StatusCodes } = require('http-status-codes');
const ApiError        = require('../utils/ApiError');

const protect = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Access denied. No token provided.');
  }

  const token = authHeader.split(' ')[1];
  const decoded = jwt.verify(token, process.env.JWT_SECRET);

  const User = require('../modules/users/user.model');
  const user = await User.findById(decoded.id);
  if (!user) throw new ApiError(StatusCodes.UNAUTHORIZED, 'User no longer exists.');
  if (!user.isActive) throw new ApiError(StatusCodes.FORBIDDEN, 'Account has been deactivated.');
  if ((decoded.authVersion ?? 0) !== (user.authVersion ?? 0)) {
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Session expired. Please log in again.');
  }

  req.user = { id: user._id, role: user.role, email: user.email };
  next();
};

module.exports = { protect };
