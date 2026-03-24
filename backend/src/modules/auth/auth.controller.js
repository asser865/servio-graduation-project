// ─── Purpose ──────────────────────────────────────────────────────────────────
// Thin controller — delegates all business logic to auth.service.js and is
// only responsible for translating service responses into HTTP responses.
// express-async-errors catches any thrown ApiErrors so no try/catch needed.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const authService    = require('./auth.service');
const ApiResponse    = require('../../utils/ApiResponse');

// ── REGISTER METHOD ──────────────────────────────────────────────────────────
// WHAT: Creates a new user account (User or Worker).
// HOW:  Expects { name, email, password, role } in body. Returns User + JWT.
const register = async (req, res) => {
  const { user, token } = await authService.registerUser(req.body);

  return ApiResponse.success(res, StatusCodes.CREATED, 'Account created successfully.', {
    token,
    user,
  });
};

// ── LOGIN METHOD ─────────────────────────────────────────────────────────────
// WHAT: Authenticates a user and starts their session.
// HOW:  Expects { email, password }. Returns User + JWT if credentials match.
const login = async (req, res) => {
  const { user, token } = await authService.loginUser(req.body);

  return ApiResponse.success(res, StatusCodes.OK, 'Login successful.', {
    token,
    user,
  });
};

module.exports = { register, login };
