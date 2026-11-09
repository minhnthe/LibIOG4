const jwt = require('jsonwebtoken');
const User = require('../models/user_model');

/**
 * Xác thực JWT. Gắn req.user và req.userRole nếu hợp lệ.
 */
async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, errorCode: 'UNAUTHORIZED', message: 'Chưa đăng nhập' });
    }

    const token = authHeader.split(' ')[1];
    const secret = process.env.JWT_SECRET || 'library_access_jwt_secret_dev_key_2026';
    const decoded = jwt.verify(token, secret);

    const user = await User.findById(decoded.id)
      .populate('role_id')
      .select('-password_hash -password -refresh_token -refreshToken');

    if (!user) {
      return res.status(401).json({ success: false, errorCode: 'UNAUTHORIZED', message: 'Tài khoản không tồn tại' });
    }

    if (user.deleted_at || user.status === 'deleted') {
      return res.status(401).json({ success: false, errorCode: 'UNAUTHORIZED', message: 'Tài khoản không tồn tại hoặc đã bị xóa' });
    }

    if (user.status === 'BLOCKED' || user.status === 'locked') {
      return res.status(403).json({ success: false, errorCode: 'ACCOUNT_LOCKED', message: 'Tài khoản bị khóa. Vui lòng liên hệ thủ thư' });
    }

    req.user = user;
    req.userRole = (user.role_id?.role_name || user.role || 'STUDENT').toUpperCase();
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, errorCode: 'TOKEN_EXPIRED', message: 'Phiên đăng nhập hết hạn' });
    }
    return res.status(401).json({ success: false, errorCode: 'UNAUTHORIZED', message: 'Token không hợp lệ' });
  }
}

/**
 * Chỉ cho phép Quản trị viên (ADMIN).
 */
function requireAdmin(req, res, next) {
  const role = (req.userRole || req.user?.role_id?.role_name || req.user?.role || '').toUpperCase();
  if (role !== 'ADMIN') {
    return res.status(403).json({ success: false, errorCode: 'FORBIDDEN', message: 'Yêu cầu quyền Quản trị viên (ADMIN)' });
  }
  next();
}

/**
 * Cho phép Nhân viên thư viện (LIBRARIAN) và Quản trị viên (ADMIN).
 */
function requireStaff(req, res, next) {
  const role = (req.userRole || req.user?.role_id?.role_name || req.user?.role || '').toUpperCase();
  if (role !== 'ADMIN' && role !== 'LIBRARIAN') {
    return res.status(403).json({
      success: false,
      errorCode: 'FORBIDDEN',
      message: 'Yêu cầu quyền Thủ thư (LIBRARIAN) hoặc Quản trị viên (ADMIN)',
    });
  }
  next();
}

module.exports = { authenticate, requireAdmin, requireStaff };
