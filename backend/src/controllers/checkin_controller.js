const mongoose = require('mongoose');
const CheckInLog = require('../models/check_in_log_model');
const User = require('../models/user_model');
const LibraryCard = require('../models/library_card_model');
const Gate = require('../models/gate_model');
const SystemConfig = require('../models/system_config_model');
const { sendCheckInNotification } = require('../services/fcm_service');
const {
  autoPromoteOperatingHours,
  resolveOperatingHoursForDate,
} = require('../utils/operating_hours_helper');

/** Lấy config dạng object { key: value } hỗ trợ cả UPPER_SNAKE và camelCase */
async function getConfigMap() {
  const configs = await SystemConfig.find();
  const rawMap = configs.reduce((acc, c) => {
    acc[c.config_key] = c.config_value;
    if (c.key) acc[c.key] = c.value;
    return acc;
  }, {});
  await autoPromoteOperatingHours(rawMap);
  return rawMap;
}

/** Lấy cổng hợp lệ (mặc định lấy Cổng chính) */
async function getDefaultGate(deviceId) {
  if (deviceId) {
    const gateByName = await Gate.findOne({ gate_name: deviceId });
    if (gateByName) return gateByName;
  }
  let gate = await Gate.findOne({ status: 'ACTIVE' });
  if (!gate) {
    gate = await Gate.create({
      gate_name: 'Cổng chính',
      location: 'Sảnh chính - Tầng 1 Nhà Thư Viện',
      status: 'ACTIVE',
    });
  }
  return gate;
}

/** Kiểm tra điều kiện trước khi sinh viên check-in */
async function validateCheckIn(user, card, config) {
  // 1. Kiểm tra trạng thái tài khoản & thẻ
  if (user.status === 'BLOCKED' || user.status === 'locked') {
    return { ok: false, errorCode: 'ACCOUNT_LOCKED', message: 'Tài khoản đã bị khóa. Vui lòng liên hệ thủ thư' };
  }
  if (!card) {
    return { ok: false, errorCode: 'CARD_NOT_FOUND', message: 'Không tìm thấy thẻ thư viện của sinh viên' };
  }
  if (card.status === 'LOCKED') {
    return { ok: false, errorCode: 'CARD_LOCKED', message: 'Thẻ thư viện đang bị khóa' };
  }
  if (card.status === 'EXPIRED' || card.isExpired()) {
    return { ok: false, errorCode: 'CARD_EXPIRED', message: 'Thẻ thư viện đã hết hạn' };
  }

  // 2. Chế độ bảo trì
  const isMaintenance = config.MAINTENANCE_MODE === 'true' || config.maintenanceMode === 'true';
  if (isMaintenance) {
    return {
      ok: false,
      errorCode: 'LIBRARY_CLOSED',
      message: config.MAINTENANCE_MESSAGE || config.maintenanceMessage || 'Thư viện tạm ngừng hoạt động để bảo trì',
    };
  }

  // 3. Giờ mở cửa có hiệu lực của ngày hôm nay
  const now = new Date();
  const { openTime: openTimeStr, closeTime: closeTimeStr } = resolveOperatingHoursForDate(config, now);
  const [openH, openM] = openTimeStr.split(':').map(Number);
  const [closeH, closeM] = closeTimeStr.split(':').map(Number);
  const todayOpen = new Date(now); todayOpen.setHours(openH, openM, 0, 0);
  const todayClose = new Date(now); todayClose.setHours(closeH, closeM, 0, 0);
  if (now < todayOpen || now > todayClose) {
    return { ok: false, errorCode: 'LIBRARY_CLOSED', message: `Thư viện chỉ mở cửa ${openTimeStr} – ${closeTimeStr}` };
  }

  // 4. Ngày mở cửa trong tuần
  const dayMap = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const allowedDaysStr = config.ALLOWED_DAYS || config.allowedDays || 'Mon,Tue,Wed,Thu,Fri,Sat';
  const allowedDays = allowedDaysStr.split(',').map((d) => d.trim());
  if (!allowedDays.includes(dayMap[now.getDay()])) {
    return { ok: false, errorCode: 'LIBRARY_CLOSED', message: 'Thư viện không mở cửa ngày hôm nay' };
  }

  // 5. Kiểm tra sức chứa
  const currentOccupancy = await User.countDocuments({ is_inside: true, deleted_at: null });
  const maxCapacity = parseInt(config.MAX_CAPACITY || config.maxCapacity || '200', 10);
  if (currentOccupancy >= maxCapacity) {
    return { ok: false, errorCode: 'CAPACITY_EXCEEDED', message: `Thư viện đã đầy (${currentOccupancy}/${maxCapacity})` };
  }

  return { ok: true, currentOccupancy, maxCapacity };
}

