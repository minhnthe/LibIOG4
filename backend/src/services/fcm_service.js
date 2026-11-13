const fs = require('fs');
const path = require('path');
const User = require('../models/user_model');

let admin = null;
let isInitialized = false;

function initFirebase() {
  if (isInitialized) return admin;

  let serviceAccount = null;

  // 1. Ưu tiên nạp từ biến môi trường JSON (Rất tiện lợi khi deploy Render/Cloud)
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
      const rawEnv = process.env.FIREBASE_SERVICE_ACCOUNT_JSON.trim();
      // Hỗ trợ cả chuỗi JSON thuần và chuỗi Base64
      if (rawEnv.startsWith('{')) {
        serviceAccount = JSON.parse(rawEnv);
      } else {
        const decoded = Buffer.from(rawEnv, 'base64').toString('utf-8');
        serviceAccount = JSON.parse(decoded);
      }
    } catch (e) {
      console.warn('[FCM] Không thể parse FIREBASE_SERVICE_ACCOUNT_JSON:', e.message);
    }
  }

  // 2. Dự phòng nạp từ file path
  if (!serviceAccount) {
    const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || path.join(__dirname, '../../firebase-service-account.json');
    if (fs.existsSync(keyPath)) {
      try {
        serviceAccount = require(path.resolve(keyPath));
      } catch (e) {
        console.warn('[FCM] Không thể nạp file Service Account:', e.message);
      }
    }
  }

  if (!serviceAccount) {
    return null;
  }

  try {
    admin = require('firebase-admin');
    if (admin.apps.length === 0) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log('[FCM] Firebase Admin SDK đã khởi tạo thành công');
    }
    isInitialized = true;
    return admin;
  } catch (err) {
    console.warn('[FCM] Không thể khởi tạo Firebase Admin SDK:', err.message);
    return null;
  }
}

function isFirebaseConfigured() {
  const fcmAdmin = initFirebase();
  return Boolean(fcmAdmin);
}

async function sendPushNotification(deviceToken, { title, body, data = {} }) {
  if (!deviceToken || typeof deviceToken !== 'string' || !deviceToken.trim()) {
    console.warn('[FCM] sendPushNotification gọi nhưng không có deviceToken');
    return { success: false, reason: 'NO_DEVICE_TOKEN', message: 'deviceToken trống hoặc không hợp lệ' };
  }

  const fcmAdmin = initFirebase();
  if (!fcmAdmin) {
    console.warn('[FCM] Chưa cấu hình Firebase Admin SDK (thiếu FIREBASE_SERVICE_ACCOUNT_JSON hoặc file JSON)');
    return {
      success: false,
      reason: 'FIREBASE_NOT_CONFIGURED',
      message: 'Hệ thống chưa nạp được cấu hình Firebase (kiểm tra FIREBASE_SERVICE_ACCOUNT_JSON trên Render)',
    };
  }

  const message = {
    token: deviceToken.trim(),
    notification: {
      title,
      body,
    },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v ?? '')])
    ),
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'library_access_channel',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };

  try {
    const response = await fcmAdmin.messaging().send(message);
    return { success: true, messageId: response };
  } catch (error) {
    console.error(`[FCM] Lỗi gửi thông báo: ${error.message}`);
    if (
      error.code === 'messaging/registration-token-not-registered' ||
      error.code === 'messaging/invalid-registration-token'
    ) {
      await User.updateOne({ device_token: deviceToken }, { $set: { device_token: '' } });
      console.log(`[FCM] Đã xóa device_token hết hạn: ${deviceToken.substring(0, 10)}...`);
    }
    return { success: false, error: error.message };
  }
}

async function sendCheckInNotification(user, log) {
  if (!user || !user.device_token) return;
  const isCheckIn = log.action_type === 'CHECK_IN' || log.status === 'INSIDE';
  const title = isCheckIn ? 'Check-in Thư Viện Thành Công' : 'Check-out Thư Viện Thành Công';
  const body = isCheckIn
    ? `Chào ${user.full_name}! Bạn đã vào thư viện lúc ${new Date(log.check_in_time).toLocaleTimeString('vi-VN')}. Chúc bạn học tập hiệu quả!`
    : `Bạn đã rời thư viện. Thời gian lưu trú: ${log.total_minutes || 0} phút. Hẹn gặp lại!`;

  return sendPushNotification(user.device_token, {
    title,
    body,
    data: {
      type: isCheckIn ? 'CHECK_IN_SUCCESS' : 'CHECK_OUT_SUCCESS',
      studentId: user.student_id,
      timestamp: (log.check_out_time || log.check_in_time || new Date()).toISOString(),
      logId: log._id ? log._id.toString() : '',
    },
  });
}

