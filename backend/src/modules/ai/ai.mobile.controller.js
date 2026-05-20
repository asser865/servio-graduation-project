const axios           = require('axios');
const FormData        = require('form-data');
const { StatusCodes } = require('http-status-codes');
const ApiError        = require('../../utils/ApiError');
const ApiResponse     = require('../../utils/ApiResponse');
const User            = require('../users/user.model');

const SERVICE_TO_CATEGORY = {
  Plumbing: 'plumbing',
  Electrical: 'electrical',
  'A/C': 'hvac',
  Carpentry: 'carpentry',
  Cleaning: 'cleaning',
  Painting: 'painting',
  'Appliance Repair': 'appliance',
  Handyman: 'handyman',
};

const GENERIC_AREA_TOKENS = new Set([
  'cairo', 'giza', 'egypt',
  'al qahira', 'al qāhirah',
  'cairo governorate', 'giza governorate',
]);

const ROOM_LOCATION_TOKENS = new Set([
  'bathroom', 'kitchen', 'bedroom', 'room', 'living room', 'ceiling',
  'wall', 'walls', 'floor', 'panel', 'electrical panel',
]);

function isRoomOnlyLocation(location) {
  if (!location || typeof location !== 'string') return false;
  const normalized = location
    .trim()
    .toLowerCase()
    .replace(/\b(my|the|a|an)\b/g, '')
    .replace(/\s+/g, ' ')
    .replace(/^[\s,._-]+|[\s,._-]+$/g, '');
  return ROOM_LOCATION_TOKENS.has(normalized);
}

function extractAreaKeywords(location) {
  if (!location || typeof location !== 'string') return [];
  const primaryTokens = location
    .split(/[,/\n]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 3 && !/^\d+$/.test(s));
  const expanded = primaryTokens.flatMap((token) => {
    if (!token.includes(' ')) return [token];
    const words = token.split(/\s+/).filter((w) => w.length > 3 && !/^\d+$/.test(w));
    const hasGenericWord = words.some((w) => GENERIC_AREA_TOKENS.has(w.toLowerCase()));
    return hasGenericWord && words.length > 1 ? [token, ...words] : [token];
  });
  const unique = [...new Set(expanded)];
  const specific = unique.filter((t) => !GENERIC_AREA_TOKENS.has(t.toLowerCase()));
  return specific.length ? specific : unique;
}

function categoryForService(service) {
  return SERVICE_TO_CATEGORY[service] || null;
}

