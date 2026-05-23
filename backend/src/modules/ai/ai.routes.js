// ─── Purpose ──────────────────────────────────────────────────────────────────
// AI routes — Smart Match entry point.
// ─────────────────────────────────────────────────────────────────────────────

const { Router }       = require('express');
const multer           = require('multer');
const { protect }      = require('../../middleware/auth.middleware');
const aiController     = require('./ai.controller');

const router  = Router();
const upload  = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    cb(null, allowed.includes(file.mimetype));
  },
});

// POST /recommend is public — guests are allowed; no auth required
router.post('/recommend', aiController.getServiceRecommendation);

// POST /api/v1/ai/analyze-room — authenticated users only
router.post('/analyze-room', protect, upload.single('image'), aiController.analyzeRoom);

module.exports = router;
