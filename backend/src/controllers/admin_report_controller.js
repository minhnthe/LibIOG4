const CheckInLog = require('../models/check_in_log_model');
const User = require('../models/user_model');
const SystemConfig = require('../models/system_config_model');
const { sendForceCheckOutNotification } = require('../services/fcm_service');
const {
  autoPromoteOperatingHours,
  resolveOperatingHoursForDate,
} = require('../utils/operating_hours_helper');

/**
 * Lấy khoảng thời gian bắt đầu và kết thúc của một ngày theo múi giờ Việt Nam (UTC+7)
 */
function getVNDayBounds(date = new Date()) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const [year, month, day] = formatter.format(date).split('-').map(Number);
  const start = new Date(`${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T00:00:00.000+07:00`);
  const end = new Date(`${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T23:59:59.999+07:00`);
  return { start, end, year, month, day };
}

/**
 * Xây dựng các khung giờ (hour slots) 2 tiếng linh hoạt dựa trên cấu hình OPEN_TIME và CLOSE_TIME
 * Tự động chuyển đổi theo ngày có hiệu lực (ngày hôm sau) hoặc tra cứu đúng khung giờ lịch sử cho ngày đó
 * Hỗ trợ mọi cấu hình giờ mở/đóng cửa gồm cả phút (ví dụ 07:30, 08:00, 21:30, 22:00...)
 *
 * @param {Date|string|number} targetDate - Ngày cần tính khung giờ
 */
async function getOperatingHourSlots(targetDate = new Date()) {
  const configs = await SystemConfig.find();
  const configMap = {};
  for (const c of configs) {
    configMap[c.config_key] = c.config_value;
    if (c.key) configMap[c.key] = c.value;
  }

  await autoPromoteOperatingHours(configMap);
  const resolved = resolveOperatingHoursForDate(configMap, targetDate);

  const openTimeStr = resolved.openTime;
  const closeTimeStr = resolved.closeTime;

  const [openH, openM = 0] = openTimeStr.split(':').map(Number);
  const [closeH, closeM = 0] = closeTimeStr.split(':').map(Number);

  const openTotalMin = openH * 60 + openM;
  const closeTotalMin = closeH * 60 + closeM;

  const slots = [];
  const SLOT_DURATION_MIN = 120; // 2 tiếng = 120 phút

  let cur = openTotalMin;
  while (cur < closeTotalMin) {
    const next = Math.min(cur + SLOT_DURATION_MIN, closeTotalMin);

    const startH = Math.floor(cur / 60);
    const startM = cur % 60;
    const endH = Math.floor(next / 60);
    const endM = next % 60;

    const startStr = `${String(startH).padStart(2, '0')}:${String(startM).padStart(2, '0')}`;
    const endStr = `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}`;

    slots.push({
      startMin: cur,
      endMin: next,
      label: `${startStr} - ${endStr}`,
    });

    cur = next;
  }

  return { openTotalMin, closeTotalMin, openTimeStr, closeTimeStr, slots, resolved };
}

/**
 * Định dạng thời gian theo múi giờ Việt Nam cho file CSV
 */
function formatVNTime(date) {
  if (!date) return '';
  const d = new Date(date);
  const formatter = new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });
  return formatter.format(d);
}

