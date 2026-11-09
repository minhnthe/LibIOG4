const express = require('express');
const { getMyHistory } = require('../controllers/checkin_controller');
const { authenticate } = require('../middleware/auth_middleware');

const router = express.Router();

router.get('/me', authenticate, getMyHistory);

module.exports = router;
