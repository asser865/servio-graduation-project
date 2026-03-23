// ─── Purpose ──────────────────────────────────────────────────────────────────
// auth.service.js contains only business logic — no Express objects (req/res).
// This makes the logic unit-testable in isolation and keeps controllers thin.
// ─────────────────────────────────────────────────────────────────────────────

const jwt            = require('jsonwebtoken');
const { StatusCodes } = require('http-status-codes');
const User           = require('../users/user.model');
const ApiError       = require('../../utils/ApiError');

// ── generateToken ─────────────────────────────────────────────────────────────
// Signs a JWT containing only { id, role } — minimal payload to keep tokens
// compact. The secret and expiry are driven by environment variables so they
// can be rotated without code changes.
const generateToken = (userId, role) => {
  return jwt.sign(
    { id: userId, role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

// ── registerUser ─────────────────────────────────────────────────────────────
const registerUser = async (data) => {
  const { name, email, password, phone, role } = data;

  // Prevent duplicate accounts — give a clear message instead of letting
  // Mongoose throw a generic duplicate key error.
  const existingUser = await User.findOne({ email });
  if (existingUser) {
    throw new ApiError(StatusCodes.CONFLICT, 'An account with this email already exists.');
  }

  // Password hashing is handled by the pre-save hook in user.model.js
  const user = await User.create({ name, email, password, phone, role: role || 'user' });

  const token = generateToken(user._id, user.role);

  return { user, token };
};

// ── loginUser ─────────────────────────────────────────────────────────────────
const loginUser = async ({ email, password }) => {
  // Explicitly select password because the schema marks it select: false.
  // We ONLY bring it into memory here, for comparison — never expose it.
  const user = await User.findOne({ email }).select('+password');

  if (!user) {
    // Use the same error for "user not found" and "wrong password" to prevent
    // user enumeration attacks (attacker cannot tell which is wrong).
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Invalid email or password.');
  }

  if (!user.isActive) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Your account has been deactivated. Please contact support.');
  }

  const isMatch = await user.comparePassword(password);
  if (!isMatch) {
    throw new ApiError(StatusCodes.UNAUTHORIZED, 'Invalid email or password.');
  }

  const token = generateToken(user._id, user.role);

  return { user, token };
};

module.exports = { registerUser, loginUser, generateToken };
