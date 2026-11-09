const SystemConfig = require('../models/system_config_model');
const {
  getVNTomorrowString,
  formatVNDisplayDate,
  normalizeTimeStr,
  autoPromoteOperatingHours,
} = require('../utils/operating_hours_helper');

// Bảng định nghĩa kiểu dữ liệu và mô tả chuẩn cho cấu hình hệ thống
const CONFIG_DEFINITIONS = {
  MAX_CAPACITY: {
    aliases: ['maxCapacity', 'MAX_CAPACITY'],
    dataType: 'INT',
    description: 'Sức chứa tối đa của thư viện',
    validate: (val) => Number.isInteger(Number(val)) && Number(val) > 0,
  },
  OPEN_TIME: {
    aliases: ['openTime', 'OPEN_TIME'],
    dataType: 'TIME',
    description: 'Giờ mở cửa thư viện (HH:mm)',
    validate: (val) => /^\d{1,2}:\d{2}$/.test(String(val)),
  },
  CLOSE_TIME: {
    aliases: ['closeTime', 'CLOSE_TIME'],
    dataType: 'TIME',
    description: 'Giờ đóng cửa thư viện (HH:mm)',
    validate: (val) => /^\d{1,2}:\d{2}$/.test(String(val)),
  },
  WARNING_MINUTES_BEFORE_CLOSE: {
    aliases: ['warningMinutesBeforeClose', 'WARNING_MINUTES_BEFORE_CLOSE'],
    dataType: 'INT',
    description: 'Số phút cảnh báo trước khi đóng cửa',
    validate: (val) => Number.isInteger(Number(val)) && Number(val) >= 0,
  },
  MAX_SESSION_HOURS: {
    aliases: ['maxSessionHours', 'MAX_SESSION_HOURS'],
    dataType: 'INT',
    description: 'Số giờ tối đa cho một phiên truy cập',
    validate: (val) => Number.isInteger(Number(val)) && Number(val) > 0,
  },
  ALLOWED_DAYS: {
    aliases: ['allowedDays', 'ALLOWED_DAYS'],
    dataType: 'STRING',
    description: 'Các ngày mở cửa trong tuần',
    validate: (val) => typeof val === 'string' && val.trim().length > 0,
  },
  MAINTENANCE_MODE: {
    aliases: ['maintenanceMode', 'MAINTENANCE_MODE'],
    dataType: 'BOOLEAN',
    description: 'Trạng thái bảo trì hệ thống',
    validate: (val) => typeof val === 'boolean' || val === 'true' || val === 'false',
  },
  MAINTENANCE_MESSAGE: {
    aliases: ['maintenanceMessage', 'MAINTENANCE_MESSAGE'],
    dataType: 'STRING',
    description: 'Nội dung thông báo bảo trì',
    validate: () => true,
  },
};

function buildConfigMap(rawConfigs) {
  const map = {};
  for (const c of rawConfigs) {
    map[c.config_key] = c.config_value;
  }

  const maxCap = parseInt(map['MAX_CAPACITY'] || map['maxCapacity'] || '200', 10);
  const warnMinutes = parseInt(map['WARNING_MINUTES_BEFORE_CLOSE'] || map['warningMinutesBeforeClose'] || '15', 10);
  const maxSession = parseInt(map['MAX_SESSION_HOURS'] || map['maxSessionHours'] || '8', 10);
  const openT = normalizeTimeStr(map['OPEN_TIME'] || map['openTime'] || '07:30');
  const closeT = normalizeTimeStr(map['CLOSE_TIME'] || map['closeTime'] || '21:30');
  const allowedD = String(map['ALLOWED_DAYS'] || map['allowedDays'] || '1,2,3,4,5,6');
  const maintMode = (map['MAINTENANCE_MODE'] === 'true' || map['MAINTENANCE_MODE'] === true || map['maintenanceMode'] === 'true' || map['maintenanceMode'] === true);
  const maintMsg = String(map['MAINTENANCE_MESSAGE'] || map['maintenanceMessage'] || '');

  const nextOpenT = (map['NEXT_OPEN_TIME'] || map['nextOpenTime']) ? normalizeTimeStr(map['NEXT_OPEN_TIME'] || map['nextOpenTime']) : null;
  const nextCloseT = (map['NEXT_CLOSE_TIME'] || map['nextCloseTime']) ? normalizeTimeStr(map['NEXT_CLOSE_TIME'] || map['nextCloseTime']) : null;
  const effectiveDate = map['OPERATING_HOURS_EFFECTIVE_DATE'] || map['effectiveDate'] || null;

  map['MAX_CAPACITY'] = maxCap;
  map['maxCapacity'] = maxCap;
  map['OPEN_TIME'] = openT;
  map['openTime'] = openT;
  map['CLOSE_TIME'] = closeT;
  map['closeTime'] = closeT;
  map['WARNING_MINUTES_BEFORE_CLOSE'] = warnMinutes;
  map['warningMinutesBeforeClose'] = warnMinutes;
  map['MAX_SESSION_HOURS'] = maxSession;
  map['maxSessionHours'] = maxSession;
  map['ALLOWED_DAYS'] = allowedD;
  map['allowedDays'] = allowedD;
  map['MAINTENANCE_MODE'] = maintMode;
  map['maintenanceMode'] = maintMode;
  map['MAINTENANCE_MESSAGE'] = maintMsg;
  map['maintenanceMessage'] = maintMsg;

  if (nextOpenT && nextCloseT && effectiveDate) {
    map['NEXT_OPEN_TIME'] = nextOpenT;
    map['nextOpenTime'] = nextOpenT;
    map['NEXT_CLOSE_TIME'] = nextCloseT;
    map['nextCloseTime'] = nextCloseT;
    map['OPERATING_HOURS_EFFECTIVE_DATE'] = effectiveDate;
    map['effectiveDate'] = effectiveDate;
    map['hasPendingOperatingHours'] = true;
  } else {
    map['hasPendingOperatingHours'] = false;
  }

  return map;
}

