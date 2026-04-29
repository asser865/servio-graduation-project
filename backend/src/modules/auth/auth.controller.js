// ─── Purpose ──────────────────────────────────────────────────────────────────
// Thin controller — delegates all business logic to auth.service.js and is
// only responsible for translating service responses into HTTP responses.
// express-async-errors catches any thrown ApiErrors so no try/catch needed.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const authService    = require('./auth.service');
const ApiResponse    = require('../../utils/ApiResponse');
const { logEvent }   = require('../admin/audit.service');

// ── REGISTER METHOD ──────────────────────────────────────────────────────────
const register = async (req, res) => {
  const { user, token } = await authService.registerUser(req.body);

  logEvent({ req, type: 'auth', action: `New ${user.role} registered: ${user.email}`, target: user.email });

  return ApiResponse.success(res, StatusCodes.CREATED, 'Account created successfully.', {
    token,
    user,
  });
};

// ── LOGIN METHOD ─────────────────────────────────────────────────────────────
const login = async (req, res) => {
  let user, token;
  try {
    ({ user, token } = await authService.loginUser(req.body));
  } catch (err) {
    logEvent({ req, type: 'auth', action: `Failed login attempt`, target: req.body.email || '', status: 'fail', actorEmail: req.body.email });
    throw err;
  }

  logEvent({ req, type: 'auth', action: `User logged in`, target: user.email, actorEmail: user.email });

  return ApiResponse.success(res, StatusCodes.OK, 'Login successful.', {
    token,
    user,
  });
};

// ── FORGOT PASSWORD ──────────────────────────────────────────────────────────
const forgotPassword = async (req, res) => {
  const clientUrl = req.headers.origin || req.headers.referer?.replace(/\/html\/.*$/, '');
  const result = await authService.forgotPassword({ email: req.body.email, clientUrl });

  logEvent({ req, type: 'auth', action: `Forgot-password request`, target: req.body.email || '' });

  return ApiResponse.success(res, StatusCodes.OK, result.message, {
    ...(result.devResetUrl && { devResetUrl: result.devResetUrl }),
  });
};

// ── RESET PASSWORD ───────────────────────────────────────────────────────────
const resetPassword = async (req, res) => {
  const { user, token } = await authService.resetPassword({
    token:    req.params.token,
    password: req.body.password,
  });

  logEvent({ req, type: 'auth', action: `Password reset successful`, target: user.email, actorEmail: user.email });

  return ApiResponse.success(res, StatusCodes.OK, 'Password updated successfully. You are now logged in.', {
    token,
    user,
  });
};

module.exports = { register, login, forgotPassword, resetPassword };
