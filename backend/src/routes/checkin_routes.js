const express = require('express');
const { checkIn, syncLogs, currentStatus } = require('../controllers/checkin_controller');
const { authenticate, requireStaff } = require('../middleware/auth_middleware');

const router = express.Router();

router.use(authenticate);

// Trạm quét và đồng bộ dữ liệu ngoại tuyến chỉ dành cho Staff (LIBRARIAN, ADMIN)
router.post('/', requireStaff, checkIn);
router.post('/sync', requireStaff, syncLogs);

// Sinh viên kiểm tra trạng thái đang có mặt trong thư viện của chính mình
router.get('/current-status', currentStatus);

module.exports = router;