async function sendCardStatusNotification(user, status, reason = '') {
  if (!user || !user.device_token) return;
  const isBlocked = status === 'BLOCKED' || status === 'LOCKED';
  const title = isBlocked ? 'Cảnh Báo: Thẻ Thư Viện Bị Khóa' : 'Thông Báo: Thẻ Đã Mở Khóa';
  const body = isBlocked
    ? `Thẻ của bạn đã bị khóa.${reason ? ' Lý do: ' + reason : ' Vui lòng liên hệ thủ thư tại quầy.'}`
    : 'Thẻ thư viện của bạn đã được kích hoạt lại. Bạn có thể tiếp tục sử dụng dịch vụ.';

  return sendPushNotification(user.device_token, {
    title,
    body,
    data: {
      type: isBlocked ? 'CARD_BLOCKED' : 'CARD_UNLOCKED',
      studentId: user.student_id,
      status,
      reason: reason || '',
      timestamp: new Date().toISOString(),
    },
  });
}

async function sendForceCheckOutNotification(user, log, staffName = 'Thủ thư') {
  if (!user || !user.device_token || !user.device_token.trim()) {
    console.log(`[FCM] Không thể gửi push mời ra: User ${user?.student_id || ''} chưa có device_token trong database`);
    return {
      success: false,
      reason: 'NO_DEVICE_TOKEN',
      message: `Sinh viên ${user?.student_id || ''} chưa đăng ký thiết bị nhận thông báo (cần đăng nhập app trên điện thoại)`,
    };
  }
  const duration = log && log.total_minutes ? log.total_minutes : 0;
  const title = 'Thông Báo: Bạn Đã Được Mời Rời Thư Viện';
  const body = `${staffName} đã thực hiện mời bạn rời khỏi thư viện. Thời gian lưu trú: ${duration} phút. Hẹn gặp lại bạn!`;

  return sendPushNotification(user.device_token, {
    title,
    body,
    data: {
      type: 'FORCE_CHECK_OUT',
      studentId: user.student_id,
      timestamp: (log?.check_out_time || new Date()).toISOString(),
      logId: log?._id ? log._id.toString() : '',
      durationMinutes: String(duration),
    },
  });
}

async function sendClosingSoonNotification(user, closeTime, warningMinutes) {
  if (!user || !user.device_token) return;

  return sendPushNotification(user.device_token, {
    title: 'Thư viện sắp đóng cửa',
    body: `Thư viện sẽ đóng cửa lúc ${closeTime}. Vui lòng chuẩn bị rời thư viện trong ${warningMinutes} phút tới.`,
    data: {
      type: 'LIBRARY_CLOSING_ALERT',
      studentId: user.student_id,
      closeTime,
      warningMinutes: String(warningMinutes),
      timestamp: new Date().toISOString(),
    },
  });
}

async function sendAutoCheckOutNotification(user, log) {
  if (!user || !user.device_token || !user.device_token.trim()) return;

  const duration = log && log.total_minutes ? log.total_minutes : 0;
  return sendPushNotification(user.device_token, {
    title: 'Thông báo: Hệ thống đã tự động check-out',
    body: `Thư viện đã đóng cửa. Bạn đã được tự động check-out sau ${duration} phút.`,
    data: {
      type: 'AUTO_CHECK_OUT',
      studentId: user.student_id,
      timestamp: (log?.check_out_time || new Date()).toISOString(),
      logId: log?._id ? log._id.toString() : '',
      durationMinutes: String(duration),
    },
  });
}

module.exports = {
  isFirebaseConfigured,
  sendPushNotification,
  sendCheckInNotification,
  sendCardStatusNotification,
  sendForceCheckOutNotification,
  sendClosingSoonNotification,
  sendAutoCheckOutNotification,
};
