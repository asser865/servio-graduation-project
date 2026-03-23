// ─── Purpose ──────────────────────────────────────────────────────────────────
// ApiResponse — a static helper that enforces a consistent JSON envelope across
// ALL endpoints. Clients can always rely on { success, message, data/errors }
// regardless of which route they hit. This avoids ad-hoc res.json() shapes.
// ─────────────────────────────────────────────────────────────────────────────

class ApiResponse {
  /**
   * Send a successful JSON response.
   *
   * @param {object} res        - Express response object
   * @param {number} statusCode - HTTP 2xx code
   * @param {string} message    - Descriptive success message
   * @param {*}      data       - Payload (object, array, or null)
   */
  static success(res, statusCode, message, data = null) {
    return res.status(statusCode).json({
      success: true,
      message,
      data,
    });
  }

  /**
   * Send an error JSON response.
   * Prefer throwing ApiError and letting the global handler call this;
   * use directly only when you need fine-grained control.
   *
   * @param {object} res        - Express response object
   * @param {number} statusCode - HTTP 4xx / 5xx code
   * @param {string} message    - Descriptive error message
   * @param {Array}  errors     - Optional field-level error details
   */
  static error(res, statusCode, message, errors = []) {
    return res.status(statusCode).json({
      success: false,
      message,
      errors,
    });
  }
}

module.exports = ApiResponse;
