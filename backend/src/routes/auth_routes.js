const express = require('express');
const { register, login, refreshToken, logout, changePassword } = require('../controllers/auth_controller');
const { authenticate } = require('../middleware/auth_middleware');

const router = express.Router();

router.post('/register',        register);
router.post('/login',           login);
router.post('/refresh',         refreshToken);
router.post('/logout',          authenticate, logout);
router.put('/change-password',  authenticate, changePassword);

module.exports = router;
