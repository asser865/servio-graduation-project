// ─── Purpose ──────────────────────────────────────────────────────────────────
// Thin controller — delegates all business logic to auth.service.js and is
// only responsible for translating service responses into HTTP responses.
// express-async-errors catches any thrown ApiErrors so no try/catch needed.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const authService    = require('./auth.service');
const ApiResponse    = require('../../utils/ApiResponse');

// ── register ──────────────────────────────────────────────────────────────────
const register = async (req, res) => {
  const { user, token } = await authService.registerUser(req.body);

  return ApiResponse.success(res, StatusCodes.CREATED, 'Account created successfully.', {
    token,
    user,
  });
};

// ── login ─────────────────────────────────────────────────────────────────────
const login = async (req, res) => {
  const { user, token } = await authService.loginUser(req.body);

  return ApiResponse.success(res, StatusCodes.OK, 'Login successful.', {
    token,
    user,
  });
};

module.exports = { register, login };
