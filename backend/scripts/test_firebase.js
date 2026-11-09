const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');

const keyPath = path.resolve(__dirname, '../firebase-service-account.json');

console.log('----------------------------------------------------');
console.log('KIỂM TRA CẤU HÌNH FIREBASE ADMIN SDK (BACKEND)');
console.log('----------------------------------------------------');

if (!fs.existsSync(keyPath)) {
  console.error('❌ KHÔNG TÌM THẤY file: backend/firebase-service-account.json');
  process.exit(1);
}

try {
  const serviceAccount = require(keyPath);
  console.log(`✅ Đã tìm thấy file Service Account Key!`);
  console.log(`   - Project ID: ${serviceAccount.project_id}`);
  console.log(`   - Client Email: ${serviceAccount.client_email}`);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log('✅ Khởi tạo Firebase Admin SDK thành công!');

  const targetToken = process.argv[2];
  if (!targetToken) {
    console.log('\n💡 Để gửi thử 1 thông báo thực tế đến điện thoại:');
    console.log('   node scripts/test_firebase.js <DEVICE_TOKEN>');
    console.log('\n(Lấy DEVICE_TOKEN khi chạy app Flutter trên máy ảo/điện thoại thật)');
    process.exit(0);
  }

  console.log(`\n🚀 Đang gửi thông báo thử nghiệm tới device token: ${targetToken.substring(0, 15)}...`);

  admin.messaging().send({
    token: targetToken.trim(),
    notification: {
      title: '🔔 Test Firebase Thành Công!',
      body: 'Hệ thống LibIOG4 đã kết nối Firebase Cloud Messaging thành công.',
    },
    data: {
      type: 'TEST_NOTIFICATION',
      time: new Date().toISOString(),
    },
  }).then((res) => {
    console.log('🎉 GỬI THÀNH CÔNG! Message ID:', res);
    process.exit(0);
  }).catch((err) => {
    console.error('❌ GỬI THẤT BẠI:', err.message);
    process.exit(1);
  });
} catch (e) {
  console.error('❌ Lỗi khi khởi tạo Firebase:', e.message);
  process.exit(1);
}
