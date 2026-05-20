'use strict';
const { Router } = require('express');
const { param }  = require('express-validator');
const ctrl       = require('./favorite.controller');
const { protect }     = require('../../middleware/auth.middleware');
const { authorize }   = require('../../middleware/role.middleware');
const { validate }    = require('../../middleware/validate.middleware');

const router = Router();

router.get('/',     protect, authorize('user'),   ctrl.listMine);
router.get('/ids',  protect, authorize('user'),   ctrl.listMyIds);
router.get('/me/count', protect, authorize('worker'), ctrl.myCountAsWorker);
router.post('/:workerId',   protect, authorize('user'),
  validate([param('workerId').isMongoId()]),
  ctrl.add);
router.delete('/:workerId', protect, authorize('user'),
  validate([param('workerId').isMongoId()]),
  ctrl.remove);

module.exports = router;