async function findMatchingWorkers(aiData, bodyLocation) {
  const aiLocation = String(aiData.extracted?.location || '').trim();
  const usableAiLocation = isRoomOnlyLocation(aiLocation) ? '' : aiLocation;
  const effectiveLocation = String(usableAiLocation || bodyLocation || '').trim();

  const services = Array.isArray(aiData.steps) && aiData.steps.length
    ? aiData.steps.map((step) => step.service)
    : [aiData.recommended_service].filter(Boolean);

  const categories = [...new Set(services.map(categoryForService).filter(Boolean))];
  if (!categories.length) return { workers: [], effectiveLocation };

  const filter = {
    role:        'worker',
    isActive:    true,
    isVerified:  true,
    isAvailable: true,
    categories:  { $in: categories },
  };

  if (effectiveLocation) {
    const keywords = extractAreaKeywords(effectiveLocation);
    if (keywords.length) {
      filter.$or = keywords.flatMap((kw) => {
        const re = new RegExp(kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
        return [
          { coverageAreas: re },
          { serviceArea:   re },
          { locationLabel: re },
        ];
      });
    }
  }

  const workers = await User.find(filter)
    .select('name profileImage categories skills averageRating totalReviews locationLabel hourlyRate yearsExperience bio isAvailable completedJobs')
    .sort({ averageRating: -1, totalReviews: -1 })
    .limit(6);

  return { workers, effectiveLocation };
}

function postProcessAiData(aiData, effectiveLocation) {
  const aiLocation = String(aiData.extracted?.location || '').trim();
  const shouldReplaceLocation = !aiLocation || isRoomOnlyLocation(aiLocation);

  if (!effectiveLocation) {
    return isRoomOnlyLocation(aiLocation)
      ? { ...aiData, extracted: { ...(aiData.extracted || {}), location: null } }
      : aiData;
  }

  const patchedExtracted = {
    ...(aiData.extracted || {}),
    location: shouldReplaceLocation ? effectiveLocation : aiData.extracted.location,
  };

  const newMissingFields = (aiData.missing_fields || []).filter((f) => f !== 'location');
  const newMissingLabels = (aiData.missing_field_labels || []).filter(
    (l) => !l.toLowerCase().includes('location')
  );
  const newAdvisoryFields = (aiData.advisory_missing_fields || []).filter((f) => f !== 'location');
  const newAdvisoryLabels = (aiData.advisory_missing_field_labels || []).filter(
    (l) => !l.toLowerCase().includes('location')
  );

  const advisoryLabelsText = newAdvisoryLabels.join(', ');
  const newAdvisoryMessageMissing = advisoryLabelsText
    ? `For closer matches, add: ${advisoryLabelsText}.`
    : '';

  const stillNeedsFollowUp = newMissingFields.length > 0;
  const newScenario = stillNeedsFollowUp ? aiData.scenario : (aiData.issue_mode || 'single');

  return {
    ...aiData,
    extracted:                     patchedExtracted,
    missing_fields:                newMissingFields,
    missing_field_labels:          newMissingLabels,
    advisory_missing_fields:       newAdvisoryFields,
    advisory_missing_field_labels: newAdvisoryLabels,
    advisory_message_missing:      newAdvisoryMessageMissing,
    needs_follow_up:               stillNeedsFollowUp,
    scenario:                      newScenario,
    follow_up_message:             stillNeedsFollowUp ? aiData.follow_up_message : '',
  };
}

const getMobileRecommendation = async (req, res) => {
  const prompt       = String(req.body.prompt || req.body.description || '').trim();
  const bodyLocation = String(req.body.location || '').trim();

  if (!prompt) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Prompt is required for a recommendation.');
  }

  const mobileAiUrl = process.env.AI_MOBILE_SERVICE_URL || 'http://localhost:8001';

  try {
    const aiResponse = await axios.post(
      `${mobileAiUrl}/recommend`,
      { prompt },
      { timeout: 15_000 }
    );

    const rawAiData = aiResponse.data || {};
    const { workers: matches, effectiveLocation } = await findMatchingWorkers(rawAiData, bodyLocation);
    const aiData = postProcessAiData(rawAiData, effectiveLocation);

    return ApiResponse.success(
      res,
      StatusCodes.OK,
      'Recommendation retrieved successfully.',
      { ...aiData, matches, effectiveLocation }
    );
  } catch (error) {
    if (error.code === 'ECONNABORTED') {
      throw new ApiError(StatusCodes.GATEWAY_TIMEOUT, 'AI service timed out. Please try again later.');
    }
    if (error.response) {
      throw new ApiError(StatusCodes.BAD_GATEWAY, `AI service error: ${error.response.data?.message || 'Unknown error'}`);
    }
    throw new ApiError(StatusCodes.SERVICE_UNAVAILABLE, 'AI service is currently unavailable. Please try again later.');
  }
};

const analyzeMobileRoom = async (req, res) => {
  if (!req.file) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Room image is required.');
  }

  const { length_m, width_m, height_m, budget_egp, style, include_render } = req.body;

  if (!length_m || !width_m || !height_m || !budget_egp) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'length_m, width_m, height_m, and budget_egp are required.');
  }

  const mobileMainAiUrl = process.env.AI_MOBILE_MAIN_SERVICE_URL || 'http://localhost:8002';

  try {
    const form = new FormData();
    form.append('image', req.file.buffer, {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    form.append('length_m', length_m);
    form.append('width_m', width_m);
    form.append('height_m', height_m);
    form.append('budget_egp', budget_egp);
    form.append('style', style || 'modern');
    if (include_render !== undefined) {
      form.append('include_render', include_render);
    }

    const aiResponse = await axios.post(
      `${mobileMainAiUrl}/ai/analyze-room`,
      form,
      {
        headers: form.getHeaders(),
        timeout: 180_000,
        maxContentLength: Infinity,
        maxBodyLength: Infinity,
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
    throw new ApiError(StatusCodes.SERVICE_UNAVAILABLE, 'Mobile AI service is currently unavailable.');
  }
};

module.exports = { getMobileRecommendation, analyzeMobileRoom };
