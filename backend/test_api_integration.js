/**
 * Automated API Integration Test Suite for LibIOG4 Backend
 * Chạy độc lập bằng lệnh: node test_api_integration.js
 */

const http = require('http');

const BASE_URL = process.env.API_URL || 'http://localhost:5000';
let adminToken = '';
let studentToken = '';

function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    let payload = null;
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'close',
    };

    if (body) {
      payload = JSON.stringify(body);
      headers['Content-Length'] = Buffer.byteLength(payload);
    }

    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      agent: false, // Tắt reuse socket để ngăn ngừa lỗi ECONNRESET giữa các test case tuần tự
      headers: headers,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        let parsed = null;
        try {
          parsed = JSON.parse(data);
        } catch (_) {
          parsed = data;
        }
        resolve({ status: res.statusCode, headers: res.headers, body: parsed });
      });
    });

    req.on('error', (err) => reject(err));

    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}

const tests = [];
function test(name, fn) {
  tests.push({ name, fn });
}

function expect(actual) {
  return {
    toBe(expected) {
      if (actual !== expected && Number(actual) !== Number(expected)) {
        throw new Error(`Expected ${JSON.stringify(expected)} (${typeof expected}) but received ${JSON.stringify(actual)} (${typeof actual})`);
      }
    },
    toBeDefined() {
      if (actual === undefined || actual === null) throw new Error(`Expected value to be defined`);
    },
    toContain(sub) {
      if (!String(actual).includes(sub)) throw new Error(`Expected "${actual}" to contain "${sub}"`);
    },
  };
}

// -----------------------------------------------------------------
// 1. Health check & Public endpoints
// -----------------------------------------------------------------
test('INT-API-01: GET /api/health trả về 200 OK và trạng thái hoạt động', async () => {
  const res = await request('GET', '/api/health');
  expect(res.status).toBe(200);
  expect(res.body.status).toBe('ok');
});

test('INT-API-02: GET /api/config trả về cấu hình công khai (Không cần auth)', async () => {
  const res = await request('GET', '/api/config');
  expect(res.status).toBe(200);
  expect(res.body.success).toBe(true);
  expect(res.body.data.maxCapacity).toBeDefined();
});

// -----------------------------------------------------------------
// 2. Authentication & Authorization (RBAC)
// -----------------------------------------------------------------
test('INT-API-03: POST /api/auth/login từ chối khi sai mật khẩu (401 Unauthorized)', async () => {
  const res = await request('POST', '/api/auth/login', {
    studentId: 'ADMIN01',
    password: 'WrongPassword123',
  });
  expect(res.status).toBe(401);
});

test('INT-API-04: POST /api/auth/login đăng nhập Admin thành công và cấp JWT', async () => {
  const res = await request('POST', '/api/auth/login', {
    studentId: 'ADMIN01',
    password: 'Admin@123',
  });
  expect(res.status).toBe(200);
  expect(res.body.success).toBe(true);
  expect(res.body.data.accessToken).toBeDefined();
  adminToken = res.body.data.accessToken;
});

test('INT-API-05: POST /api/auth/login đăng nhập Sinh viên thành công', async () => {
  const res = await request('POST', '/api/auth/login', {
    studentId: 'HE190001',
    password: 'Student@123',
  });
  expect(res.status).toBe(200);
  expect(res.body.success).toBe(true);
  studentToken = res.body.data.accessToken;
});

// -----------------------------------------------------------------
// 3. Security & RBAC Guard
// -----------------------------------------------------------------
test('INT-API-06: Chặn Sinh viên truy cập API Admin /api/admin/realtime/stats (403 Forbidden)', async () => {
  const res = await request('GET', '/api/admin/realtime/stats', null, studentToken);
  expect(res.status).toBe(403);
});

test('INT-API-07: Cho phép Admin truy cập /api/admin/realtime/stats (200 OK)', async () => {
  const res = await request('GET', '/api/admin/realtime/stats', null, adminToken);
  expect(res.status).toBe(200);
  expect(res.body.success).toBe(true);
  expect(res.body.data.currentOccupancy).toBeDefined();
});

// -----------------------------------------------------------------
// 4. Hot Config Update (FR-03)
// -----------------------------------------------------------------
test('INT-API-08: PUT /api/admin/config cập nhật sức chứa tức thì không cần restart', async () => {
  const res = await request(
    'PUT',
    '/api/admin/config',
    {
      maxCapacity: 150,
      openTime: '07:30',
      closeTime: '21:30',
    },
    adminToken
  );
  expect(res.status).toBe(200);
  expect(res.body.success).toBe(true);
  expect(res.body.data.maxCapacity).toBe(150);
});

// -----------------------------------------------------------------
// 5. Offline Sync Endpoint (FR-02 & Offline Resilience)
// -----------------------------------------------------------------
test('INT-API-09: POST /api/checkin/sync tiếp nhận mảng nhật ký ngoại tuyến hợp lệ', async () => {
  const offlineLogs = [
    {
      local_id: 'offline_local_uuid_' + Date.now(),
      student_id: 'HE190001',
      check_in_time: new Date().toISOString(),
      action_type: 'CHECK_IN',
    },
  ];

  const res = await request('POST', '/api/checkin/sync', { logs: offlineLogs }, adminToken);
  expect(res.status).toBe(200);
  expect(res.body.success).toBe(true);
});

// -----------------------------------------------------------------
// Runner
// -----------------------------------------------------------------
async function run() {
  console.log('====================================================');
  console.log('BẮT ĐẦU CHẠY API INTEGRATION TEST SUITE (LIBIOG4)');
  console.log(`Endpoint mục tiêu: ${BASE_URL}`);
  console.log('====================================================\n');

  let passed = 0;
  let failed = 0;

  for (const t of tests) {
    try {
      await t.fn();
      console.log(`[PASS] ${t.name}`);
      passed++;
    } catch (err) {
      console.log(`[FAIL] ${t.name}`);
      console.log(`       Lỗi: ${err.message}\n`);
      failed++;
    }
  }

  console.log('\n====================================================');
  console.log(`TỔNG KẾT: ${passed}/${tests.length} TEST CASES PASS (${Math.round((passed / tests.length) * 100)}%)`);
  if (failed > 0) {
    console.log(`LƯU Ý: Có ${failed} test case thất bại. Đảm bảo backend đang chạy tại port 5000 và đã seed DB.`);
  } else {
    console.log('TẤT CẢ CÁC LUỒNG API TÍCH HỢP HOẠT ĐỘNG HOÀN HẢO 100%!');
  }
  console.log('====================================================\n');
}

run();
