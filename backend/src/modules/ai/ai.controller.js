// ─── Purpose ──────────────────────────────────────────────────────────────────
// AI controller acts as a gateway — it forwards requests to the Python AI
// microservice and returns its response. Isolating AI calls here means the
// AI_SERVICE_URL and retry/timeout logic is centralised, not scattered across
// multiple controllers.
// ─────────────────────────────────────────────────────────────────────────────

const axios           = require('axios');
const FormData        = require('form-data');
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

// ── ANALYZE ROOM (Authenticated) ─────────────────────────────────────────────
// WHAT: Forwards a room photo + dimensions to the Python AI microservice.
// HOW:  Expects multipart/form-data with image, length_m, width_m, height_m,
//       budget_egp, and optional style.
const analyzeRoom = async (req, res) => {
  if (!req.file) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Room image is required.');
  }

  const { length_m, width_m, height_m, budget_egp, style } = req.body;

  if (!length_m || !width_m || !height_m || !budget_egp) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'length_m, width_m, height_m, and budget_egp are required.');
  }

  try {
    const form = new FormData();
    form.append('image', req.file.buffer, {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    form.append('length_m',   length_m);
    form.append('width_m',    width_m);
    form.append('height_m',   height_m);
    form.append('budget_egp', budget_egp);
    form.append('style',      style || 'modern');

    const aiResponse = await axios.post(
      `${process.env.AI_SERVICE_URL}/ai/analyze-room`,
      form,
      {
        headers: form.getHeaders(),
        timeout: 30_000,
      }
    );

    return ApiResponse.success(
      res,
      StatusCodes.OK,
      'Room analysis completed successfully.',
      aiResponse.data
    );
  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      throw new ApiError(StatusCodes.GATEWAY_TIMEOUT, 'AI service timed out. Please try again later.');
    }
    if (error.response) {
      throw new ApiError(
        StatusCodes.BAD_GATEWAY,
        `AI service error: ${error.response.data?.detail || error.response.data?.message || 'Unknown error'}`
      );
    }
    throw new ApiError(StatusCodes.SERVICE_UNAVAILABLE, 'AI service is currently unavailable.');
  }
};

module.exports = { getServiceRecommendation, analyzeRoom };
