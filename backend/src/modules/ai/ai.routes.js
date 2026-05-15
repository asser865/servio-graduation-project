// ─── Purpose ──────────────────────────────────────────────────────────────────
// AI routes — all behind protect() so anonymous callers cannot spam the AI
// microservice and incur compute costs.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }       = require('express');
const multer           = require('multer');
const aiController     = require('./ai.controller');
const { protect }      = require('../../middleware/auth.middleware');

const router  = Router();
const upload  = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    cb(null, allowed.includes(file.mimetype));
  },
});

// POST /api/v1/ai/recommend — authenticated users only
router.post('/recommend', protect, aiController.getServiceRecommendation);

// POST /api/v1/ai/analyze-room — authenticated users only
router.post('/analyze-room', protect, upload.single('image'), aiController.analyzeRoom);

module.exports = router;
