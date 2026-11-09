require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const Role = require('./models/role_model');
const Gate = require('./models/gate_model');
const User = require('./models/user_model');
const LibraryCard = require('./models/library_card_model');
const CheckInLog = require('./models/check_in_log_model');
const SystemConfig = require('./models/system_config_model');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/library_access_system';
const SALT_ROUNDS = 10;

async function seed() {
  console.log(`Connecting to MongoDB: ${MONGODB_URI}...`);
  await mongoose.connect(MONGODB_URI);
  console.log('MongoDB connected successfully.');

  // Dọn dẹp index cũ v1 gây lỗi trùng lặp studentId_1
  try {
    const indexes = await User.collection.indexes();
    for (const idx of indexes) {
      if (idx.name === 'studentId_1' || idx.name === 'username_1') {
        await User.collection.dropIndex(idx.name);
        console.log(`- Dropped obsolete index: ${idx.name}`);
      }
    }
  } catch (_) {}

  // 1. Seed Roles
  console.log('\n--- 1. Seeding Roles ---');
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
    console.log(`- Role: ${r.role_name} (${roleDoc._id})`);
  }

  // 2. Seed SystemConfigs
  console.log('\n--- 2. Seeding System Configs ---');
  await SystemConfig.seedDefaults();
  console.log('System configs seeded with original specifications.');

  // 3. Seed Gates
  console.log('\n--- 3. Seeding Gates ---');
  const gateMain = await Gate.findOneAndUpdate(
    { gate_name: 'Cổng chính' },
    {
      gate_name: 'Cổng chính',
      location: 'Sảnh chính - Tầng 1 Nhà Thư Viện',
      status: 'ACTIVE',
      updated_at: new Date(),
    },
    { upsert: true, new: true }
  );
  console.log(`- Gate: ${gateMain.gate_name} (${gateMain._id})`);

  // 4. Seed Admin & Librarian
  console.log('\n--- 4. Seeding Staff (Admin & Librarian) ---');
  const defaultAdminPassword = await bcrypt.hash('Admin@123', SALT_ROUNDS);
  const defaultLibPassword = await bcrypt.hash('Librarian@123', SALT_ROUNDS);
  const defaultStudentPassword = await bcrypt.hash('Student@123', SALT_ROUNDS);

  const adminUser = await User.findOneAndUpdate(
    { student_id: 'ADMIN01' },
    {
      student_id: 'ADMIN01',
      full_name: 'Quản Trị Viên Hệ Thống',
      email: 'admin@library.edu.vn',
      password_hash: defaultAdminPassword,
      phone: '0901234567',
      role_id: roleMap['ADMIN'],
      status: 'ACTIVE',
      is_inside: false,
      deleted_at: null,
      updated_at: new Date(),
    },
    { upsert: true, new: true }
  );
  console.log(`- Admin: ${adminUser.full_name} (${adminUser.student_id})`);

  const librarianUser = await User.findOneAndUpdate(
    { student_id: 'LIB01' },
    {
      student_id: 'LIB01',
      full_name: 'Trần Văn Thủ Thư',
      email: 'librarian@library.edu.vn',
      password_hash: defaultLibPassword,
      phone: '0907654321',
      role_id: roleMap['LIBRARIAN'],
      status: 'ACTIVE',
      is_inside: false,
      deleted_at: null,
      updated_at: new Date(),
    },
    { upsert: true, new: true }
  );
  console.log(`- Librarian: ${librarianUser.full_name} (${librarianUser.student_id})`);

  // 5. Seed ~15 Sinh viên mẫu
  console.log('\n--- 5. Seeding 15 Sample Students & Library Cards ---');
  const now = new Date();
  const oneYearLater = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000);
  const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const tenDaysAgo = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000);

  const sampleStudents = [
    { student_id: 'HE190001', full_name: 'Nguyễn Văn An', email: 'an.nv@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190002', full_name: 'Trần Thị Bình', email: 'binh.tt@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190003', full_name: 'Lê Hoàng Cường', email: 'cuong.lh@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 120 },
    { student_id: 'HE190004', full_name: 'Phạm Minh Dũng', email: 'dung.pm@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 65 },
    { student_id: 'HE190005', full_name: 'Hoàng Thị Giang', email: 'giang.ht@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190006', full_name: 'Vũ Đức Hải', email: 'hai.vd@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190007', full_name: 'Đặng Tuấn Kiệt', email: 'kiet.dt@fpt.edu.vn', status: 'BLOCKED', is_inside: false, card_status: 'LOCKED', expiry: oneYearLater },
    { student_id: 'HE190008', full_name: 'Bùi Khánh Linh', email: 'linh.bk@fpt.edu.vn', status: 'BLOCKED', is_inside: true, card_status: 'LOCKED', expiry: oneYearLater, insideSinceMinutes: 90 },
    { student_id: 'HE190009', full_name: 'Ngô Quang Minh', email: 'minh.nq@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'EXPIRED', expiry: oneMonthAgo },
    { student_id: 'HE190010', full_name: 'Đỗ Phương Nam', email: 'nam.dp@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'EXPIRED', expiry: tenDaysAgo },
    { student_id: 'HE190011', full_name: 'Hồ Gia Oanh', email: 'oanh.hg@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'LOCKED', expiry: oneYearLater },
    { student_id: 'HE190012', full_name: 'Phan Hữu Phúc', email: 'phuc.ph@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 45 },
    { student_id: 'HE190013', full_name: 'Trịnh Thu Quỳnh', email: 'quynh.tt@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190014', full_name: 'Cao Đình Sang', email: 'sang.cd@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190015', full_name: 'Lâm Mỹ Tâm', email: 'tam.lm@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
  ];

  for (const s of sampleStudents) {
    const checkInTime = s.is_inside
      ? new Date(now.getTime() - (s.insideSinceMinutes || 30) * 60 * 1000)
      : null;

    const studentUser = await User.findOneAndUpdate(
      { student_id: s.student_id },
      {
        student_id: s.student_id,
        full_name: s.full_name,
        email: s.email,
        password_hash: defaultStudentPassword,
        phone: '098' + Math.floor(1000000 + Math.random() * 9000000),
        role_id: roleMap['STUDENT'],
        status: s.status,
        is_inside: s.is_inside,
        last_check_in: checkInTime,
        deleted_at: null,
        updated_at: new Date(),
      },
      { upsert: true, new: true }
    );

    // Seed / update library card
    const qrHash = crypto.randomBytes(16).toString('hex');
    const card = await LibraryCard.findOneAndUpdate(
      { user_id: studentUser._id },
      {
        user_id: studentUser._id,
        qr_code_hash: qrHash,
        issue_date: new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000),
        expiry_date: s.expiry,
        status: s.card_status,
        updated_at: new Date(),
      },
      { upsert: true, new: true }
    );

    // Nếu đang is_inside, tạo CheckInLog với status INSIDE
    if (s.is_inside && checkInTime) {
      await CheckInLog.findOneAndUpdate(
        { user_id: studentUser._id, status: 'INSIDE' },
        {
          user_id: studentUser._id,
          card_id: card._id,
          gate_id: gateMain._id,
          check_in_time: checkInTime,
          check_out_time: null,
          total_minutes: null,
          action_type: 'CHECK_IN',
          status: 'INSIDE',
          sync_status: 'SYNCED',
          updated_at: new Date(),
        },
        { upsert: true, new: true }
      );
    }

    console.log(
      `- SV: ${s.student_id} | ${s.full_name.padEnd(18)} | User: ${s.status.padEnd(7)} | Card: ${s.card_status.padEnd(7)} | Inside: ${s.is_inside}`
    );
  }

  console.log('\n=== Seed Completed Successfully! ===');
  await mongoose.disconnect();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
