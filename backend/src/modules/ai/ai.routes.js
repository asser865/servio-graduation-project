// ─── Purpose ──────────────────────────────────────────────────────────────────
// AI routes — all behind protect() so anonymous callers cannot spam the AI
// microservice and incur compute costs.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }       = require('express');
const aiController     = require('./ai.controller');
const { protect }      = require('../../middleware/auth.middleware');

const router = Router();

// POST /api/v1/ai/recommend — authenticated users only
router.post('/recommend', protect, aiController.getServiceRecommendation);

module.exports = router;
