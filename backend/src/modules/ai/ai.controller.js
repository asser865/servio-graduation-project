// ─── Purpose ──────────────────────────────────────────────────────────────────
// AI controller acts as a gateway — it forwards requests to the Python AI
// microservice and returns its response. Smart Match uses AI_SERVICE_URL.
// Website room finishing uses AI_FINISHER_SERVICE_URL so its runtime can
// evolve independently from both Smart Match and the mobile application.
// ─────────────────────────────────────────────────────────────────────────────

const axios           = require('axios');
const FormData        = require('form-data');
const { StatusCodes } = require('http-status-codes');
const ApiError        = require('../../utils/ApiError');
const ApiResponse     = require('../../utils/ApiResponse');
const User            = require('../users/user.model');
const { resolveSlug } = require('../../utils/locationsTaxonomy');

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

// Generic city/governorate tokens that are too broad to use alone as a location
// filter when a district-level token is also present. "Cairo" alone matches
// every seeded worker; "Heliopolis" does not.
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

  // Primary split: commas, slashes, newlines
  const primaryTokens = location
    .split(/[,/\n]+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 3 && !/^\d+$/.test(s));

  // Space-compound expansion: "Dokki Giza" → also try "Dokki" and "Giza"
  // Only expand tokens where at least one constituent word is a generic city/
  // governorate name — that signals a "district + city" compound. Tokens where
  // no word is generic (e.g. "Nasr City" as a proper district name) are left as-is.
  const expanded = primaryTokens.flatMap((token) => {
    if (!token.includes(' ')) return [token];
    const words = token.split(/\s+/).filter((w) => w.length > 3 && !/^\d+$/.test(w));
    const hasGenericWord = words.some((w) => GENERIC_AREA_TOKENS.has(w.toLowerCase()));
    return hasGenericWord && words.length > 1 ? [token, ...words] : [token];
  });

  const unique = [...new Set(expanded)];

  // Prefer specific (non-generic) tokens; fall back to all if nothing specific
  const specific = unique.filter((t) => !GENERIC_AREA_TOKENS.has(t.toLowerCase()));
  return specific.length ? specific : unique;
}

function categoryForService(service) {
  return SERVICE_TO_CATEGORY[service] || null;
}

async function findMatchingWorkers(aiData, bodyLocation) {
  // Compute effectiveLocation BEFORE any early return so it is always in the response.
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
    // Preferred: resolve the request location to a canonical slug and match
    // against `coverageMatchSlugs` (which already includes ancestors + descendants).
    // This is what makes "Nasr City" match a worker whose coverage is "Cairo".
    const requestSlug = resolveSlug(effectiveLocation);
    const orClauses = [];
    if (requestSlug) orClauses.push({ coverageMatchSlugs: requestSlug });

    // Regex fallback for legacy workers without slugs and for free-form labels
    // that fall outside the taxonomy.
    const keywords = extractAreaKeywords(effectiveLocation);
    keywords.forEach((kw) => {
      const re = new RegExp(kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      orClauses.push({ coverageAreas: re }, { serviceArea: re }, { locationLabel: re });
    });

    if (orClauses.length) filter.$or = orClauses;
  }

  const workers = await User.find(filter)
    .select('name profileImage categories skills averageRating totalReviews locationLabel hourlyRate yearsExperience bio isAvailable completedJobs')
    .sort({ averageRating: -1, totalReviews: -1 })
    .limit(6);

  return { workers, effectiveLocation };
}

// If effectiveLocation fills the "location" field that the Python AI marked missing,
// remove it from missing_fields, update scenario, and patch extracted.location so
// the response is internally consistent (follow_up_message won't say "Add Location…").
// Patch extracted.location with effectiveLocation (address pill / body.location).
// Remove "location" from BOTH blocking missing_fields and advisory_missing_fields when filled.
// Upgrade scenario from vague → issue_mode when location was the only blocking field.
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

  // Strip location from blocking list (legacy: may still arrive from older Python builds)
  const newMissingFields = (aiData.missing_fields || []).filter((f) => f !== 'location');
  const newMissingLabels = (aiData.missing_field_labels || []).filter(
    (l) => !l.toLowerCase().includes('location')
  );

  // Strip location from advisory list (new: added by Task 1)
  const newAdvisoryFields = (aiData.advisory_missing_fields || []).filter((f) => f !== 'location');
  const newAdvisoryLabels = (aiData.advisory_missing_field_labels || []).filter(
    (l) => !l.toLowerCase().includes('location')
  );

  // Rebuild advisory_message_missing without the location mention
  const advisoryLabelsText = newAdvisoryLabels.join(', ');
  const newAdvisoryMessageMissing = advisoryLabelsText
    ? `For closer matches, add: ${advisoryLabelsText}.`
    : '';

  const stillNeedsFollowUp = newMissingFields.length > 0;
  const newScenario = stillNeedsFollowUp ? aiData.scenario : (aiData.issue_mode || 'single');
  const locationWasMissing = (aiData.missing_fields || []).includes('location');

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
    follow_up_message:             (stillNeedsFollowUp && !locationWasMissing) ? aiData.follow_up_message : '',
  };
}

// ── GET AI RECOMMENDATION (Public) ───────────────────────────────────────────
// WHAT: Forwards a service request description to the Python AI microservice.
// HOW:  Expects { prompt } and accepts legacy { description } for older callers.
const getServiceRecommendation = async (req, res) => {
  const prompt       = String(req.body.prompt || req.body.description || '').trim();
  const bodyLocation = String(req.body.location || '').trim();

  if (!prompt) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Prompt is required for a recommendation.');
  }

  try {
    const aiResponse = await axios.post(
      `${process.env.AI_SERVICE_URL}/recommend`,
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

// ── ANALYZE ROOM (Authenticated) ─────────────────────────────────────────────
// WHAT: Forwards a room photo + dimensions to the Python AI microservice.
// HOW:  Expects multipart/form-data with image, length_m, width_m, height_m,
//       budget_egp, and optional style.
const analyzeRoom = async (req, res) => {
  if (!req.file) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Room image is required.');
  }

  const { length_m, width_m, height_m, budget_egp, style, include_render } = req.body;

  if (!length_m || !width_m || !height_m || !budget_egp) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'length_m, width_m, height_m, and budget_egp are required.');
  }

  try {
    const aiFinisherServiceUrl = process.env.AI_FINISHER_SERVICE_URL || process.env.AI_SERVICE_URL;
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
    form.append('include_render', String(include_render === true || include_render === 'true'));

    const aiResponse = await axios.post(
      `${aiFinisherServiceUrl}/ai/analyze-room`,
      form,
      {
        headers: form.getHeaders(),
        // Gemini call + Stable Diffusion render can each take 30–90s on CPU.
        // Give upstream 3 minutes before declaring a gateway timeout.
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
    throw new ApiError(StatusCodes.SERVICE_UNAVAILABLE, 'AI service is currently unavailable.');
  }
};

module.exports = { getServiceRecommendation, extractAreaKeywords, analyzeRoom };
