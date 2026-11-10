const User = require('../models/user_model');
const LibraryCard = require('../models/library_card_model');

// GET /api/users/me
async function getMe(req, res, next) {
  try {
    const card = await LibraryCard.findOne({ user_id: req.user._id });
    const safeData = req.user.toSafeObject();
    if (card) {
      safeData.cardExpiry = card.expiry_date;
      safeData.cardStatus = card.status;
    }
    res.json({ success: true, data: safeData });
  } catch (err) {
    next(err);
  }
}

// GET /api/users/me/qr
// Định dạng QR chuẩn: LIB:{student_id}:{card_id}:{expireEpoch}
async function getMyQr(req, res, next) {
  try {
    const user = req.user;

    // 1. Kiểm tra trạng thái tài khoản
    if (user.status === 'BLOCKED' || user.status === 'locked') {
      return res.status(403).json({
        success: false,
        errorCode: 'ACCOUNT_LOCKED',
        message: 'Tài khoản đang bị khóa. Vui lòng liên hệ thủ thư',
      });
    }

    // 2. Kiểm tra thẻ thư viện trong bảng library_cards
    const card = await LibraryCard.findOne({ user_id: user._id });
    if (!card) {
      return res.status(404).json({
        success: false,
        errorCode: 'CARD_NOT_FOUND',
        message: 'Chưa có thẻ thư viện. Vui lòng liên hệ thủ thư',
      });
    }

    if (card.status === 'LOCKED') {
      return res.status(403).json({
        success: false,
        errorCode: 'CARD_LOCKED',
        message: 'Thẻ thư viện đang bị khóa. Vui lòng liên hệ thủ thư',
      });
    }

    if (card.isExpired() || card.status === 'EXPIRED') {
      return res.status(403).json({
        success: false,
        errorCode: 'CARD_EXPIRED',
        message: 'Thẻ thư viện đã hết hạn. Vui lòng gia hạn tại quầy',
      });
    }

    // Sinh mã QR payload chuẩn thiết kế gốc: LIB:{student_id}:{card_id}:{expireEpoch}
    // Dynamic rolling QR: hết hạn sau 60 giây (BR-12, BR-13)
    const expireEpoch = Math.floor(Date.now() / 1000) + 60;
    const qrPayload = `LIB:${user.student_id}:${card._id}:${expireEpoch}`;

    res.json({
      success: true,
      data: {
        qrPayload,
        studentId: user.student_id,
        cardId: card._id,
        name: user.full_name,
        expiresAt: new Date(expireEpoch * 1000).toISOString(),
        expiresIn: 60,
        cardExpiry: card.expiry_date,
        status: card.status,
        isInside: Boolean(user.is_inside),
        isInsideLibrary: Boolean(user.is_inside),
      },
    });
  } catch (err) {
    next(err);
  }
}

// PUT /api/users/me
async function updateMe(req, res, next) {
  try {
    const rawName = req.body.name || req.body.fullName || req.body.full_name;
    const { phone } = req.body;
    const rawAvatar = req.body.avatarUrl || req.body.avatar_url;

    const updateFields = {};
    if (rawName) updateFields.full_name = rawName.trim();
    if (phone !== undefined) updateFields.phone = phone.trim();
    if (rawAvatar !== undefined) updateFields.avatar_url = rawAvatar;

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: updateFields },
      { new: true }
    ).populate('role_id');

    const card = await LibraryCard.findOne({ user_id: user._id });
    const safeData = user.toSafeObject();
    if (card) {
      safeData.cardExpiry = card.expiry_date;
      safeData.cardStatus = card.status;
    }

    res.json({ success: true, message: 'Cập nhật thành công', data: safeData });
  } catch (err) {
    next(err);
  }
}

// POST /api/users/register-device — lưu FCM token
async function registerDevice(req, res, next) {
  try {
    const rawToken = req.body.deviceToken || req.body.device_token;
    if (!rawToken) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_INPUT',
        message: 'deviceToken bắt buộc',
      });
    }

    await User.findByIdAndUpdate(req.user._id, { $set: { device_token: rawToken } });
    console.log(`[FCM] Đã cập nhật device_token cho ${req.user.student_id}: ${rawToken.substring(0, 15)}...`);
    res.json({ success: true, message: 'Đã đăng ký thiết bị' });
  } catch (err) {
    next(err);
  }
}

// GET /api/users/me/fcm-status — kiểm tra tình trạng kết nối FCM và token
async function getFcmStatus(req, res, next) {
  try {
    const user = await User.findById(req.user._id).select('student_id full_name device_token');
    const { isFirebaseConfigured } = require('../services/fcm_service');
    const hasToken = Boolean(user && user.device_token && user.device_token.trim());
    const isConfigured = Boolean(isFirebaseConfigured());

    res.json({
      success: true,
      data: {
        studentId: user?.student_id,
        fullName: user?.full_name,
        hasDeviceToken: hasToken,
        deviceTokenPreview: hasToken ? `${user.device_token.substring(0, 20)}...` : null,
        isFirebaseConfigured: isConfigured,
      },
    });
  } catch (err) {
    next(err);
  }
}

// POST /api/users/me/test-push — bắn thử 1 thông báo tới thiết bị của chính người dùng hiện tại
async function sendSelfTestPush(req, res, next) {
  try {
    const user = await User.findById(req.user._id);
    if (!user || !user.device_token || !user.device_token.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Tài khoản chưa có device_token trong database. Hãy mở app trên điện thoại và đăng nhập lại.',
      });
    }

    const { sendPushNotification } = require('../services/fcm_service');
    const result = await sendPushNotification(user.device_token, {
      title: '🔔 Thử Nghiệm Thông Báo Thư Viện',
      body: `Xin chào ${user.full_name}! Hệ thống thông báo đẩy (FCM) đã được kết nối và hoạt động tốt.`,
      data: {
        type: 'TEST_PUSH',
        timestamp: new Date().toISOString(),
      },
    });

    res.json({
      success: result.success,
      message: result.success
        ? 'Đã gửi thông báo thử nghiệm thành công'
        : `Gửi thông báo thất bại: ${result.message || result.reason || result.error}`,
      result,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getMe,
  getMyQr,
  updateMe,
  registerDevice,
  getFcmStatus,
  sendSelfTestPush,
};
