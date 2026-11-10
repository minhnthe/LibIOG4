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
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
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

async function sendPushNotification(deviceToken, { title, body, data = {} }) {
  if (!deviceToken || typeof deviceToken !== 'string' || !deviceToken.trim()) {
    return { success: false, reason: 'NO_DEVICE_TOKEN' };
  }

  const fcmAdmin = initFirebase();
  if (!fcmAdmin) {
    return { success: false, reason: 'FIREBASE_NOT_CONFIGURED' };
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
  if (!user || !user.device_token) {
    console.log(`[FCM] Không thể gửi push mời ra: User ${user?.student_id || ''} chưa có device_token`);
    return;
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

module.exports = {
  sendPushNotification,
  sendCheckInNotification,
  sendCardStatusNotification,
  sendForceCheckOutNotification,
};
