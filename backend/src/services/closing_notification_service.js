const User = require('../models/user_model');
const SystemConfig = require('../models/system_config_model');
const { sendClosingSoonNotification } = require('./fcm_service');
const {
  autoPromoteOperatingHours,
  getVNDateString,
  getVNTimeParts,
  resolveOperatingHoursForDate,
} = require('../utils/operating_hours_helper');

let lastNotificationKey = null;
let isChecking = false;

async function checkAndSendClosingNotifications() {
  if (isChecking) return;
  isChecking = true;

  try {
    const configs = await SystemConfig.find();
    const config = configs.reduce((map, item) => {
      map[item.config_key] = item.config_value;
      return map;
    }, {});

    await autoPromoteOperatingHours(config);

    const today = getVNDateString();
    const { openTime, closeTime } = resolveOperatingHoursForDate(config, new Date());
    const allowedDays = (config.ALLOWED_DAYS || 'Mon,Tue,Wed,Thu,Fri,Sat')
      .split(',')
      .map((day) => day.trim());
    const { hour, minute, weekday } = getVNTimeParts();

    if (!allowedDays.includes(weekday)) return;

    const warningMinutes = parseInt(
      config.WARNING_MINUTES_BEFORE_CLOSE || config.warningMinutesBeforeClose || '15',
      10
    );
    if (!Number.isFinite(warningMinutes) || warningMinutes <= 0) return;

    const [closeHour, closeMinute] = closeTime.split(':').map(Number);
    const currentTotalMinutes = hour * 60 + minute;
    const closeTotalMinutes = closeHour * 60 + closeMinute;
    const warningStart = closeTotalMinutes - warningMinutes;

    if (currentTotalMinutes < warningStart || currentTotalMinutes >= closeTotalMinutes) return;

    const notificationKey = `${today}:${closeTime}:${warningMinutes}`;
    if (lastNotificationKey === notificationKey) return;

    const users = await User.find({
      is_inside: true,
      deleted_at: null,
      device_token: { $nin: [null, ''] },
    }).select('student_id full_name device_token');

    lastNotificationKey = notificationKey;
    if (users.length === 0) return;

    let sent = 0;
    for (const user of users) {
      try {
        const result = await sendClosingSoonNotification(user, closeTime, warningMinutes);
        if (result?.success) sent++;
      } catch (error) {
        console.warn(`[ClosingNotification] Không thể gửi cho ${user.student_id}: ${error.message}`);
      }
    }

    console.log(`[ClosingNotification] Đã gửi ${sent}/${users.length} cảnh báo đóng cửa.`);
  } catch (error) {
    console.warn(`[ClosingNotification] Không thể kiểm tra giờ đóng cửa: ${error.message}`);
  } finally {
    isChecking = false;
  }
}

function startClosingNotificationScheduler() {
  checkAndSendClosingNotifications();
  const timer = setInterval(checkAndSendClosingNotifications, 60 * 1000);
  timer.unref?.();
  return timer;
}

module.exports = {
  checkAndSendClosingNotifications,
  startClosingNotificationScheduler,
};
