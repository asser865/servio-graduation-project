// ─── Purpose ──────────────────────────────────────────────────────────────────
// validate() converts express-validator results into a consistent ApiError(400).
// Using a dedicated middleware keeps controllers clean — they can assume the
// request body is already valid when they execute.
// ─────────────────────────────────────────────────────────────────────────────

const { validationResult } = require('express-validator');
const { StatusCodes }       = require('http-status-codes');
const ApiError              = require('../utils/ApiError');

/**
 * validate(validations) — runs an array of express-validator checks,
 * then collects any errors and throws ApiError(400) with a structured errors
 * array if validation fails.
 *
 * Usage:
 *   router.post('/register',
 *     validate([body('email').isEmail(), body('password').isLength({ min: 8 })]),
 *     authController.register
 *   );
 *
 * @param {Array} validations - Array of express-validator chain objects
 */
const validate = (validations) => {
  return async (req, res, next) => {
    // Run all validators in parallel for performance
    await Promise.all(validations.map((v) => v.run(req)));

    const result = validationResult(req);

    if (!result.isEmpty()) {
      // Map errors to { field, message } objects for the client
      const errors = result.array().map((err) => ({
        field:   err.path || err.param,
        message: err.msg,
      }));

      throw new ApiError(
        StatusCodes.UNPROCESSABLE_ENTITY,
        'Validation failed. Please check the provided data.',
        errors
      );
    }

    next();
  };
};

module.exports = { validate };
