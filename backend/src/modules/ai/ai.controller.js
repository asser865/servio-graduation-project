// ─── Purpose ──────────────────────────────────────────────────────────────────
// AI controller acts as a gateway — it forwards requests to the Python AI
// microservice and returns its response. Isolating AI calls here means the
// AI_SERVICE_URL and retry/timeout logic is centralised, not scattered across
// multiple controllers.
// ─────────────────────────────────────────────────────────────────────────────

const axios           = require('axios');
const { StatusCodes } = require('http-status-codes');
const ApiError        = require('../../utils/ApiError');
const ApiResponse     = require('../../utils/ApiResponse');

// ── GET AI RECOMMENDATION (Authenticated) ────────────────────────────────────
// WHAT: Forwards a service request description to the Python AI microservice.
// HOW:  Expects { description, location, budget }.
const getServiceRecommendation = async (req, res) => {
  const { description, location, budget } = req.body;

  if (!description) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Description is required for a recommendation.');
  }

  try {
    // Forward the request to the Python AI microservice.
    // Timeout of 15s prevents this request from hanging indefinitely.
    const aiResponse = await axios.post(
      `${process.env.AI_SERVICE_URL}/recommend`,
      { description, location, budget },
      { timeout: 15_000 }
    );

    return ApiResponse.success(
      res,
      StatusCodes.OK,
      'Recommendation retrieved successfully.',
      aiResponse.data
    );
  } catch (error) {
    // Handle axios errors distinctly from application errors
    if (error.code === 'ECONNABORTED') {
      throw new ApiError(
        StatusCodes.GATEWAY_TIMEOUT,
        'AI service timed out. Please try again later.'
      );
    }

    if (error.response) {
      // AI service responded with an error status
      throw new ApiError(
        StatusCodes.BAD_GATEWAY,
        `AI service error: ${error.response.data?.message || 'Unknown error'}`
      );
    }

    // Network error — AI service is unreachable
    throw new ApiError(
      StatusCodes.SERVICE_UNAVAILABLE,
      'AI service is currently unavailable. Please try again later.'
    );
  }
};

module.exports = { getServiceRecommendation };
