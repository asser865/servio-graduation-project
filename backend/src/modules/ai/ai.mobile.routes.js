const express                  = require('express');
const { getMobileRecommendation } = require('./ai.mobile.controller');

const router = express.Router();

router.post('/recommend', getMobileRecommendation);

module.exports = router;
