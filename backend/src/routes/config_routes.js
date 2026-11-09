const express = require('express');
const { getConfigs, updateConfigs } = require('../controllers/config_controller');
const { authenticate, requireAdmin } = require('../middleware/auth_middleware');

const router = express.Router();

router.get('/',  getConfigs);                         // public (student, admin, scanner station)
router.put('/',  authenticate, requireAdmin, updateConfigs); // admin only

module.exports = router;
