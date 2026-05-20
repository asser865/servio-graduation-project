const express                                = require('express');
const multer                                 = require('multer');
const { protect }                            = require('../../middleware/auth.middleware');
const { getMobileRecommendation, analyzeMobileRoom } = require('./ai.mobile.controller');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    cb(null, allowed.includes(file.mimetype));
  },
});

router.post('/recommend', getMobileRecommendation);
router.post('/analyze-room', protect, upload.single('image'), analyzeMobileRoom);

module.exports = router;
