const { Router } = require('express');
const platformController = require('./platform.controller');

const router = Router();

router.get('/', platformController.getSettings);

module.exports = router;
