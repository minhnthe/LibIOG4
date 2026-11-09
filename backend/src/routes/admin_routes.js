const express = require('express');
const {
  listUsers, createUser, getUserById,
  updateUser, updateUserStatus, deleteUser,
  restoreUser,
} = require('../controllers/admin_user_controller');
const {
  getPresentList, getRealtimeStats,
  getCheckinReport, getUserHistory, exportReport,
  forceCheckOutUser,
} = require('../controllers/admin_report_controller');
const { authenticate, requireAdmin, requireStaff } = require('../middleware/auth_middleware');

const router = express.Router();

// Tất cả admin/staff routes yêu cầu auth + role ADMIN hoặc LIBRARIAN
router.use(authenticate, requireStaff);

// ── Quản lý thành viên ──
router.get('/users', listUsers);
router.post('/users', createUser);
router.get('/users/:id', getUserById);
router.put('/users/:id', updateUser);
router.patch('/users/:id/status', updateUserStatus);
router.delete('/users/:id', requireAdmin, deleteUser); // CHỈ ADMIN MỚI ĐƯỢC XÓA USER
router.post('/users/:id/restore', requireAdmin, restoreUser); // CHỈ ADMIN MỚI ĐƯỢC KHÔI PHỤC USER

// ── Theo dõi thời gian thực ──
router.get('/realtime/present', getPresentList);
router.get('/realtime/stats', getRealtimeStats);
router.post('/realtime/checkout/:userId', forceCheckOutUser);

// ── Báo cáo & thống kê ──
router.get('/reports/checkin', getCheckinReport);
router.get('/reports/users/:id/history', getUserHistory);
router.get('/reports/export', exportReport);

// ── Cấu hình hệ thống ──
router.put('/config', requireAdmin, require('../controllers/config_controller').updateConfigs); // CHỈ ADMIN MỚI ĐƯỢC ĐỔI CONFIG

module.exports = router;