// POST /api/checkin
async function checkIn(req, res, next) {
  try {
    const { qrPayload, deviceId } = req.body;

    if (!qrPayload) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_INPUT',
        message: 'qrPayload hoặc mã sinh viên bắt buộc',
      });
    }

    let user = null;
    let card = null;
    let expireEpochStr = null;
    const rawInput = qrPayload.trim();

    if (rawInput.startsWith('LIB:')) {
      // Định dạng QR chuẩn: LIB:{student_id}:{card_id}:{expireEpoch}
      const parts = rawInput.split(':');
      if (parts.length < 4) {
        return res.status(400).json({ success: false, errorCode: 'INVALID_QR', message: 'Mã QR không đúng định dạng' });
      }

      let studentId, cardOrUserId;
      [, studentId, cardOrUserId, expireEpochStr] = parts;

      // 1. Tìm thẻ thư viện theo ID hoặc User ID
      if (mongoose.Types.ObjectId.isValid(cardOrUserId)) {
        card = await LibraryCard.findById(cardOrUserId);
        if (!card) {
          card = await LibraryCard.findOne({ user_id: cardOrUserId });
        }
      }

      // 2. Tìm người dùng
      if (card) {
        user = await User.findOne({ _id: card.user_id, deleted_at: null });
      }
      if (!user) {
        user = await User.findOne({ student_id: studentId, deleted_at: null });
      }

      if (!user) {
        return res.status(404).json({ success: false, errorCode: 'USER_NOT_FOUND', message: 'Không tìm thấy sinh viên' });
      }

      // Nếu chưa có card thì lấy theo user._id
      if (!card) {
        card = await LibraryCard.findOne({ user_id: user._id });
      }
    } else {
      // Nhập tay mã sinh viên dự phòng
      user = await User.findOne({
        student_id: { $regex: new RegExp(`^${rawInput}$`, 'i') },
        deleted_at: null,
      });

      if (!user) {
        return res.status(404).json({
          success: false,
          errorCode: 'USER_NOT_FOUND',
          message: `Không tìm thấy sinh viên có mã: ${rawInput}`,
        });
      }

      card = await LibraryCard.findOne({ user_id: user._id });
    }

    const config = await getConfigMap();
    const gate = await getDefaultGate(deviceId);

    // ── XỬ LÝ ĐÓNG PHIÊN CŨ QUA ĐÊM (NẾU QUÊN CHECK-OUT) ──
    if (user.is_inside) {
      const activeLog = await CheckInLog.findOne({
        user_id: user._id,
        status: 'INSIDE',
        check_out_time: null,
      }).sort({ check_in_time: -1 });

      const now = new Date();
      if (activeLog && activeLog.check_in_time.toDateString() !== now.toDateString()) {
        const { closeTime: activeCloseTime } = resolveOperatingHoursForDate(config, activeLog.check_in_time);
        const [closeH, closeM] = activeCloseTime.split(':').map(Number);
        const autoClose = new Date(activeLog.check_in_time);
        autoClose.setHours(closeH, closeM, 0, 0);

        activeLog.check_out_time = autoClose > activeLog.check_in_time
          ? autoClose
          : new Date(activeLog.check_in_time.getTime() + 4 * 60 * 60 * 1000);
        activeLog.status = 'COMPLETED';
        activeLog.action_type = 'CHECK_OUT';
        await activeLog.save();

        user.is_inside = false;
        await user.save();
      }
    }

    // ── NẾU ĐANG Ở TRONG THƯ VIỆN (is_inside = true) -> TIẾN HÀNH CHECK-OUT ──
    // QUY TẮC ĐẶC BIỆT: Tài khoản bị khóa (BLOCKED) hoặc thẻ hết hạn/khóa vẫn ĐƯỢC PHÉP CHECK-OUT để ra ngoài!
    if (user.is_inside) {
      const activeLog = await CheckInLog.findOne({
        user_id: user._id,
        status: 'INSIDE',
        check_out_time: null,
      }).sort({ check_in_time: -1 });

      const checkOutTime = new Date();
      if (activeLog) {
        activeLog.check_out_time = checkOutTime;
        activeLog.action_type = 'CHECK_OUT';
        activeLog.status = 'COMPLETED';
        activeLog.total_minutes = Math.max(1, Math.round((checkOutTime - activeLog.check_in_time) / 60000));
        await activeLog.save();
      }

      user.is_inside = false;
      await user.save();

      // Bắn push notification check-out qua FCM (non-blocking)
      if (activeLog) {
        sendCheckInNotification(user, activeLog).catch((e) =>
          console.warn('[FCM] Push error:', e.message)
        );
      }

      const currentOccupancy = await User.countDocuments({ is_inside: true, deleted_at: null });
      const maxCapacity = parseInt(config.MAX_CAPACITY || config.maxCapacity || '200', 10);

      return res.json({
        success: true,
        data: {
          logId: activeLog?._id,
          userId: user._id,
          studentId: user.student_id,
          studentName: user.full_name,
          type: 'check_out',
          checkInTime: activeLog?.check_in_time,
          checkOutTime,
          durationMinutes: activeLog?.total_minutes || 0,
          currentOccupancy,
          maxCapacity,
        },
      });
    }

    // ── NẾU ĐANG Ở NGOÀI (is_inside = false) -> TIẾN HÀNH CHECK-IN ──
    // 0. Kiểm tra hạn sử dụng của mã QR động (rolling token 60s)
    if (expireEpochStr) {
      const expireEpoch = parseInt(expireEpochStr, 10);
      if (!isNaN(expireEpoch) && expireEpoch < Math.floor(Date.now() / 1000)) {
        return res.status(422).json({
          success: false,
          errorCode: 'QR_EXPIRED',
          message: 'Mã QR đã hết hạn. Vui lòng làm mới mã trên ứng dụng',
        });
      }
    }

    // Kiểm tra tất cả điều kiện: trạng thái thẻ, trạng thái user, bảo trì, giờ mở cửa, sức chứa
    const validation = await validateCheckIn(user, card, config);
    if (!validation.ok) {
      return res.status(422).json({
        success: false,
        errorCode: validation.errorCode,
        message: validation.message,
      });
    }

    const checkInTime = new Date();
    const log = await CheckInLog.create({
      user_id: user._id,
      card_id: card ? card._id : null,
      gate_id: gate._id,
      check_in_time: checkInTime,
      action_type: 'CHECK_IN',
      status: 'INSIDE',
      sync_status: 'SYNCED',
    });

    user.is_inside = true;
    user.last_check_in = checkInTime;
    await user.save();

    // Bắn push notification check-in qua FCM (non-blocking)
    sendCheckInNotification(user, log).catch((e) =>
      console.warn('[FCM] Push error:', e.message)
    );

    return res.json({
      success: true,
      data: {
        logId: log._id,
        userId: user._id,
        studentId: user.student_id,
        studentName: user.full_name,
        type: 'check_in',
        checkInTime,
        currentOccupancy: validation.currentOccupancy + 1,
        maxCapacity: validation.maxCapacity,
      },
    });
  } catch (err) {
    next(err);
  }
}

