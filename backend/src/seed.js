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

// Ưu tiên: tham số dòng lệnh -> biến môi trường MONGODB_URI -> mongodb local
const MONGODB_URI =
  process.argv[2] ||
  process.env.MONGODB_URI ||
  'mongodb://127.0.0.1:27017/library_access_system';

const SALT_ROUNDS = 10;

async function seed() {
  console.log('====================================================');
  console.log(`Connecting to MongoDB: ${MONGODB_URI}`);
  console.log('====================================================');

  await mongoose.connect(MONGODB_URI);
  console.log('MongoDB connected successfully.\n');

  // Dọn dẹp index cũ v1 gây lỗi trùng lặp studentId_1 hoặc username_1 nếu có
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
  console.log('--- 1. Seeding Roles (ADMIN, LIBRARIAN, STUDENT) ---');
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
    console.log(`- Role: ${r.role_name.padEnd(10)} [ID: ${roleDoc._id}]`);
  }

  // 2. Seed System Configs (Giờ mở/đóng cửa, sức chứa...)
  console.log('\n--- 2. Seeding System Configs ---');
  await SystemConfig.seedDefaults();
  console.log('System configs seeded with default operating parameters.');

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
  console.log(`- Gate: ${gateMain.gate_name} (${gateMain.location})`);

  // Hash mật khẩu dùng chung cho từng vai trò
  console.log('\n--- 4. Hashing Passwords ---');
  const defaultAdminPassword = await bcrypt.hash('Admin@123', SALT_ROUNDS);
  const defaultLibPassword = await bcrypt.hash('Librarian@123', SALT_ROUNDS);
  const defaultStudentPassword = await bcrypt.hash('Student@123', SALT_ROUNDS);
  console.log('Default passwords hashed.');

  // 5. Seed Quản trị viên (Admin)
  console.log('\n--- 5. Seeding Admin ---');
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
  console.log(`- Admin: ${adminUser.full_name} | Mã: ${adminUser.student_id} | Email: ${adminUser.email}`);

  // 6. Seed 3 Thủ Thư (Librarians)
  console.log('\n--- 6. Seeding 3 Librarians ---');
  const librariansData = [
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

  for (const lib of librariansData) {
    const libDoc = await User.findOneAndUpdate(
      { student_id: lib.student_id },
      {
        student_id: lib.student_id,
        full_name: lib.full_name,
        email: lib.email,
        password_hash: defaultLibPassword,
        phone: lib.phone,
        role_id: roleMap['LIBRARIAN'],
        status: 'ACTIVE',
        is_inside: false,
        deleted_at: null,
        updated_at: new Date(),
      },
      { upsert: true, new: true }
    );
    console.log(`- Thủ thư: ${libDoc.student_id} | ${libDoc.full_name.padEnd(22)} | Email: ${libDoc.email}`);
  }

  // 7. Seed 53 Sinh Viên (HE190001 -> HE190053) & Thẻ Thư Viện
  console.log('\n--- 7. Seeding 53 Students & Library Cards ---');
  const now = new Date();
  const oneYearLater = new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000);
  const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const tenDaysAgo = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000);

  const sampleStudents = [
    { student_id: 'HE190001', full_name: 'Nguyễn Văn An', email: 'an.nvhe190001@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190002', full_name: 'Trần Thị Bình', email: 'binh.tthe190002@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190003', full_name: 'Lê Hoàng Cường', email: 'cuong.lhhe190003@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 120 },
    { student_id: 'HE190004', full_name: 'Phạm Minh Dũng', email: 'dung.pmhe190004@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 65 },
    { student_id: 'HE190005', full_name: 'Hoàng Thị Giang', email: 'giang.hthe190005@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190006', full_name: 'Vũ Đức Hải', email: 'hai.vdhe190006@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190007', full_name: 'Đặng Tuấn Kiệt', email: 'kiet.dthe190007@fpt.edu.vn', status: 'BLOCKED', is_inside: false, card_status: 'LOCKED', expiry: oneYearLater },
    { student_id: 'HE190008', full_name: 'Bùi Khánh Linh', email: 'linh.bkhe190008@fpt.edu.vn', status: 'BLOCKED', is_inside: true, card_status: 'LOCKED', expiry: oneYearLater, insideSinceMinutes: 90 },
    { student_id: 'HE190009', full_name: 'Ngô Quang Minh', email: 'minh.nqhe190009@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'EXPIRED', expiry: oneMonthAgo },
    { student_id: 'HE190010', full_name: 'Đỗ Phương Nam', email: 'nam.dphe190010@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'EXPIRED', expiry: tenDaysAgo },
    { student_id: 'HE190011', full_name: 'Hồ Gia Oanh', email: 'oanh.hghe190011@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'LOCKED', expiry: oneYearLater },
    { student_id: 'HE190012', full_name: 'Phan Hữu Phúc', email: 'phuc.phhe190012@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 45 },
    { student_id: 'HE190013', full_name: 'Trịnh Thu Quỳnh', email: 'quynh.tthe190013@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190014', full_name: 'Cao Đình Sang', email: 'sang.cdhe190014@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190015', full_name: 'Lâm Mỹ Tâm', email: 'tam.lmhe190015@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190016', full_name: 'Đinh Trọng Tấn', email: 'tan.dthe190016@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 110 },
    { student_id: 'HE190017', full_name: 'Mai Ngọc Ánh', email: 'anh.mnhe190017@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190018', full_name: 'Lương Quốc Bảo', email: 'bao.lqhe190018@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190019', full_name: 'Võ Thành Đạt', email: 'dat.vthe190019@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190020', full_name: 'Đoàn Nhật Hào', email: 'hao.dnhe190020@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 35 },
    { student_id: 'HE190021', full_name: 'Dương Thu Hằng', email: 'hang.dthe190021@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190022', full_name: 'Lý Gia Huy', email: 'huy.lghe190022@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190023', full_name: 'Tạ Minh Khang', email: 'khang.tmhe190023@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190024', full_name: 'Chu Hoàng Long', email: 'long.chhe190024@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 80 },
    { student_id: 'HE190025', full_name: 'Nông Thị Mai', email: 'mai.nthe190025@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190026', full_name: 'Hà Trọng Nhân', email: 'nhan.hthe190026@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190027', full_name: 'Quách Thị Phương', email: 'phuong.qthe190027@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190028', full_name: 'Bạch Thái Quân', email: 'quan.bthe190028@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 50 },
    { student_id: 'HE190029', full_name: 'Châu Minh Quân', email: 'quan.cmhe190029@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190030', full_name: 'Diệp Thảo Quyên', email: 'quyen.dthe190030@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190031', full_name: 'Huỳnh Tấn Tài', email: 'tai.hthe190031@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190032', full_name: 'Khổng Minh Trí', email: 'tri.kmhe190032@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 15 },
    { student_id: 'HE190033', full_name: 'Kiều Anh Tuấn', email: 'tuan.kathe190033@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190034', full_name: 'La Hải Đăng', email: 'dang.lhhe190034@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190035', full_name: 'Lục Đình Nguyên', email: 'nguyen.ldhe190035@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190036', full_name: 'Mạc Văn Khoa', email: 'khoa.mvhe190036@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 140 },
    { student_id: 'HE190037', full_name: 'Nghiêm Xuân Thành', email: 'thanh.nxthe190037@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190038', full_name: 'Phí Thị Thảo', email: 'thao.pthe190038@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190039', full_name: 'Sầm Bảo Ngọc', email: 'ngoc.sbhe190039@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190040', full_name: 'Thạch Hoàng Nam', email: 'nam.thhe190040@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 95 },
    { student_id: 'HE190041', full_name: 'Tiêu Ngọc Trâm', email: 'tram.tnthe190041@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190042', full_name: 'Uông Đình Trung', email: 'trung.udhe190042@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190043', full_name: 'Văn Tiến Dũng', email: 'dung.vthe190043@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190044', full_name: 'Vương Đình Huệ', email: 'hue.vdhe190044@fpt.edu.vn', status: 'ACTIVE', is_inside: true, card_status: 'ACTIVE', expiry: oneYearLater, insideSinceMinutes: 25 },
    { student_id: 'HE190045', full_name: 'Xa Thị Hạnh', email: 'hanh.xthe190045@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'EXPIRED', expiry: oneMonthAgo },
    { student_id: 'HE190046', full_name: 'Yên Quốc Việt', email: 'viet.yqhe190046@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'LOCKED', expiry: oneYearLater },
    { student_id: 'HE190047', full_name: 'Tạ Bích Loan', email: 'loan.tbhe190047@fpt.edu.vn', status: 'BLOCKED', is_inside: false, card_status: 'LOCKED', expiry: oneYearLater },
    { student_id: 'HE190048', full_name: 'Nguyễn Đình Thi', email: 'thi.ndhe190048@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190049', full_name: 'Trần Quốc Tuấn', email: 'tuan.tqhe190049@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190050', full_name: 'Lê Quý Đôn', email: 'don.lqhe190050@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190051', full_name: 'Phạm Ngũ Lão', email: 'lao.pnhe190051@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190052', full_name: 'Hoàng Diệu Linh', email: 'linh.hdhe190052@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
    { student_id: 'HE190053', full_name: 'Vũ Trọng Phụng', email: 'phung.vthe190053@fpt.edu.vn', status: 'ACTIVE', is_inside: false, card_status: 'ACTIVE', expiry: oneYearLater },
  ];

  let insideCount = 0;
  for (const s of sampleStudents) {
    const checkInTime = s.is_inside
      ? new Date(now.getTime() - (s.insideSinceMinutes || 30) * 60 * 1000)
      : null;

    if (s.is_inside) insideCount++;

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

    // Nếu đang is_inside = true, tạo / cập nhật CheckInLog với status INSIDE
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
    } else {
      // Đảm bảo không còn log dở dang nếu sinh viên đang ở ngoài
      await CheckInLog.deleteMany({ user_id: studentUser._id, status: 'INSIDE' });
    }

    console.log(
      `- [${s.student_id}] ${s.full_name.padEnd(20)} | User: ${s.status.padEnd(7)} | Thẻ: ${s.card_status.padEnd(7)} | Trong TV: ${s.is_inside ? 'CÓ (' + s.insideSinceMinutes + 'p)' : 'KHÔNG'}`
    );
  }

  console.log('\n====================================================');
  console.log(' SEED DATABASE HOÀN TẤT THÀNH CÔNG!');
  console.log('====================================================');
  console.log(`- 1 Admin:      ADMIN01 (admin@library.edu.vn / Admin@123)`);
  console.log(`- 3 Thủ thư:    LIB01, LIB02, LIB03 (Librarian@123)`);
  console.log(`- 53 Sinh viên: HE190001 -> HE190053 (Student@123)`);
  console.log(`- Đang có mặt:  ${insideCount} sinh viên đang ở trong thư viện`);
  console.log('====================================================\n');

  await mongoose.disconnect();
}

seed().catch((err) => {
  console.error('Seed thất bại:', err);
  process.exit(1);
});
