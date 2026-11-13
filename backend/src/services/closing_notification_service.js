const User = require('../models/user_model');
const CheckInLog = require('../models/check_in_log_model');
const SystemConfig = require('../models/system_config_model');
const {
  sendClosingSoonNotification,
  sendAutoCheckOutNotification,
} = require('./fcm_service');
const {
  autoPromoteOperatingHours,
  getVNDateString,
  getVNTimeParts,
  resolveOperatingHoursForDate,
} = require('../utils/operating_hours_helper');

let lastNotificationKey = null;
let isChecking = false;

function getVNClosingDate(date, closeTime) {
  const dateStr = getVNDateString(date);
  return new Date(`${dateStr}T${closeTime}:00+07:00`);
}

async function autoCheckOutAtClosing(closeTime, now) {
  const closingTime = getVNClosingDate(now, closeTime);
  const users = await User.find({
    is_inside: true,
    deleted_at: null,
  });

  let checkedOut = 0;
  for (const user of users) {
    const activeLog = await CheckInLog.findOne({
      user_id: user._id,
      status: 'INSIDE',
      check_out_time: null,
    }).sort({ check_in_time: -1 });

    const checkOutTime = activeLog && closingTime > activeLog.check_in_time
      ? closingTime
      : now;

    if (activeLog) {
      activeLog.check_out_time = checkOutTime;
      activeLog.status = 'COMPLETED';
      activeLog.action_type = 'CHECK_OUT';
      await activeLog.save();
    }

    user.is_inside = false;
    await user.save();
    checkedOut++;

    try {
      await sendAutoCheckOutNotification(user, activeLog);
    } catch (error) {
      console.warn(`[FCM] Không thể gửi thông báo tự động check-out cho ${user.student_id}: ${error.message}`);
    }
  }

  if (checkedOut > 0) {
    console.log(`[ClosingNotification] Đã tự động check-out ${checkedOut} sinh viên lúc ${closeTime}.`);
  }
}

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
    const effectiveWarningMinutes = Number.isFinite(warningMinutes) && warningMinutes > 0
      ? warningMinutes
      : 0;

    const [closeHour, closeMinute] = closeTime.split(':').map(Number);
    const currentTotalMinutes = hour * 60 + minute;
    const closeTotalMinutes = closeHour * 60 + closeMinute;

    if (currentTotalMinutes >= closeTotalMinutes) {
      await autoCheckOutAtClosing(closeTime, new Date());
      return;
    }

    if (effectiveWarningMinutes <= 0) return;
    const warningStart = closeTotalMinutes - effectiveWarningMinutes;
    if (currentTotalMinutes < warningStart) return;

    const notificationKey = `${today}:${closeTime}:${effectiveWarningMinutes}`;
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
        const result = await sendClosingSoonNotification(user, closeTime, effectiveWarningMinutes);
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
