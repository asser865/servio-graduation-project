const { StatusCodes } = require('http-status-codes');
const ApiError = require('../utils/ApiError');

function hasPermission(user, required) {
  if (!user) return false;
  if (user.role === 'superadmin') return true;
  if (user.role !== 'admin') return false;
  const perms = Array.isArray(user.adminPermissions) ? user.adminPermissions : [];
  if (perms.length === 0) return true;
  return perms.includes(required);
}

function permission(required) {
  return (req, _res, next) => {
    if (!req.user) return next(new ApiError(StatusCodes.UNAUTHORIZED, 'Not authenticated.'));
    if (!hasPermission(req.user, required)) {
      return next(new ApiError(StatusCodes.FORBIDDEN, `Missing permission: ${required}`));
    }
    next();
  };
}

module.exports = { permission, hasPermission };