// GET /api/config — Đọc cấu hình hệ thống
async function getConfigs(req, res, next) {
  try {
    let rawConfigs = await SystemConfig.find();
    let configMap = buildConfigMap(rawConfigs);
    const didPromote = await autoPromoteOperatingHours(configMap);
    if (didPromote) {
      rawConfigs = await SystemConfig.find();
      configMap = buildConfigMap(rawConfigs);
    }

    const items = rawConfigs.map((c) => ({
      configKey: c.config_key,
      configValue: c.config_value,
      dataType: c.data_type,
      description: c.description,
      updatedAt: c.updated_at,
    }));

    res.json({
      success: true,
      data: configMap,
      items,
    });
  } catch (err) {
    next(err);
  }
}

// PUT /api/admin/config — Cập nhật cấu hình hệ thống (chỉ ADMIN)
async function updateConfigs(req, res, next) {
  try {
    const body = req.body || {};
    const updates = [];
    const errors = [];

    // Lấy config hiện tại để đối chiếu
    let rawConfigs = await SystemConfig.find();
    let currentConfigMap = buildConfigMap(rawConfigs);
    await autoPromoteOperatingHours(currentConfigMap);

    const currentOpen = currentConfigMap.openTime;
    const currentClose = currentConfigMap.closeTime;

    // 1. Xử lý riêng giờ mở/đóng cửa theo nghiệp vụ chuyển giao ngày hôm sau
    let incomingOpen = undefined;
    for (const alias of CONFIG_DEFINITIONS.OPEN_TIME.aliases) {
      if (body[alias] !== undefined) {
        incomingOpen = body[alias];
        break;
      }
    }

    let incomingClose = undefined;
    for (const alias of CONFIG_DEFINITIONS.CLOSE_TIME.aliases) {
      if (body[alias] !== undefined) {
        incomingClose = body[alias];
        break;
      }
    }

    let hoursNotice = null;

    if (incomingOpen !== undefined || incomingClose !== undefined) {
      if (incomingOpen !== undefined && !CONFIG_DEFINITIONS.OPEN_TIME.validate(incomingOpen)) {
        errors.push(`Giờ mở cửa không hợp lệ: ${incomingOpen}`);
      }
      if (incomingClose !== undefined && !CONFIG_DEFINITIONS.CLOSE_TIME.validate(incomingClose)) {
        errors.push(`Giờ đóng cửa không hợp lệ: ${incomingClose}`);
      }

      if (errors.length === 0) {
        const targetOpen = incomingOpen !== undefined ? normalizeTimeStr(incomingOpen) : currentOpen;
        const targetClose = incomingClose !== undefined ? normalizeTimeStr(incomingClose) : currentClose;

        const [oH, oM] = targetOpen.split(':').map(Number);
        const [cH, cM] = targetClose.split(':').map(Number);
        if (oH * 60 + oM >= cH * 60 + cM) {
          errors.push('Giờ mở cửa phải trước giờ đóng cửa');
        } else {
          // Kiểm tra xem giờ mới có khác với giờ đang áp dụng của hôm nay hay không
          const isDifferentFromActive = targetOpen !== currentOpen || targetClose !== currentClose;

          if (isDifferentFromActive) {
            // Lên lịch áp dụng cho ngày hôm sau
            const tomorrowVN = getVNTomorrowString();
            updates.push(
              SystemConfig.findOneAndUpdate(
                { config_key: 'NEXT_OPEN_TIME' },
                {
                  config_key: 'NEXT_OPEN_TIME',
                  config_value: targetOpen,
                  data_type: 'TIME',
                  description: 'Giờ mở cửa dự kiến áp dụng ngày mai',
                  updated_at: new Date(),
                },
                { upsert: true, new: true }
              ),
              SystemConfig.findOneAndUpdate(
                { config_key: 'nextOpenTime' },
                {
                  config_key: 'nextOpenTime',
                  config_value: targetOpen,
                  data_type: 'TIME',
                  description: 'Alias nextOpenTime',
                  updated_at: new Date(),
                },
                { upsert: true }
              ),
              SystemConfig.findOneAndUpdate(
                { config_key: 'NEXT_CLOSE_TIME' },
                {
                  config_key: 'NEXT_CLOSE_TIME',
                  config_value: targetClose,
                  data_type: 'TIME',
                  description: 'Giờ đóng cửa dự kiến áp dụng ngày mai',
                  updated_at: new Date(),
                },
                { upsert: true, new: true }
              ),
              SystemConfig.findOneAndUpdate(
                { config_key: 'nextCloseTime' },
                {
                  config_key: 'nextCloseTime',
                  config_value: targetClose,
                  data_type: 'TIME',
                  description: 'Alias nextCloseTime',
                  updated_at: new Date(),
                },
                { upsert: true }
              ),
              SystemConfig.findOneAndUpdate(
                { config_key: 'OPERATING_HOURS_EFFECTIVE_DATE' },
                {
                  config_key: 'OPERATING_HOURS_EFFECTIVE_DATE',
                  config_value: tomorrowVN,
                  data_type: 'STRING',
                  description: 'Ngày giờ hoạt động mới bắt đầu có hiệu lực',
                  updated_at: new Date(),
                },
                { upsert: true, new: true }
              ),
              SystemConfig.findOneAndUpdate(
                { config_key: 'effectiveDate' },
                {
                  config_key: 'effectiveDate',
                  config_value: tomorrowVN,
                  data_type: 'STRING',
                  description: 'Alias effectiveDate',
                  updated_at: new Date(),
                },
                { upsert: true }
              )
            );
            hoursNotice = `Giờ mở/đóng cửa mới (${targetOpen} – ${targetClose}) sẽ có hiệu lực từ ngày mai (${formatVNDisplayDate(tomorrowVN)}). Hôm nay thư viện vẫn giữ nguyên khung giờ hiện tại (${currentOpen} – ${currentClose}).`;
          } else {
            // Nếu người dùng chọn lại giờ trùng với hôm nay và trước đó có lịch hẹn -> hủy lịch hẹn
            if (currentConfigMap.hasPendingOperatingHours) {
              updates.push(
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
                })
              );
              hoursNotice = `Đã hủy lịch thay đổi giờ hoạt động ngày mai. Hệ thống tiếp tục áp dụng khung giờ ${currentOpen} – ${currentClose}.`;
            }
          }
        }
      }
    }

    // 2. Cập nhật các cấu hình thông số vận hành khác (MAX_CAPACITY, MAINTENANCE...)
    for (const [normKey, meta] of Object.entries(CONFIG_DEFINITIONS)) {
      if (normKey === 'OPEN_TIME' || normKey === 'CLOSE_TIME') {
        continue; // Đã xử lý ở trên
      }

      let incomingValue = undefined;
      for (const alias of meta.aliases) {
        if (body[alias] !== undefined) {
          incomingValue = body[alias];
          break;
        }
      }

      if (incomingValue !== undefined) {
        if (!meta.validate(incomingValue)) {
          errors.push(`Giá trị cấu hình không hợp lệ cho '${normKey}': ${incomingValue}`);
          continue;
        }

        const stringValue = String(incomingValue);

        updates.push(
          SystemConfig.findOneAndUpdate(
            { config_key: normKey },
            {
              config_key: normKey,
              config_value: stringValue,
              data_type: meta.dataType,
              description: meta.description,
              updated_at: new Date(),
            },
            { upsert: true, new: true }
          )
        );

        const camelAlias = meta.aliases.find((a) => a !== normKey);
        if (camelAlias) {
          updates.push(
            SystemConfig.findOneAndUpdate(
              { config_key: camelAlias },
              {
                config_key: camelAlias,
                config_value: stringValue,
                data_type: meta.dataType,
                description: `Alias ${camelAlias}`,
                updated_at: new Date(),
              },
              { upsert: true }
            )
          );
        }
      }
    }

    if (errors.length > 0) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_CONFIG_INPUT',
        message: errors.join('; '),
      });
    }

    if (updates.length === 0) {
      // Trường hợp admin gửi lại y nguyên config không đổi
      const allConfigs = await SystemConfig.find();
      const resultConfigMap = buildConfigMap(allConfigs);
      return res.json({
        success: true,
        message: 'Không có thay đổi cấu hình nào được ghi nhận',
        data: resultConfigMap,
      });
    }

    await Promise.all(updates);

    // Lấy danh sách cấu hình mới nhất để trả về cho client
    const allConfigs = await SystemConfig.find();
    const resultConfigMap = buildConfigMap(allConfigs);

    res.json({
      success: true,
      message: hoursNotice || 'Cấu hình hệ thống đã được cập nhật thành công',
      data: resultConfigMap,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { getConfigs, updateConfigs };
