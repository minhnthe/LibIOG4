const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const User = require('../models/user_model');
const Role = require('../models/role_model');
const LibraryCard = require('../models/library_card_model');
const CheckInLog = require('../models/check_in_log_model');
const { sendCardStatusNotification } = require('../services/fcm_service');

const SALT_ROUNDS = 10;

// GET /api/admin/users
async function listUsers(req, res, next) {
  try {
    const { page = 1, limit = 20, search, status, role } = req.query;
    const filter = { deleted_at: null };

    // Lọc theo trạng thái (chấp nhận cả active/locked và ACTIVE/BLOCKED)
    if (status) {
      const upperStatus = status.toString().toUpperCase();
      if (upperStatus === 'LOCKED' || upperStatus === 'BLOCKED') {
        filter.status = 'BLOCKED';
      } else if (upperStatus === 'ACTIVE') {
        filter.status = 'ACTIVE';
      }
    }

    // Lọc theo vai trò
    if (role) {
      const roleDoc = await Role.findOne({ role_name: role.toString().toUpperCase() });
      if (roleDoc) {
        filter.role_id = roleDoc._id;
      }
    }

    // Tìm kiếm theo mã SV, họ tên hoặc email
    if (search) {
      filter.$or = [
        { student_id: { $regex: search, $options: 'i' } },
        { full_name: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
      ];
    }

    const total = await User.countDocuments(filter);
    const users = await User.find(filter)
      .populate('role_id')
      .sort({ created_at: -1 })
      .skip((page - 1) * Number(limit))
      .limit(Number(limit));

    // Lấy thông tin thẻ thư viện tương ứng cho từng thành viên
    const userIds = users.map((u) => u._id);
    const cards = await LibraryCard.find({ user_id: { $in: userIds } });
    const cardMap = {};
    for (const c of cards) {
      cardMap[c.user_id.toString()] = c;
    }

    const formattedUsers = users.map((u) => {
      const safe = u.toSafeObject();
      const card = cardMap[u._id.toString()];
      if (card) {
        safe.cardExpiry = card.expiry_date;
        safe.cardStatus = card.status;
      }
      return safe;
    });

    res.json({
      success: true,
      data: formattedUsers,
      pagination: {
        page: Number(page),
        limit: Number(limit),
        total,
        totalPages: Math.ceil(total / Number(limit)),
      },
    });
  } catch (err) {
    next(err);
  }
}

// POST /api/admin/users
async function createUser(req, res, next) {
  try {
    const rawStudentId = req.body.studentId || req.body.student_id;
    const rawName = req.body.name || req.body.full_name;
    const { email, phone, role, cardExpiry } = req.body;

    if (!rawStudentId || !rawName || !email) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_INPUT',
        message: 'studentId, name, email bắt buộc',
      });
    }

    const studentId = rawStudentId.trim();
    const name = rawName.trim();
    const normalizedEmail = email.toLowerCase().trim();

    const existing = await User.findOne({
      $or: [{ student_id: studentId }, { email: normalizedEmail }],
    });
    if (existing) {
      return res.status(409).json({
        success: false,
        errorCode: 'DUPLICATE_USER',
        message: 'Mã sinh viên hoặc email đã tồn tại',
      });
    }

    // Ánh xạ role_id
    const requesterRole = (req.userRole || req.user?.role_id?.role_name || req.user?.role || '').toUpperCase();
    const targetRoleName = (role || 'STUDENT').toString().toUpperCase();
    if (!['STUDENT', 'LIBRARIAN', 'ADMIN'].includes(targetRoleName)) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_ROLE',
        message: 'Vai trò tài khoản không hợp lệ',
      });
    }

    // Chỉ ADMIN được cấp vai trò quản trị hoặc thủ thư.
    if (requesterRole !== 'ADMIN' && targetRoleName !== 'STUDENT') {
      return res.status(403).json({
        success: false,
        errorCode: 'FORBIDDEN',
        message: 'Thủ thư chỉ có thể tạo tài khoản sinh viên',
      });
    }

    const roleDoc = await Role.findOne({ role_name: targetRoleName });
    if (!roleDoc) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_ROLE',
        message: 'Vai trò tài khoản không hợp lệ',
      });
    }

    // Mật khẩu tạm: studentId + "@Lib"
    const tempPassword = `${studentId}@Lib`;
    const hashedPassword = await bcrypt.hash(tempPassword, SALT_ROUNDS);

    const user = await User.create({
      student_id: studentId,
      full_name: name,
      email: normalizedEmail,
      phone: phone ? phone.trim() : '',
      role_id: roleDoc._id,
      password_hash: hashedPassword,
      status: 'ACTIVE',
      deleted_at: null,
    });

    // Tạo thẻ thư viện tương ứng trong bảng library_cards
    const expiryDate = cardExpiry ? new Date(cardExpiry) : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);

    const card = await LibraryCard.create({
      user_id: user._id,
      qr_code_hash: crypto.randomBytes(16).toString('hex'),
      issue_date: new Date(),
      expiry_date: expiryDate,
      status: 'ACTIVE',
    });

    await user.populate('role_id');
    const safeData = user.toSafeObject();
    safeData.cardExpiry = card.expiry_date;
    safeData.cardStatus = card.status;
    safeData.tempPassword = tempPassword;

    res.status(201).json({
      success: true,
      data: safeData,
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/users/:id
async function getUserById(req, res, next) {
  try {
    const user = await User.findOne({ _id: req.params.id, deleted_at: null }).populate('role_id');
    if (!user) {
      return res.status(404).json({
        success: false,
        errorCode: 'USER_NOT_FOUND',
        message: 'Không tìm thấy thành viên',
      });
    }

    const card = await LibraryCard.findOne({ user_id: user._id });
    const safeUser = user.toSafeObject();
    if (card) {
      safeUser.cardExpiry = card.expiry_date;
      safeUser.cardStatus = card.status;
    }

    res.json({ success: true, data: safeUser });
  } catch (err) {
    next(err);
  }
}

// PUT /api/admin/users/:id
async function updateUser(req, res, next) {
  try {
    const rawName = req.body.name || req.body.full_name;
    const { email, phone, cardExpiry, role } = req.body;

    const requesterRole = (req.userRole || req.user?.role_id?.role_name || req.user?.role || '').toUpperCase();

    // 1. Kiểm tra thành viên cần cập nhật
    const existingUser = await User.findOne({ _id: req.params.id, deleted_at: null }).populate('role_id');
    if (!existingUser) {
      return res.status(404).json({
        success: false,
        errorCode: 'USER_NOT_FOUND',
        message: 'Không tìm thấy thành viên',
      });
    }

    const targetRole = (existingUser.role_id?.role_name || existingUser.role || 'STUDENT').toUpperCase();

    // Thủ thư không được phép sửa thông tin của Admin hoặc Thủ thư khác
    if (requesterRole !== 'ADMIN' && targetRole !== 'STUDENT') {
      return res.status(403).json({
        success: false,
        errorCode: 'FORBIDDEN',
        message: 'Thủ thư không có quyền chỉnh sửa tài khoản cán bộ hoặc quản trị viên',
      });
    }

    // Chỉ Admin mới được phép phân quyền vai trò (role)
    if (role && requesterRole !== 'ADMIN') {
      return res.status(403).json({
        success: false,
        errorCode: 'FORBIDDEN',
        message: 'Chỉ Quản trị viên mới có quyền phân quyền vai trò',
      });
    }

    const updateFields = {};
    if (rawName) updateFields.full_name = rawName.trim();
    if (email) updateFields.email = email.toLowerCase().trim();
    if (phone !== undefined) updateFields.phone = phone.trim();

    if (role) {
      const targetRoleName = role.toString().toUpperCase();
      const roleDoc = await Role.findOne({ role_name: targetRoleName });
      if (roleDoc) {
        updateFields.role_id = roleDoc._id;
      }
    }

    const user = await User.findOneAndUpdate(
      { _id: req.params.id, deleted_at: null },
      { $set: updateFields },
      { new: true },
    ).populate('role_id');

    if (!user) {
      return res.status(404).json({
        success: false,
        errorCode: 'USER_NOT_FOUND',
        message: 'Không tìm thấy thành viên',
      });
    }

    // Cập nhật hạn thẻ nếu có truyền cardExpiry
    let card = await LibraryCard.findOne({ user_id: user._id });
    if (cardExpiry) {
      const newExpiry = new Date(cardExpiry);
      if (card) {
        card.expiry_date = newExpiry;
        if (card.status === 'EXPIRED' && newExpiry > new Date()) {
          card.status = 'ACTIVE';
        }
        await card.save();
      } else {
        card = await LibraryCard.create({
          user_id: user._id,
          qr_code_hash: crypto.randomBytes(16).toString('hex'),
          issue_date: new Date(),
          expiry_date: newExpiry,
          status: 'ACTIVE',
        });
      }
    }

    const safeUser = user.toSafeObject();
    if (card) {
      safeUser.cardExpiry = card.expiry_date;
      safeUser.cardStatus = card.status;
    }

    res.json({ success: true, message: 'Cập nhật thành công', data: safeUser });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/admin/users/:id/status (Đồng bộ khóa thẻ / người dùng)
async function updateUserStatus(req, res, next) {
  try {
    const { status, reason } = req.body;
    if (!status) {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_INPUT',
        message: 'status bắt buộc (ACTIVE hoặc BLOCKED)',
      });
    }

    const rawStatus = status.toString().toUpperCase();
    let targetUserStatus = 'ACTIVE';
    let targetCardStatus = 'ACTIVE';

    if (rawStatus === 'LOCKED' || rawStatus === 'BLOCKED') {
      targetUserStatus = 'BLOCKED';
      targetCardStatus = 'LOCKED';
    } else if (rawStatus === 'ACTIVE') {
      targetUserStatus = 'ACTIVE';
      targetCardStatus = 'ACTIVE';
    } else {
      return res.status(400).json({
        success: false,
        errorCode: 'INVALID_INPUT',
        message: 'status phải là ACTIVE hoặc BLOCKED',
      });
    }

    // Chặn tự khóa tài khoản của chính mình (BR-08)
    if (req.user && req.params.id === req.user._id.toString() && targetUserStatus === 'BLOCKED') {
      return res.status(400).json({
        success: false,
        errorCode: 'CANNOT_LOCK_SELF',
        message: 'Không thể tự khóa tài khoản của chính mình',
      });
    }

    // 1. Kiểm tra đối tượng người dùng cần cập nhật
    const user = await User.findOne({ _id: req.params.id, deleted_at: null }).populate('role_id');
    if (!user) {
      return res.status(404).json({
        success: false,
        errorCode: 'USER_NOT_FOUND',
        message: 'Không tìm thấy thành viên',
      });
    }

    // 2. Ràng buộc phân quyền RBAC: Thủ thư (LIBRARIAN) chỉ có quyền khóa/mở khóa thẻ sinh viên (STUDENT)
    const requesterRole = (req.userRole || req.user?.role_id?.role_name || req.user?.role || '').toUpperCase();
    const targetRole = (user.role_id?.role_name || user.role || 'STUDENT').toUpperCase();

    if (requesterRole !== 'ADMIN' && targetRole !== 'STUDENT') {
      return res.status(403).json({
        success: false,
        errorCode: 'FORBIDDEN',
        message:
          'Thủ thư chỉ có quyền quản lý thẻ sinh viên, không thể khóa hoặc mở khóa tài khoản cán bộ/quản trị viên',
      });
    }

    // 3. Cập nhật User status
    user.status = targetUserStatus;
    await user.save();

    // 2. Đồng bộ cập nhật bảng library_cards
    let card = await LibraryCard.findOne({ user_id: user._id });
    if (card) {
      if (targetUserStatus === 'ACTIVE' && card.expiry_date && card.expiry_date < new Date()) {
        targetCardStatus = 'EXPIRED';
      }
      card.status = targetCardStatus;
      await card.save();
    }

    const safeUser = user.toSafeObject();
    if (card) {
      safeUser.cardExpiry = card.expiry_date;
      safeUser.cardStatus = card.status;
    }

    const msg =
      targetUserStatus === 'BLOCKED'
        ? `Tài khoản đã bị khóa${reason ? ': ' + reason : ''}`
        : 'Tài khoản đã được mở khóa';

    // Bắn push notification trạng thái thẻ qua FCM (non-blocking)
    sendCardStatusNotification(user, targetUserStatus, reason).catch((e) =>
      console.warn('[FCM] Push error:', e.message),
    );

    res.json({ success: true, message: msg, data: safeUser });
  } catch (err) {
    next(err);
  }
}

// DELETE /api/admin/users/:id (soft delete + đóng phiên nếu đang ở trong + khóa thẻ)
async function deleteUser(req, res, next) {
  try {
    // Chặn tự xóa tài khoản của chính mình (BR-08)
    if (req.user && req.params.id === req.user._id.toString()) {
      return res.status(400).json({
        success: false,
        errorCode: 'CANNOT_DELETE_SELF',
        message: 'Không thể tự xóa tài khoản của chính mình',
      });
    }

    const user = await User.findOne({ _id: req.params.id, deleted_at: null });
    if (!user) {
      return res.status(404).json({
        success: false,
        errorCode: 'USER_NOT_FOUND',
        message: 'Không tìm thấy thành viên',
      });
    }

    // Nếu người dùng đang ở trong thư viện, tự động đóng phiên check-in để giải phóng sức chứa
    if (user.is_inside) {
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
    }

    user.deleted_at = new Date();
    user.status = 'BLOCKED';
    await user.save();

    // Khóa thẻ thư viện khi xóa thành viên
    await LibraryCard.updateMany({ user_id: req.params.id }, { $set: { status: 'LOCKED' } });

    res.json({ success: true, message: 'Đã xóa thành viên' });
  } catch (err) {
    next(err);
  }
}

// POST /api/admin/users/:id/restore (khôi phục thành viên đã xóa mềm - UC34)
async function restoreUser(req, res, next) {
  try {
    const user = await User.findOne({ _id: req.params.id, deleted_at: { $ne: null } }).populate('role_id');
    if (!user) {
      return res.status(404).json({
        success: false,
        errorCode: 'USER_NOT_FOUND',
        message: 'Không tìm thấy thành viên đã xóa để khôi phục',
      });
    }

    user.deleted_at = null;
    user.status = 'ACTIVE';
    await user.save();

    // Mở lại thẻ thư viện nếu thẻ chưa hết hạn
    const card = await LibraryCard.findOne({ user_id: user._id });
    if (card) {
      const isExpired = card.expiry_date && new Date(card.expiry_date) < new Date();
      card.status = isExpired ? 'EXPIRED' : 'ACTIVE';
      await card.save();
    }

    const safeData = user.toSafeObject();
    if (card) {
      safeData.cardExpiry = card.expiry_date;
      safeData.cardStatus = card.status;
    }

    res.json({
      success: true,
      message: `Đã khôi phục thành công tài khoản ${user.full_name} (${user.student_id})`,
      data: safeData,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  listUsers,
  createUser,
  getUserById,
  updateUser,
  updateUserStatus,
  deleteUser,
  restoreUser,
};
