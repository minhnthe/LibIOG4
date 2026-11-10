const SystemConfig = require('../models/system_config_model');

/**
 * Lấy chuỗi ngày YYYY-MM-DD theo múi giờ Việt Nam (+07:00 ICT)
 * @param {Date|string|number} date
 * @returns {string} 'YYYY-MM-DD'
 */
function getVNDateString(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date);
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(d);
}

/**
 * Lấy chuỗi ngày YYYY-MM-DD của ngày hôm sau theo múi giờ Việt Nam
 * @param {Date|string|number} date
 * @returns {string} 'YYYY-MM-DD'
 */
function getVNTomorrowString(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date);
  const tomorrow = new Date(d.getTime() + 24 * 60 * 60 * 1000);
  return getVNDateString(tomorrow);
}

/**
 * Định dạng chuỗi ngày YYYY-MM-DD sang định dạng hiển thị thân thiện DD/MM/YYYY
 * @param {string} dateStr 'YYYY-MM-DD'
 * @returns {string} 'DD/MM/YYYY'
 */
function formatVNDisplayDate(dateStr) {
  if (!dateStr || typeof dateStr !== 'string') return '';
  const parts = dateStr.split('-');
  if (parts.length === 3) {
    return `${parts[2]}/${parts[1]}/${parts[0]}`;
  }
  return dateStr;
}

/**
 * Chuẩn hóa chuỗi thời gian HH:mm (ví dụ "7:30" -> "07:30")
 * @param {string} timeStr
 * @returns {string}
 */
function normalizeTimeStr(timeStr) {
  if (!timeStr) return '07:30';
  const parts = String(timeStr).trim().split(':');
  const h = parts[0] ? parts[0].padStart(2, '0') : '07';
  const m = parts[1] ? parts[1].padStart(2, '0') : '00';
  return `${h}:${m}`;
}

/**
 * Tự động chuyển giao (auto-promote) giờ mở/đóng cửa mới vào cấu hình chính thức
 * khi ngày hôm nay (múi giờ VN) đã đến hoặc vượt qua ngày bắt đầu có hiệu lực.
 *
 * @param {Object} configMap - Map cấu hình hiện tại
 * @returns {Promise<boolean>} true nếu có sự chuyển giao diễn ra
 */
async function autoPromoteOperatingHours(configMap) {
  const nextOpen = configMap['NEXT_OPEN_TIME'] || configMap['nextOpenTime'];
  const nextClose = configMap['NEXT_CLOSE_TIME'] || configMap['nextCloseTime'];
  const effectiveDate = configMap['OPERATING_HOURS_EFFECTIVE_DATE'] || configMap['effectiveDate'];

  if (!nextOpen || !nextClose || !effectiveDate) {
    return false;
  }

  const todayVN = getVNDateString();

  // Kiểm tra nếu hôm nay đã đến hoặc vượt quá ngày bắt đầu có hiệu lực
  if (todayVN >= effectiveDate) {
    const prevOpen = configMap['OPEN_TIME'] || configMap['openTime'] || '07:30';
    const prevClose = configMap['CLOSE_TIME'] || configMap['closeTime'] || '21:30';

    try {
      await Promise.all([
        SystemConfig.findOneAndUpdate(
          { config_key: 'OPEN_TIME' },
          { config_key: 'OPEN_TIME', config_value: nextOpen, data_type: 'TIME', updated_at: new Date() },
          { upsert: true }
        ),
        SystemConfig.findOneAndUpdate(
          { config_key: 'openTime' },
          { config_key: 'openTime', config_value: nextOpen, data_type: 'TIME', updated_at: new Date() },
          { upsert: true }
        ),
        SystemConfig.findOneAndUpdate(
          { config_key: 'CLOSE_TIME' },
          { config_key: 'CLOSE_TIME', config_value: nextClose, data_type: 'TIME', updated_at: new Date() },
          { upsert: true }
        ),
        SystemConfig.findOneAndUpdate(
          { config_key: 'closeTime' },
          { config_key: 'closeTime', config_value: nextClose, data_type: 'TIME', updated_at: new Date() },
          { upsert: true }
        ),
        SystemConfig.findOneAndUpdate(
          { config_key: 'PREVIOUS_OPEN_TIME' },
          { config_key: 'PREVIOUS_OPEN_TIME', config_value: prevOpen, data_type: 'TIME', updated_at: new Date() },
          { upsert: true }
        ),
        SystemConfig.findOneAndUpdate(
          { config_key: 'PREVIOUS_CLOSE_TIME' },
          { config_key: 'PREVIOUS_CLOSE_TIME', config_value: prevClose, data_type: 'TIME', updated_at: new Date() },
          { upsert: true }
        ),
        SystemConfig.findOneAndUpdate(
          { config_key: 'LAST_HOURS_CHANGED_DATE' },
          { config_key: 'LAST_HOURS_CHANGED_DATE', config_value: effectiveDate, data_type: 'STRING', updated_at: new Date() },
          { upsert: true }
        ),
        SystemConfig.deleteMany({
          config_key: {
            $in: [
              'NEXT_OPEN_TIME',
              'nextOpenTime',
              'NEXT_CLOSE_TIME',
              'nextCloseTime',
              'OPERATING_HOURS_EFFECTIVE_DATE',
              'effectiveDate',
            ],
          },
        }),
      ]);
    } catch (e) {
      console.warn('[OperatingHoursHelper] Error updating database during auto-promotion:', e.message);
    }

    // Cập nhật map in-memory
    configMap['OPEN_TIME'] = nextOpen;
    configMap['openTime'] = nextOpen;
    configMap['CLOSE_TIME'] = nextClose;
    configMap['closeTime'] = nextClose;
    configMap['PREVIOUS_OPEN_TIME'] = prevOpen;
    configMap['PREVIOUS_CLOSE_TIME'] = prevClose;
    configMap['LAST_HOURS_CHANGED_DATE'] = effectiveDate;

    delete configMap['NEXT_OPEN_TIME'];
    delete configMap['nextOpenTime'];
    delete configMap['NEXT_CLOSE_TIME'];
    delete configMap['nextCloseTime'];
    delete configMap['OPERATING_HOURS_EFFECTIVE_DATE'];
    delete configMap['effectiveDate'];

    return true;
  }

  return false;
}