// POST /api/checkin/sync — Đồng bộ log offline từ thiết bị trạm quét
async function syncLogs(req, res, next) {
  try {
    const { logs } = req.body;
    if (!Array.isArray(logs)) {
      return res.status(400).json({ success: false, errorCode: 'INVALID_INPUT', message: 'logs phải là mảng' });
    }

    const defaultGate = await getDefaultGate();
    const synced = [];
    const failed = [];

    for (const log of logs) {
      try {
        const localId = log.localId || log.local_id || '';
        const rawTime = log.checkInTime || log.check_in_time;
        const studentId = log.studentId || log.student_id;
        const rawPayload = (log.qrPayload || studentId || '').trim();

        if (!rawPayload) {
          failed.push({ localId, reason: 'Thiếu studentId hoặc qrPayload' });
          continue;
        }

        let user = null;
        let card = null;

        if (rawPayload.startsWith('LIB:')) {
          const parts = rawPayload.split(':');
          const [, sId, cardOrUserId] = parts;
          if (mongoose.Types.ObjectId.isValid(cardOrUserId)) {
            card = await LibraryCard.findById(cardOrUserId);
          }
          if (card) {
            user = await User.findById(card.user_id);
          }
          if (!user) {
            user = await User.findOne({ student_id: sId, deleted_at: null });
          }
        } else {
          user = await User.findOne({ student_id: rawPayload, deleted_at: null });
        }

        if (!user) {
          failed.push({ localId, reason: 'User không tồn tại' });
          continue;
        }

        if (!card) {
          card = await LibraryCard.findOne({ user_id: user._id });
        }

        // Chống trùng lặp theo localId
        if (localId) {
          const duplicate = await CheckInLog.findOne({ local_id: localId });
          if (duplicate) {
            synced.push({ localId, serverId: duplicate._id, status: 'already_synced' });
            continue;
          }
        }

        const checkInTime = rawTime ? new Date(rawTime) : new Date();
        const rawOutTime = log.checkOutTime || log.check_out_time;
        const checkOutTime = rawOutTime ? new Date(rawOutTime) : null;
        let totalMinutes = null;
        if (checkOutTime && !isNaN(checkOutTime.getTime())) {
          totalMinutes = Math.max(1, Math.round((checkOutTime - checkInTime) / 60000));
        }

        const actionType = log.actionType || log.action_type || (checkOutTime ? 'CHECK_OUT' : 'CHECK_IN');

        const newLog = await CheckInLog.create({
          user_id: user._id,
          card_id: card ? card._id : null,
          gate_id: defaultGate ? defaultGate._id : null,
          check_in_time: isNaN(checkInTime.getTime()) ? new Date() : checkInTime,
          check_out_time: checkOutTime,
          total_minutes: totalMinutes,
          action_type: actionType,
          status: checkOutTime ? 'COMPLETED' : 'INSIDE',
          sync_status: 'SYNCED',
          local_id: localId,
        });

        synced.push({ localId, serverId: newLog._id, status: 'success' });
      } catch (e) {
        failed.push({ localId: log.localId || log.local_id, reason: e.message });
      }
    }

    res.json({ success: true, data: { synced, failed } });
  } catch (err) {
    next(err);
  }
}

