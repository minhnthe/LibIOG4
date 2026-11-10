const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const Role = require('../models/role_model');
const User = require('../models/user_model');
const LibraryCard = require('../models/library_card_model');

const SALT_ROUNDS = 10;

/**
 * Tự động dọn dẹp các index cũ từ v1 và đảm bảo các Roles,
 * Tài khoản mẫu (Admin, Thủ thư, Sinh viên) luôn sẵn sàng.
 */
async function bootstrapDemoAccounts() {
  try {
    // 0. Gỡ bỏ index cũ gây lỗi E11000: studentId_1 (camelCase từ phiên bản cũ v1)
    try {
      const indexes = await User.collection.indexes();
      for (const idx of indexes) {
        if (idx.name === 'studentId_1' || idx.name === 'username_1') {
          await User.collection.dropIndex(idx.name);
          console.log(`Đã gỡ bỏ index cũ gây trùng lặp: ${idx.name}`);
        }
      }
    } catch (_) {}

    // 1. Roles
    const rolesData = [
      { role_name: 'ADMIN', description: 'Quản trị viên toàn quyền hệ thống' },
      { role_name: 'LIBRARIAN', description: 'Thủ thư vận hành trạm quét và kiểm soát ra vào' },
      { role_name: 'STUDENT', description: 'Sinh viên sử dụng thẻ ra vào thư viện' },
    ];

    const roleMap = {};
    for (const r of rolesData) {
      const roleDoc = await Role.findOneAndUpdate(
        { role_name: r.role_name },
        { ...r, updated_at: new Date() },
        { upsert: true, new: true }
      );
      roleMap[r.role_name] = roleDoc._id;
    }

    // Hash mật khẩu
    const adminPassHash = await bcrypt.hash('Admin@123', SALT_ROUNDS);
    const libPassHash = await bcrypt.hash('Librarian@123', SALT_ROUNDS);
    const studentPassHash = await bcrypt.hash('Student@123', SALT_ROUNDS);

    // 2. Admin (ADMIN01)
    let adminDoc = await User.findOne({
      $or: [{ student_id: 'ADMIN01' }, { email: 'admin@library.edu.vn' }],
    });
    if (adminDoc) {
      adminDoc.student_id = 'ADMIN01';
      adminDoc.full_name = 'Quản Trị Viên Hệ Thống';
      adminDoc.email = 'admin@library.edu.vn';
      adminDoc.password_hash = adminPassHash;
      adminDoc.phone = '0901234567';
      adminDoc.role_id = roleMap['ADMIN'];
      adminDoc.status = 'ACTIVE';
      adminDoc.is_inside = false;
      adminDoc.deleted_at = null;
      adminDoc.updated_at = new Date();
      await adminDoc.save();
    } else {
      adminDoc = await User.create({
        student_id: 'ADMIN01',
        full_name: 'Quản Trị Viên Hệ Thống',
        email: 'admin@library.edu.vn',
        password_hash: adminPassHash,
        phone: '0901234567',
        role_id: roleMap['ADMIN'],
        status: 'ACTIVE',
        is_inside: false,
        deleted_at: null,
      });
    }

    // 3. 3 Thủ thư (LIB01, LIB02, LIB03)
    const librarians = [
      {
        student_id: 'LIB01',
        full_name: 'Trần Văn Thủ Thư',
        email: 'librarian@library.edu.vn',
        phone: '0907654321',
      },
      {
        student_id: 'LIB02',
        full_name: 'Nguyễn Thị Hương Thư',
        email: 'librarian02@library.edu.vn',
        phone: '0907654322',
      },
      {
        student_id: 'LIB03',
        full_name: 'Lê Minh Thảo',
        email: 'librarian03@library.edu.vn',
        phone: '0907654323',
      },
    ];

    for (const lib of librarians) {
      let libDoc = await User.findOne({
        $or: [{ student_id: lib.student_id }, { email: lib.email }],
      });
      if (libDoc) {
        libDoc.student_id = lib.student_id;
        libDoc.full_name = lib.full_name;
        libDoc.email = lib.email;
        libDoc.password_hash = libPassHash;
        libDoc.phone = lib.phone;
        libDoc.role_id = roleMap['LIBRARIAN'];
        libDoc.status = 'ACTIVE';
        libDoc.is_inside = false;
        libDoc.deleted_at = null;
        libDoc.updated_at = new Date();
        await libDoc.save();
      } else {
        await User.create({
          student_id: lib.student_id,
          full_name: lib.full_name,
          email: lib.email,
          password_hash: libPassHash,
          phone: lib.phone,
          role_id: roleMap['LIBRARIAN'],
          status: 'ACTIVE',
          is_inside: false,
          deleted_at: null,
        });
      }
    }

    // 4. Sinh viên mẫu (HE190001)
    let studentDoc = await User.findOne({
      $or: [{ student_id: 'HE190001' }, { email: 'an.nv@fpt.edu.vn' }],
    });
    if (studentDoc) {
      studentDoc.student_id = 'HE190001';
      studentDoc.full_name = 'Nguyễn Văn An';
      studentDoc.email = 'an.nv@fpt.edu.vn';
      studentDoc.password_hash = studentPassHash;
      studentDoc.phone = '0981234567';
      studentDoc.role_id = roleMap['STUDENT'];
      studentDoc.status = 'ACTIVE';
      studentDoc.is_inside = false;
      studentDoc.deleted_at = null;
      studentDoc.updated_at = new Date();
      await studentDoc.save();
    } else {
      studentDoc = await User.create({
        student_id: 'HE190001',
        full_name: 'Nguyễn Văn An',
        email: 'an.nv@fpt.edu.vn',
        password_hash: studentPassHash,
        phone: '0981234567',
        role_id: roleMap['STUDENT'],
        status: 'ACTIVE',
        is_inside: false,
        deleted_at: null,
      });
    }

    // Thẻ thư viện cho HE190001
    if (studentDoc && studentDoc._id) {
      const oneYearLater = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
      await LibraryCard.findOneAndUpdate(
        { user_id: studentDoc._id },
        {
          user_id: studentDoc._id,
          qr_code_hash: crypto.randomBytes(16).toString('hex'),
          issue_date: new Date(),
          expiry_date: oneYearLater,
          status: 'ACTIVE',
          updated_at: new Date(),
        },
        { upsert: true, new: true }
      );
    }

    console.log('Demo accounts bootstrap completed: ADMIN01, LIB01..LIB03, HE190001 ready.');
  } catch (err) {
    console.error('Error bootstrapping demo accounts:', err.message);
  }
}

module.exports = { bootstrapDemoAccounts };
