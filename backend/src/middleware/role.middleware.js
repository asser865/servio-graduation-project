// ─── Purpose ──────────────────────────────────────────────────────────────────
// authorize() is a middleware factory — it takes a list of allowed roles and
// returns a middleware that checks req.user.role (set by protect()) against
// that list. Separating authentication (protect) from authorisation (authorize)
// keeps each concern focused and composable.
// ─────────────────────────────────────────────────────────────────────────────

const { StatusCodes } = require('http-status-codes');
const ApiError        = require('../utils/ApiError');

/**
 * authorize(...roles) — role-based access control middleware.
 *
 * Usage:  router.delete('/resource', protect, authorize('admin'), controller)
 *
 * @param {...string} roles - Roles that are allowed to access the route
 */
const authorize = (...roles) => {
  return (req, res, next) => {
    // protect() must run first to populate req.user
    if (!req.user) {
      throw new ApiError(StatusCodes.UNAUTHORIZED, 'Not authenticated.');
    }

    if (!roles.includes(req.user.role)) {
      throw new ApiError(
        StatusCodes.FORBIDDEN,
        `Role '${req.user.role}' is not authorised to access this resource.`
      );
    }

    next();
  };
};

module.exports = { authorize };