// GET /api/checkin/current-status — Xem trạng thái có mặt hiện tại của chính mình
async function currentStatus(req, res, next) {
  try {
    const user = req.user;
    if (!user.is_inside && !user.isInsideLibrary) {
      return res.json({ success: true, data: { isInsideLibrary: false, isInside: false } });
    }

    const activeLog = await CheckInLog.findOne({
      user_id: user._id,
      status: 'INSIDE',
      check_out_time: null,
    }).sort({ check_in_time: -1 });

    const durationMinutes = activeLog
      ? Math.max(1, Math.round((Date.now() - activeLog.check_in_time) / 60000))
      : 0;

    res.json({
      success: true,
      data: {
        isInsideLibrary: true,
        isInside: true,
        checkInTime: activeLog?.check_in_time,
        durationMinutes,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/history/me — Lịch sử vào ra của cá nhân
async function getMyHistory(req, res, next) {
  try {
    const { limit = 20, page = 1 } = req.query;
    const total = await CheckInLog.countDocuments({ user_id: req.user._id });
    const logs = await CheckInLog.find({ user_id: req.user._id })
      .populate('gate_id')
      .sort({ check_in_time: -1 })
      .skip((page - 1) * Number(limit))
      .limit(Number(limit));

    const formatted = logs.map((l) => ({
      id: l._id,
      logId: l._id,
      userId: l.user_id,
      checkInTime: l.check_in_time,
      checkOutTime: l.check_out_time,
      durationMinutes: l.total_minutes,
      actionType: l.action_type,
      status: l.status,
      gateName: l.gate_id?.gate_name || 'Cổng chính',
    }));

    res.json({
      success: true,
      data: formatted,
      pagination: {
        total,
        page: Number(page),
        limit: Number(limit),
      },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { checkIn, syncLogs, currentStatus, getMyHistory };
