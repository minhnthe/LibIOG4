const express = require('express');
const {
  getMe,
  getMyQr,
  updateMe,
  registerDevice,
  getFcmStatus,
  sendSelfTestPush,
} = require('../controllers/user_controller');
const { authenticate } = require('../middleware/auth_middleware');

const router = express.Router();

router.use(authenticate); // tất cả user routes đều cần auth

router.get('/me', getMe);
router.get('/me/qr', getMyQr);
router.put('/me', updateMe);
router.post('/register-device', registerDevice);
router.get('/me/fcm-status', getFcmStatus);
router.post('/me/test-push', sendSelfTestPush);

module.exports = router;