/**
 * Phân giải giờ mở và đóng cửa áp dụng cho một ngày truy vấn cụ thể (targetDate)
 *
 * @param {Object} configMap - Map cấu hình
 * @param {Date|string|number} targetDate - Ngày cần tính giờ hoạt động
 * @returns {{ openTime: string, closeTime: string, isPending: boolean, effectiveDate?: string, isHistorical?: boolean }}
 */
function resolveOperatingHoursForDate(configMap, targetDate = new Date()) {
  const targetDateStr = getVNDateString(targetDate);
  const nextOpen = configMap['NEXT_OPEN_TIME'] || configMap['nextOpenTime'];
  const nextClose = configMap['NEXT_CLOSE_TIME'] || configMap['nextCloseTime'];
  const effectiveDate = configMap['OPERATING_HOURS_EFFECTIVE_DATE'] || configMap['effectiveDate'];

  // 1. Nếu có lịch đổi giờ trong tương lai và ngày truy vấn >= ngày có hiệu lực
  if (nextOpen && nextClose && effectiveDate) {
    if (targetDateStr >= effectiveDate) {
      return {
        openTime: normalizeTimeStr(nextOpen),
        closeTime: normalizeTimeStr(nextClose),
        isPending: false,
        effectiveDate,
      };
    }
  }

  // 2. Nếu tra cứu ngày trong quá khứ trước mốc đổi giờ gần nhất
  const lastChangedDate = configMap['LAST_HOURS_CHANGED_DATE'];
  const prevOpen = configMap['PREVIOUS_OPEN_TIME'];
  const prevClose = configMap['PREVIOUS_CLOSE_TIME'];
  if (lastChangedDate && prevOpen && prevClose && targetDateStr < lastChangedDate) {
    return {
      openTime: normalizeTimeStr(prevOpen),
      closeTime: normalizeTimeStr(prevClose),
      isHistorical: true,
      lastChangedDate,
    };
  }

  // 3. Mặc định dùng giờ đang có hiệu lực hiện tại
  const openTime = normalizeTimeStr(configMap['OPEN_TIME'] || configMap['openTime'] || '07:30');
  const closeTime = normalizeTimeStr(configMap['CLOSE_TIME'] || configMap['closeTime'] || '21:30');

  return {
    openTime,
    closeTime,
    isPending: Boolean(nextOpen && nextClose && effectiveDate),
    nextOpenTime: nextOpen ? normalizeTimeStr(nextOpen) : undefined,
    nextCloseTime: nextClose ? normalizeTimeStr(nextClose) : undefined,
    effectiveDate: effectiveDate || undefined,
  };
}

/**
 * Lấy các phần tử giờ, phút, giây và thứ theo múi giờ Việt Nam (Asia/Ho_Chi_Minh)
 * @param {Date|string|number} date
 * @returns {{ hour: number, minute: number, second: number, weekday: string }}
 */
function getVNTimeParts(date = new Date()) {
  const d = date instanceof Date ? date : new Date(date);
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Ho_Chi_Minh',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    hourCycle: 'h23',
    weekday: 'short',
  });
  const parts = formatter.formatToParts(d);
  const map = {};
  for (const p of parts) {
    map[p.type] = p.value;
  }
  return {
    hour: parseInt(map.hour || '0', 10),
    minute: parseInt(map.minute || '0', 10),
    second: parseInt(map.second || '0', 10),
    weekday: map.weekday, // 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  };
}

module.exports = {
  getVNDateString,
  getVNTomorrowString,
  getVNTimeParts,
  formatVNDisplayDate,
  normalizeTimeStr,
  autoPromoteOperatingHours,
  resolveOperatingHoursForDate,
};