// GET /api/admin/realtime/present — Danh sách sinh viên đang có mặt trong thư viện
async function getPresentList(req, res, next) {
  try {
    const presentUsers = await User.find({ is_inside: true, deleted_at: null })
      .select('-password_hash -password -refresh_token -refreshToken')
      .populate('role_id');

    const now = new Date();
    const userIds = presentUsers.map((u) => u._id);

    // Lấy log check-in hiện tại của từng người
    const activeLogs = await CheckInLog.find({
      user_id: { $in: userIds },
      status: 'INSIDE',
      check_out_time: null,
    }).sort({ check_in_time: -1 });

    const logMap = {};
    for (const log of activeLogs) {
      if (!logMap[log.user_id.toString()]) {
        logMap[log.user_id.toString()] = log;
      }
    }

    const presentList = presentUsers.map((u) => {
      const log = logMap[u._id.toString()];
      const checkInTime = log ? log.check_in_time : u.last_check_in;
      const duration = checkInTime
        ? Math.max(1, Math.round((now - new Date(checkInTime)) / 60000))
        : 0;

      return {
        userId: u._id,
        id: u._id,
        studentId: u.student_id,
        name: u.full_name,
        fullName: u.full_name,
        avatarUrl: u.avatar_url,
        checkInTime: checkInTime,
        durationMinutes: duration,
      };
    });

    const currentOccupancy = presentUsers.length;
    const config = await SystemConfig.findOne({ config_key: 'MAX_CAPACITY' });
    const maxCapacity = parseInt(config?.config_value || '200', 10);
    const occupancyPercent = maxCapacity > 0 ? Math.round((currentOccupancy / maxCapacity) * 100) : 0;

    res.json({
      success: true,
      data: {
        currentOccupancy,
        maxCapacity,
        occupancyPercent,
        presentList,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/realtime/stats — Thống kê tức thời trong ngày theo khung giờ cấu hình
async function getRealtimeStats(req, res, next) {
  try {
    const vnToday = getVNDayBounds();
    const todayStart = vnToday.start;
    const todayEnd = vnToday.end;

    const totalVisitsToday = await CheckInLog.countDocuments({
      check_in_time: { $gte: todayStart, $lte: todayEnd },
    });

    const currentOccupancy = await User.countDocuments({ is_inside: true, deleted_at: null });

    // Khung giờ theo cấu hình OPEN_TIME - CLOSE_TIME
    const { openTotalMin, closeTotalMin, slots } = await getOperatingHourSlots();

    const minuteOfDayExpr = {
      $add: [
        { $multiply: [{ $hour: { date: '$check_in_time', timezone: '+07:00' } }, 60] },
        { $minute: { date: '$check_in_time', timezone: '+07:00' } },
      ],
    };

    const branches = slots.map((s) => ({
      case: {
        $and: [
          { $gte: [minuteOfDayExpr, s.startMin] },
          { $lt: [minuteOfDayExpr, s.endMin] },
        ],
      },
      then: s.label,
    }));

    const hourSlotExpr = {
      $switch: {
        branches,
        default: 'Khác',
      },
    };

    // Tìm khung giờ cao điểm trong ngày (chỉ tính trong khung giờ mở cửa)
    const hourlyData = await CheckInLog.aggregate([
      {
        $match: {
          check_in_time: { $gte: todayStart, $lte: todayEnd },
          $expr: {
            $and: [
              { $gte: [minuteOfDayExpr, openTotalMin] },
              { $lt: [minuteOfDayExpr, closeTotalMin] },
            ],
          },
        },
      },
      { $group: { _id: hourSlotExpr, count: { $sum: 1 } } },
      { $match: { _id: { $ne: 'Khác' } } },
      { $sort: { count: -1 } },
    ]);

    const peak = hourlyData[0];
    const peakTime = peak ? peak._id : null;

    res.json({
      success: true,
      data: {
        totalVisitsToday,
        currentOccupancy,
        peakOccupancy: peak?.count || 0,
        peakTime,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/reports/checkin?groupBy=hour|day|week&from=...&to=...
async function getCheckinReport(req, res, next) {
  try {
    const { groupBy = 'day', from, to } = req.query;

    const vnToday = getVNDayBounds();
    let fromDate;
    let toDate;

    if (from) {
      fromDate = new Date(from);
      toDate = to ? new Date(to) : new Date();
      toDate.setHours(23, 59, 59, 999);
    } else if (groupBy === 'hour') {
      // Mặc định xem thống kê các khung giờ trong ngày hôm nay
      fromDate = vnToday.start;
      toDate = vnToday.end;

      // Nếu hôm nay chưa có dữ liệu (ví dụ chạy thử nghiệm vào ngày khác), tự động lấy ngày có dữ liệu gần nhất
      const todayCount = await CheckInLog.countDocuments({
        check_in_time: { $gte: fromDate, $lte: toDate },
      });
      if (todayCount === 0) {
        const latestLog = await CheckInLog.findOne().sort({ check_in_time: -1 });
        if (latestLog) {
          const latestVn = getVNDayBounds(latestLog.check_in_time);
          fromDate = latestVn.start;
          toDate = latestVn.end;
        }
      }
    } else {
      fromDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      toDate = new Date();
      toDate.setHours(23, 59, 59, 999);
    }

    // Xác định khung giờ mở cửa có hiệu lực tương ứng cho ngày được truy vấn (đặc biệt khi xem theo giờ)
    const queryDate = groupBy === 'hour' ? fromDate : new Date();
    const { openTotalMin, closeTotalMin, slots } = await getOperatingHourSlots(queryDate);

    const minuteOfDayExpr = {
      $add: [
        { $multiply: [{ $hour: { date: '$check_in_time', timezone: '+07:00' } }, 60] },
        { $minute: { date: '$check_in_time', timezone: '+07:00' } },
      ],
    };

    // Xây dựng expression nhóm theo khung giờ cấu hình
    const branches = slots.map((s) => ({
      case: {
        $and: [
          { $gte: [minuteOfDayExpr, s.startMin] },
          { $lt: [minuteOfDayExpr, s.endMin] },
        ],
      },
      then: s.label,
    }));

    const hourSlotExpr = {
      $switch: {
        branches,
        default: 'Khác',
      },
    };

    const groupFormats = {
      hour: hourSlotExpr,
      day: { $dateToString: { format: '%Y-%m-%d', date: '$check_in_time', timezone: '+07:00' } },
      week: { $dateToString: { format: '%Y-W%V', date: '$check_in_time', timezone: '+07:00' } },
    };

    const format = groupFormats[groupBy] || groupFormats.day;

    // Filter match: nếu xem theo giờ thì CHỈ lấy các lượt check-in nằm trong khung giờ mở cửa [openTotalMin, closeTotalMin)
    const matchFilter = {
      check_in_time: { $gte: fromDate, $lte: toDate },
    };

    if (groupBy === 'hour') {
      matchFilter.$expr = {
        $and: [
          { $gte: [minuteOfDayExpr, openTotalMin] },
          { $lt: [minuteOfDayExpr, closeTotalMin] },
        ],
      };
    }

    const checkInData = await CheckInLog.aggregate([
      { $match: matchFilter },
      {
        $group: {
          _id: format,
          checkIns: { $sum: 1 },
          totalDuration: { $sum: { $ifNull: ['$total_minutes', 0] } },
          completedSessions: {
            $sum: { $cond: [{ $ne: ['$check_out_time', null] }, 1, 0] },
          },
        },
      },
      { $match: { _id: { $ne: 'Khác' } } },
      { $sort: { _id: 1 } },
    ]);

    let labels = [];
    let checkIns = [];

    if (groupBy === 'hour') {
      // Map kết quả aggregate vào toàn bộ danh sách slots cấu hình để đảm bảo các khung giờ có 0 lượt vẫn hiện trên biểu đồ
      const dataMap = {};
      for (const d of checkInData) {
        dataMap[d._id] = d;
      }
      labels = slots.map((s) => s.label);
      checkIns = slots.map((s) => (dataMap[s.label] ? dataMap[s.label].checkIns : 0));
    } else {
      labels = checkInData.map((d) => d._id);
      checkIns = checkInData.map((d) => d.checkIns);
    }
    const totalVisits = checkIns.reduce((a, b) => a + b, 0);
    const totalDur = checkInData.reduce((a, d) => a + d.totalDuration, 0);
    const completed = checkInData.reduce((a, d) => a + d.completedSessions, 0);

    res.json({
      success: true,
      data: {
        labels,
        checkIns,
        totalVisits,
        avgDuration: completed > 0 ? Math.round(totalDur / completed) : 0,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/reports/users/:id/history
async function getUserHistory(req, res, next) {
  try {
    const { page = 1, limit = 20, from, to } = req.query;
    const user = await User.findOne({ _id: req.params.id, deleted_at: null });
    if (!user) {
      return res.status(404).json({ success: false, errorCode: 'USER_NOT_FOUND', message: 'Không tìm thấy thành viên' });
    }

    const filter = { user_id: user._id };
    if (from || to) {
      filter.check_in_time = {};
      if (from) filter.check_in_time.$gte = new Date(from);
      if (to) filter.check_in_time.$lte = new Date(to);
    }

    const total = await CheckInLog.countDocuments(filter);
    const logs = await CheckInLog.find(filter)
      .populate('gate_id')
      .sort({ check_in_time: -1 })
      .skip((Number(page) - 1) * Number(limit))
      .limit(Number(limit));

    const totalMinutes = logs.reduce((sum, l) => sum + (l.total_minutes || 0), 0);

    const formattedLogs = logs.map((l) => ({
      _id: l._id,
      id: l._id,
      userId: l.user_id,
      studentId: user.student_id,
      studentName: user.full_name,
      checkInTime: l.check_in_time,
      checkOutTime: l.check_out_time,
      durationMinutes: l.total_minutes,
      actionType: l.action_type,
      status: l.status,
      gateName: l.gate_id?.gate_name || 'Cổng chính',
    }));

    res.json({
      success: true,
      data: formattedLogs,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total,
        totalPages: Math.ceil(total / Number(limit)),
      },
      summary: {
        totalVisits: total,
        totalMinutes,
        avgDurationMinutes: logs.length > 0 ? Math.round(totalMinutes / logs.length) : 0,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/reports/export?format=csv&from=...&to=...
async function exportReport(req, res, next) {
  try {
    const { from, to } = req.query;
    const filter = {};
    if (from || to) {
      filter.check_in_time = {};
      if (from) filter.check_in_time.$gte = new Date(from);
      if (to) filter.check_in_time.$lte = new Date(to);
    }

    const logs = await CheckInLog.find(filter)
      .populate('user_id')
      .sort({ check_in_time: -1 })
      .limit(5000);

    const header = 'STT,Mã SV,Họ tên,Giờ vào,Giờ ra,Thời gian lưu (phút)\n';
    const rows = logs
      .map((l, i) => {
        const studentId = l.user_id?.student_id || l.student_id || '';
        const studentName = l.user_id?.full_name || l.student_name || '';
        const inStr = l.check_in_time ? formatVNTime(l.check_in_time) : '';
        const outStr = l.check_out_time ? formatVNTime(l.check_out_time) : '';
        const dur = l.total_minutes !== null && l.total_minutes !== undefined ? l.total_minutes : '';
        return `${i + 1},${studentId},"${studentName}",${inStr},${outStr},${dur}`;
      })
      .join('\n');

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="library_report_${Date.now()}.csv"`);
    res.send('﻿' + header + rows); // BOM cho Excel đọc UTF-8 tiếng Việt chuẩn
  } catch (err) {
    next(err);
  }
}

// POST /api/admin/realtime/checkout/:userId — Cưỡng chế check-out tại quầy
async function forceCheckOutUser(req, res, next) {
  try {
    const { userId } = req.params;
    const user = await User.findOne({ _id: userId, deleted_at: null });
    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }

    const activeLog = await CheckInLog.findOne({
      user_id: user._id,
      status: 'INSIDE',
      check_out_time: null,
    }).sort({ check_in_time: -1 });

    const now = new Date();

    if (activeLog) {
      activeLog.check_out_time = now;
      activeLog.action_type = 'CHECK_OUT';
      activeLog.status = 'COMPLETED';
      activeLog.total_minutes = Math.max(1, Math.round((now - activeLog.check_in_time) / 60000));
      await activeLog.save();
    }

    user.is_inside = false;
    await user.save();

    // Bắn thông báo Push Notification qua FCM tới điện thoại sinh viên
    const staffName = req.user?.full_name || 'Thủ thư';
    sendForceCheckOutNotification(user, activeLog, staffName).catch((e) =>
      console.warn('[FCM] Error sending force checkout push:', e.message)
    );

    res.json({
      success: true,
      message: `Đã check-out thành công cho ${user.full_name} (${user.student_id})`,
      data: {
        userId: user._id,
        checkOutTime: now,
        durationMinutes: activeLog?.total_minutes || 0,
      },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getPresentList,
  getRealtimeStats,
  getCheckinReport,
  getUserHistory,
  exportReport,
  forceCheckOutUser,
};
