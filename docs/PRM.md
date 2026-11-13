## PHÂN TÍCH VAI TRÒ NGƯỜI DÙNG (USER ROLES & RBAC)

1. #### Sinh viên (STUDENT):
   - Đăng ký / Đăng nhập tài khoản cá nhân.
   - Thẻ sinh viên điện tử hiển thị mã QR động (`LIB:MSSV:ID:EXP`), tự động đổi màu/trạng thái thời gian thực khi đang ở trong (`is_inside = true`) hoặc ngoài thư viện (`is_inside = false`).
   - Quét mã QR tại trạm hoặc xuất trình mã QR để ghi nhận lượt ra/vào.
   - Xem lịch sử cá nhân: chi tiết từng phiên ra/vào và tổng thời gian lưu trú tại thư viện.
   - Nhận thông báo tự động (thông báo nhắc giờ đóng cửa, xác nhận check-in/out thành công).

2. #### Thủ thư (LIBRARIAN):
   - Vận hành trạm quét thẻ (QR Scanner Station) bằng camera hoặc nhập tay mã số sinh viên dự phòng khi camera lỗi/mã QR mờ.
   - Theo dõi danh sách sinh viên đang có mặt theo thời gian thực (Live Occupancy), bộ đếm sức chứa, hỗ trợ tìm kiếm và cưỡng chế check-out (Forced Check-out) tại chỗ.
   - Tra cứu danh sách thành viên, xem chi tiết thẻ và thực hiện khóa / mở khóa thẻ sinh viên (đồng bộ `users.status` và `library_cards.status`).
   - Xem biểu đồ thống kê lượng người ra vào (theo Giờ/Ngày/Tuần) và xuất file báo cáo (CSV).
   - *Ràng buộc quyền hạn:* Không có quyền xóa tài khoản người dùng, không có quyền chỉnh sửa cấu hình hệ thống.

3. #### Quản trị viên (ADMIN):
   - Kế thừa toàn bộ quyền hạn và màn hình của Thủ thư.
   - Quản lý danh sách thành viên toàn quyền: thêm mới cán bộ/thủ thư, chỉnh sửa thông tin, phân quyền vai trò (`STUDENT`, `LIBRARIAN`, `ADMIN`), khóa thẻ và xóa mềm tài khoản (`deleted_at`).
   - Quản trị cấu hình động hệ thống (System Configs): Sức chứa tối đa, giờ mở/đóng cửa, thời gian cảnh báo quá hạn, kích hoạt chế độ bảo trì nóng mà không cần dừng server hay re-deploy.

#### Yêu cầu chức năng (Functional Requirements - FR)

- **FR-01: Quản lý Tài khoản & Xác thực:** Đăng ký, Đăng nhập (Sinh viên / Admin Thư viện), Đổi mật khẩu, Phân quyền người dùng.
- **FR-02: Ghi nhận Check-in / Check-out:**
  - Sinh viên tạo/quét mã QR để ghi nhận thời gian vào và ra.
  - Hệ thống kiểm tra điều kiện (Thẻ còn hạn, thư viện còn chỗ, thời gian hợp lệ).
- **FR-03: Cấu hình hệ thống:** Admin có thể thay đổi số lượng chỗ ngồi tối đa, giờ mở/đóng cửa, thời gian cảnh báo quá hạn trực tiếp từ ứng dụng mà không cần re-deploy.
- **FR-04: Thống kê & Báo cáo:** Hiển thị biểu đồ lượng người ra vào theo khung giờ/ngày/tuần. Xuất báo cáo danh sách.
- **FR-05: Thông báo Đẩy (Push Notifications via FCM):** Gửi thông báo tức thì qua Firebase Cloud Messaging (FCM) đến điện thoại sinh viên khi check-in/out thành công (chống quét trộm mã), khi thẻ bị khóa/mở khóa, cảnh báo trước giờ đóng cửa theo cấu hình hệ thống, và nhắc nhở thẻ sắp hết hạn.
- **FR-06: Lịch sử ra vào:** Sinh viên tự xem lại lịch sử ra vào và tổng thời gian sử dụng thư viện của mình.

### TÓM TẮT VAI TRÒ CÁC THÀNH PHẦN

1. **Khối Client (Flutter App):**
   - **Multi-platform:** Chạy đồng nhất trên Mobile (Android/iOS), Web, Desktop.
   - **Real-time State Management:** Dùng BLoC/Provider để cập nhật tức thì giao diện Thẻ điện tử (đổi màu/trạng thái khi đang ở trong thư viện) và Dashboard của Thủ thư.
2. **Khối Xử lý Offline/Online:**
   - Sử dụng cơ chế bất đồng bộ (async/await, Stream) kết hợp cơ sở dữ liệu local (SQLite) giúp ứng dụng vẫn có thể ghi nhận lượt ra vào bình thường ngay cả khi trạm quét bị mất mạng tạm thời.
3. **Khối Quản trị Cấu hình Động (SYSTEM_CONFIGS):**
   - Giúp Thủ thư/Admin có thể thay đổi ngay lập tức giới hạn sức chứa, giờ mở/đóng cửa trên ứng dụng mà **không cần dừng server hay re-deploy ứng dụng**.
4. **Khối Thông Báo Đẩy Thời Gian Thực (Firebase Cloud Messaging - FCM):**
   - Backend Node.js tích hợp `firebase-admin` SDK, gửi thông báo đẩy bất đồng bộ (push notification) trực tiếp đến ứng dụng di động Flutter thông qua `device_token` lưu trong collection `users`.
   - Tiết kiệm tài nguyên và pin thiết bị (không cần duy trì kết nối WebSocket thường trực), đảm bảo sinh viên nhận cảnh báo an ninh tài khoản ngay cả khi ứng dụng đang đóng hoặc chạy ngầm.

---

## KIẾN TRÚC MÀN HÌNH THEO VAI TRÒ (SCREEN ARCHITECTURE)

Hệ thống được thiết kế giao diện theo 3 phân hệ tương ứng với 3 vai trò người dùng:

```
[Khởi động / Splash]
        │
   [LoginScreen] ── (Đăng nhập & Giải mã Role từ JWT)
        ├── Role 'STUDENT'   ──► [StudentHomeScreen] (App Sinh viên)
        │                            ├── Thẻ sinh viên điện tử (QR Code + Live Badge)
        │                            ├── Lịch sử ra vào cá nhân (StudentHistoryScreen)
        │                            └── Thông tin cá nhân & Đổi mật khẩu
        │
        ├── Role 'LIBRARIAN' ──► [LibrarianDashboardScreen] (Trạm làm việc Thủ thư)
        │                            ├── Tab 1: Trạm quét QR & Nhập tay (QrScannerTab)
        │                            ├── Tab 2: Giám sát realtime (LiveOccupancyTab)
        │                            ├── Tab 3: Tra cứu & Khóa thẻ (UserManagementTab - View/Lock)
        │                            └── Tab 4: Thống kê & Báo cáo (ReportTab)
        │
        └── Role 'ADMIN'     ──► [AdminDashboardScreen] (Bàn điều hành Quản trị)
                                     ├── Kế thừa 4 Tabs của Librarian (kèm quyền Xóa user)
                                     └── Tab 5: Cấu hình động hệ thống (SystemConfigTab)
```

### 1. Phân hệ Chung (Authentication)
* **`LoginScreen` (Màn hình Đăng nhập):**
  - Nhập Email / Mã số sinh viên và Mật khẩu.
  - Gọi API `/api/auth/login`, nhận JWT Token (access token & refresh token).
  - Tự động điều hướng theo `role`:
    - `STUDENT` $\rightarrow$ Mở `StudentHomeScreen`.
    - `LIBRARIAN` $\rightarrow$ Mở `LibrarianDashboardScreen` (hoặc `AdminDashboardScreen` ở chế độ giới hạn quyền).
    - `ADMIN` $\rightarrow$ Mở `AdminDashboardScreen` (toàn quyền).
* **`RegisterScreen` (Màn hình Đăng ký):**
  - Đăng ký tài khoản Sinh viên mới (MSSV, Họ tên, Email `@fpt.edu.vn`, Mật khẩu, Số điện thoại).

### 2. Phân hệ Sinh viên (Student Mobile App)
* **`StudentHomeScreen` (Trang chủ & Thẻ sinh viên điện tử):**
  - **Thẻ điện tử (E-Card):** Hiển thị Avatar, Họ tên, Mã số sinh viên, Khoa/Ngành.
  - **Mã QR cá nhân động:** Render mã QR định dạng chuẩn `LIB:{student_id}:{card_id}:{expireEpochSeconds}`, có nút làm mới và tự động cập nhật.
  - **Badge vị trí thời gian thực (`is_inside`):**
    - Đổi sang màu **Xanh lá cây** khi sinh viên đang ở trong thư viện (`is_inside = true`), hiển thị thời gian đã ngồi tại thư viện.
    - Đổi sang màu **Xám** khi sinh viên đang ở bên ngoài (`is_inside = false`).
  - **Trạng thái thẻ:** Hiển thị thẻ `ACTIVE`, cảnh báo khi thẻ `EXPIRED` hoặc `LOCKED`.
* **`StudentHistoryScreen` (Màn hình Lịch sử ra vào):**
  - Danh sách nhật ký quét thẻ cá nhân (ngày giờ check-in, ngày giờ check-out, thời lượng lưu lại tính theo phút).
  - Thống kê tổng số giờ sinh viên đã tự học tại thư viện trong tháng.
* **`StudentProfileScreen` (Hồ sơ cá nhân & Đổi mật khẩu):**
  - Xem và cập nhật số điện thoại, đổi mật khẩu tài khoản (`PUT /api/auth/change-password`).

### 3. Phân hệ Thủ thư (Librarian Station Dashboard)
* **`LibrarianDashboardScreen` (Bàn làm việc trạm kiểm soát):** Thiết kế dạng đa Tab (Bottom Navigation hoặc Navigation Rail):
  * **Tab 1: `QrScannerTab` (Trạm quét QR & Nhập tay dự phòng):**
    - Quét mã QR thẻ sinh viên qua Camera thiết bị.
    - **Ô nhập tay MSSV dự phòng:** Hỗ trợ thủ thư nhập trực tiếp mã sinh viên khi camera hỏng hoặc màn hình điện thoại sinh viên bị nứt vỡ.
    - **Popup kết quả:** Hiển thị tức thì ảnh, họ tên, MSSV, hành động (CHECK-IN / CHECK-OUT), kèm hiệu ứng màu (Xanh: Thành công, Đỏ: Lỗi/Thẻ bị khóa/Quá tải).
    - **Chỉ báo trạng thái mạng:** Icon Online (xanh) / Offline (vàng), hàng đợi log offline chưa gửi và nút ép buộc đồng bộ (`Sync`).
  * **Tab 2: `LiveOccupancyTab` (Giám sát người có mặt realtime):**
    - Bộ đếm sức chứa trực quan: Số lượng đang có mặt / Sức chứa tối đa (Vd: `142 / 200`), thanh tỷ lệ phần trăm lấp đầy.
    - Danh sách sinh viên đang ở trong thư viện: Ảnh đại diện, MSSV, họ tên, giờ vào, số phút đã ở.
    - Thanh tìm kiếm nhanh sinh viên theo tên hoặc MSSV.
    - **Nút Cưỡng chế Check-out (Forced Check-out):** Cho phép thủ thư quẹt thẻ ra hộ khi sinh viên quên không check-out trước khi về.
  * **Tab 3: `UserManagementTab` (Tra cứu & Khóa thẻ - Chế độ Thủ thư):**
    - Danh sách thành viên, phân trang, bộ lọc trạng thái (`ACTIVE`, `BLOCKED`).
    - Tìm kiếm nhanh theo MSSV, Email, Tên.
    - **Switch Khóa / Mở khóa thẻ:** Thủ thư khóa thẻ khi sinh viên vi phạm nội quy thư viện.
    - *(Ẩn nút Xóa người dùng và Ẩn phân quyền Admin).*
  * **Tab 4: `ReportStatsTab` (Thống kê & Xuất báo cáo):**
    - Biểu đồ số lượng lượt ra vào trực quan bằng thư viện `fl_chart` (lọc theo Khung giờ trong ngày, theo Ngày trong tuần, hoặc theo Tuần).
    - Thống kê số giờ cao điểm và tổng lượt phục vụ.
    - Nút **Xuất CSV** (hỗ trợ UTF-8 có BOM để mở tiếng Việt trên Microsoft Excel không bị lỗi font).

### 4. Phân hệ Quản trị viên (Admin Management Console)
* **`AdminDashboardScreen` (Bàn điều hành Quản trị viên):**
  - Tích hợp toàn bộ 4 Tab của Thủ thư, đồng thời mở rộng thêm các tính năng quản trị cấp cao:
  * **Tab `UserManagementTab` (Chế độ Admin toàn quyền):**
    - Thêm tài khoản thành viên mới / cấp tài khoản Thủ thư (`POST /api/admin/users`).
    - Chỉnh sửa thông tin thành viên, gán quyền Role (`STUDENT`, `LIBRARIAN`, `ADMIN`).
    - Khóa / Mở khóa thẻ (`PATCH /api/admin/users/:id/status`).
    - **Xóa mềm tài khoản:** Nút Xóa thành viên (`DELETE /api/admin/users/:id`), chỉ Admin mới có quyền thực hiện.
  * **Tab `SystemConfigTab` (Cấu hình động hệ thống):**
    - Điều chỉnh Sức chứa tối đa (`MAX_CAPACITY`).
    - Điều chỉnh Giờ mở cửa (`OPEN_TIME`) và Giờ đóng cửa (`CLOSE_TIME`).
    - Điều chỉnh Số phút cảnh báo trước khi đóng cửa (`WARNING_MINUTES_BEFORE_CLOSE`).
    - Điều chỉnh Thời gian lưu trú tối đa một phiên (`MAX_SESSION_HOURS`).
    - Bật/Tắt Chế độ bảo trì hệ thống (`MAINTENANCE_MODE`) và nhập Lời nhắn bảo trì (`MAINTENANCE_MESSAGE`).
    - Lưu cấu hình nóng trực tiếp vào cơ sở dữ liệu (`PUT /api/admin/config`), có hiệu lực tức thì mà không cần restart server hay re-deploy app.

---

## DATABASE SCHEMA (MongoDB — Mongoose Models)

### Collection 1: `roles` (Phân quyền người dùng)

| Field        | Type   | Constraint                          |
|-------------|--------|-------------------------------------|
| `_id`        | ObjectId | PK (auto)                         |
| `role_name`  | String | required, unique, enum: `STUDENT`, `LIBRARIAN`, `ADMIN` |
| `description`| String | default: `''`                      |
| `created_at` | Date   | auto (timestamps)                   |
| `updated_at` | Date   | auto (timestamps)                   |

**Virtuals:** `roleName` → `role_name`

```json
{
  "_id": "ObjectId('65a1bc1f...')",
  "role_name": "STUDENT",
  "description": "Sinh viên / Độc giả thư viện"
}
```

---

### Collection 2: `users` (Tài khoản & Trạng thái Vị trí Real-time)

| Field          | Type      | Constraint                                  |
|---------------|-----------|---------------------------------------------|
| `_id`          | ObjectId  | PK (auto)                                   |
| `student_id`   | String    | required, unique, index                     |
| `full_name`    | String    | required                                    |
| `email`        | String    | required, unique, lowercase, index          |
| `password_hash`| String    | required                                    |
| `phone`        | String    | default: `''`                               |
| `role_id`      | ObjectId  | FK → `roles`, required, index               |
| `status`       | String    | enum: `ACTIVE`, `BLOCKED`, default: `ACTIVE`, index |
| `is_inside`    | Boolean   | default: `false`, index                     |
| `last_check_in`| Date      | default: `null`                             |
| `avatar_url`   | String    | default: `''`                               |
| `device_token` | String    | default: `''`                               |
| `refresh_token`| String    | default: `''`                               |
| `deleted_at`   | Date      | default: `null`, index (soft-delete)        |
| `created_at`   | Date      | auto (timestamps)                           |
| `updated_at`   | Date      | auto (timestamps)                           |

**Virtuals:** `studentId`, `name`, `password`, `passwordHash`, `isInsideLibrary`, `avatarUrl`, `deviceToken`, `refreshToken`, `deletedAt`, `roleId`, `role` (computed từ `role_id.role_name`)

**Methods:** `toSafeObject()` — trả về object camelCase đã ẩn `password_hash`, `refresh_token`.

```json
{
  "_id": "ObjectId('65a1bc2f...')",
  "student_id": "HE150000",
  "full_name": "Nguyễn Văn A",
  "email": "anv@fpt.edu.vn",
  "password_hash": "$2b$10$...",
  "phone": "0987654321",
  "role_id": "ObjectId('65a1bc1f...')",
  "status": "ACTIVE",
  "is_inside": false,
  "last_check_in": "2026-10-19T08:00:00Z",
  "avatar_url": "",
  "device_token": "",
  "refresh_token": "",
  "deleted_at": null,
  "created_at": "2026-10-19T08:00:00Z",
  "updated_at": "2026-10-19T08:00:00Z"
}
```

---

### Collection 3: `library_cards` (Thẻ Thư viện Điện tử — QR mã hóa)

| Field          | Type      | Constraint                         |
|---------------|-----------|-------------------------------------|
| `_id`          | ObjectId  | PK (auto)                          |
| `user_id`      | ObjectId  | FK → `users`, required, index      |
| `qr_code_hash` | String   | required, unique                    |
| `issue_date`   | Date      | required, default: `Date.now`      |
| `expiry_date`  | Date      | required                            |
| `status`       | String    | enum: `ACTIVE`, `EXPIRED`, `LOCKED`, default: `ACTIVE` |
| `created_at`   | Date      | auto (timestamps)                   |
| `updated_at`   | Date      | auto (timestamps)                   |

**Methods:** `isExpired()` — kiểm tra thẻ hết hạn.

**Virtuals:** `userId`, `qrCodeHash`, `issueDate`, `expiryDate`

```json
{
  "_id": "ObjectId('65a1bc3f...')",
  "user_id": "ObjectId('65a1bc2f...')",
  "qr_code_hash": "hash_secure_string_abc123",
  "issue_date": "2026-10-01T00:00:00Z",
  "expiry_date": "2027-10-01T23:59:59Z",
  "status": "ACTIVE"
}
```

---

### Collection 4: `gates` (Danh mục Cổng / Trạm quét)

| Field        | Type      | Constraint                                       |
|-------------|-----------|---------------------------------------------------|
| `_id`        | ObjectId  | PK (auto)                                        |
| `gate_name`  | String    | required, unique                                 |
| `location`   | String    | default: `''`                                    |
| `status`     | String    | enum: `ACTIVE`, `INACTIVE`, `MAINTENANCE`, default: `ACTIVE` |
| `created_at` | Date      | auto (timestamps)                                |
| `updated_at` | Date      | auto (timestamps)                                |

**Virtuals:** `gateName`

```json
{
  "_id": "ObjectId('65a1bc4f...')",
  "gate_name": "Cổng chính Tầng 1",
  "location": "Sảnh tòa Alpha",
  "status": "ACTIVE"
}
```

---

### Collection 5: `check_in_logs` (Nhật ký Ra / Vào & Offline Sync)

| Field            | Type      | Constraint                                   |
|-----------------|-----------|-----------------------------------------------|
| `_id`            | ObjectId  | PK (auto)                                    |
| `user_id`        | ObjectId  | FK → `users`, required, index                |
| `card_id`        | ObjectId  | FK → `library_cards`, default: `null`, index  |
| `gate_id`        | ObjectId  | FK → `gates`, default: `null`, index          |
| `check_in_time`  | Date      | required, index                               |
| `check_out_time` | Date      | default: `null`                               |
| `total_minutes`  | Number    | default: `null` (auto-calc on check-out)      |
| `action_type`    | String    | enum: `CHECK_IN`, `CHECK_OUT`, default: `CHECK_IN` |
| `status`         | String    | enum: `INSIDE`, `COMPLETED`, default: `INSIDE`, index |
| `sync_status`    | String    | enum: `SYNCED`, `PENDING`, default: `SYNCED`, index |
| `local_id`       | String    | default: `''`, index (ID tạm từ offline client) |
| `created_at`     | Date      | auto (timestamps)                             |
| `updated_at`     | Date      | auto (timestamps)                             |

**Compound Indexes:**
- `{ user_id: 1, check_in_time: -1 }` — truy vấn lịch sử theo user
- `{ check_in_time: -1, status: 1 }` — truy vấn báo cáo theo thời gian

**Pre-save Hook:** Khi `check_out_time` có giá trị → tự động tính `total_minutes`, set `status = 'COMPLETED'`, `action_type = 'CHECK_OUT'`.

**Virtuals:** `userId`, `cardId`, `gateId`, `checkInTime`, `checkOutTime`, `durationMinutes`, `totalMinutes`, `actionType`, `syncStatus`, `localId`

```json
{
  "_id": "ObjectId('65a1bc5f...')",
  "user_id": "ObjectId('65a1bc2f...')",
  "card_id": "ObjectId('65a1bc3f...')",
  "gate_id": "ObjectId('65a1bc4f...')",
  "check_in_time": "2026-10-19T08:30:00Z",
  "check_out_time": "2026-10-19T11:30:00Z",
  "total_minutes": 180,
  "action_type": "CHECK_OUT",
  "status": "COMPLETED",
  "sync_status": "SYNCED",
  "local_id": "",
  "created_at": "2026-10-19T08:30:00Z",
  "updated_at": "2026-10-19T11:30:00Z"
}
```

---

### Collection 6: `system_configs` (Cấu hình Động Hệ thống)

| Field          | Type   | Constraint                                       |
|---------------|--------|---------------------------------------------------|
| `_id`          | ObjectId | PK (auto)                                      |
| `config_key`   | String | required, unique, index                          |
| `config_value` | String | required                                         |
| `data_type`    | String | enum: `INT`, `STRING`, `TIME`, `BOOLEAN`, default: `STRING` |
| `description`  | String | default: `''`                                    |
| `updated_at`   | Date   | default: `Date.now`, auto (timestamps)           |
| `created_at`   | Date   | auto (timestamps)                                |

**Virtuals:** `key`, `value`, `configKey`, `configValue`, `dataType`

**Statics:** `seedDefaults()` — Khởi tạo 8 config mặc định (+ 8 alias camelCase cho tương thích ngược).

**Dữ liệu Seed mặc định:**

| config_key                       | config_value | data_type | Mô tả                                  |
|---------------------------------|--------------|-----------|------------------------------------------|
| `MAX_CAPACITY`                   | `200`        | INT       | Sức chứa tối đa của thư viện            |
| `OPEN_TIME`                      | `07:30`      | TIME      | Giờ mở cửa thư viện                     |
| `CLOSE_TIME`                     | `21:30`      | TIME      | Giờ đóng cửa thư viện                   |
| `WARNING_MINUTES_BEFORE_CLOSE`   | `15`         | INT       | Số phút cảnh báo trước khi đóng cửa     |
| `MAX_SESSION_HOURS`              | `8`          | INT       | Số giờ tối đa cho một phiên truy cập    |
| `ALLOWED_DAYS`                   | `Mon,Tue,Wed,Thu,Fri,Sat` | STRING | Các ngày mở cửa trong tuần       |
| `MAINTENANCE_MODE`               | `false`      | BOOLEAN   | Trạng thái bảo trì hệ thống            |
| `MAINTENANCE_MESSAGE`            | *(rỗng)*     | STRING    | Nội dung thông báo bảo trì             |

```json
{
  "_id": "ObjectId('65a1bc6f...')",
  "config_key": "MAX_CAPACITY",
  "config_value": "200",
  "data_type": "INT",
  "description": "Sức chứa tối đa của thư viện",
  "updated_at": "2026-10-19T00:00:00Z"
}
```

---

## KHỞI TẠO DATABASE (MongoDB Shell)

```javascript
// 1. Chuyển sang/tạo cơ sở dữ liệu mới
use library_access_system;

// 2. Tạo các Collections
db.createCollection("roles");
db.createCollection("users");
db.createCollection("library_cards");
db.createCollection("gates");
db.createCollection("check_in_logs");
db.createCollection("system_configs");

// 3. Tạo Indexes tối ưu hiệu năng truy vấn
db.users.createIndex({ "student_id": 1 }, { unique: true });
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "is_inside": 1 });
db.users.createIndex({ "status": 1 });
db.users.createIndex({ "role_id": 1 });
db.users.createIndex({ "deleted_at": 1 });

db.library_cards.createIndex({ "qr_code_hash": 1 }, { unique: true });
db.library_cards.createIndex({ "user_id": 1 });

db.check_in_logs.createIndex({ "user_id": 1 });
db.check_in_logs.createIndex({ "check_in_time": 1 });
db.check_in_logs.createIndex({ "status": 1 });
db.check_in_logs.createIndex({ "sync_status": 1 });
db.check_in_logs.createIndex({ "local_id": 1 });
db.check_in_logs.createIndex({ "user_id": 1, "check_in_time": -1 });
db.check_in_logs.createIndex({ "check_in_time": -1, "status": 1 });

db.system_configs.createIndex({ "config_key": 1 }, { unique: true });

// 4. Khởi tạo Roles mặc định
db.roles.insertMany([
  { "role_name": "STUDENT", "description": "Sinh viên / Độc giả" },
  { "role_name": "LIBRARIAN", "description": "Thủ thư quản lý" },
  { "role_name": "ADMIN", "description": "Quản trị viên hệ thống" }
]);

// 5. Khởi tạo Dữ liệu Cấu hình Động ban đầu
db.system_configs.insertMany([
  {
    "config_key": "MAX_CAPACITY",
    "config_value": "200",
    "data_type": "INT",
    "description": "Sức chứa tối đa của thư viện",
    "updated_at": new Date()
  },
  {
    "config_key": "OPEN_TIME",
    "config_value": "07:30",
    "data_type": "TIME",
    "description": "Giờ mở cửa hàng ngày",
    "updated_at": new Date()
  },
  {
    "config_key": "CLOSE_TIME",
    "config_value": "21:30",
    "data_type": "TIME",
    "description": "Giờ đóng cửa hàng ngày",
    "updated_at": new Date()
  },
  {
    "config_key": "WARNING_MINUTES_BEFORE_CLOSE",
    "config_value": "30",
    "data_type": "INT",
    "description": "Số phút cảnh báo trước khi đóng cửa",
    "updated_at": new Date()
  },
  {
    "config_key": "MAX_SESSION_HOURS",
    "config_value": "8",
    "data_type": "INT",
    "description": "Số giờ tối đa cho một phiên truy cập",
    "updated_at": new Date()
  },
  {
    "config_key": "ALLOWED_DAYS",
    "config_value": "Mon,Tue,Wed,Thu,Fri,Sat",
    "data_type": "STRING",
    "description": "Các ngày mở cửa trong tuần",
    "updated_at": new Date()
  },
  {
    "config_key": "MAINTENANCE_MODE",
    "config_value": "false",
    "data_type": "BOOLEAN",
    "description": "Trạng thái bảo trì hệ thống",
    "updated_at": new Date()
  },
  {
    "config_key": "MAINTENANCE_MESSAGE",
    "config_value": "Thư viện đang tạm thời bảo trì, vui lòng quay lại sau.",
    "data_type": "STRING",
    "description": "Nội dung thông báo bảo trì",
    "updated_at": new Date()
  }
]);
```

---

## KẾT NỐI DATABASE (db.js)

```javascript
// db.js
const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect('mongodb://127.0.0.1:27017/library_access_system', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
```

---

## API ROUTES

### Auth Routes (`/api/auth`)

| Method | Endpoint              | Auth | Mô tả                  |
|--------|-----------------------|------|--------------------------|
| POST   | `/api/auth/register`  | ✗    | Đăng ký tài khoản mới   |
| POST   | `/api/auth/login`     | ✗    | Đăng nhập               |
| POST   | `/api/auth/refresh`   | ✗    | Refresh JWT token        |
| POST   | `/api/auth/logout`    | ✓    | Đăng xuất               |
| PUT    | `/api/auth/change-password` | ✓ | Đổi mật khẩu         |

### User Routes (`/api/users`) — Sinh viên tự quản lý

| Method | Endpoint                     | Auth | Mô tả                         |
|--------|------------------------------|------|--------------------------------|
| GET    | `/api/users/me`              | ✓    | Lấy thông tin cá nhân         |
| GET    | `/api/users/me/qr`           | ✓    | Lấy mã QR thẻ thư viện       |
| PUT    | `/api/users/me`              | ✓    | Cập nhật thông tin cá nhân    |
| POST   | `/api/users/register-device` | ✓    | Đăng ký device token (push notification) |

### History Routes (`/api/history`) — Lịch sử ra vào

| Method | Endpoint            | Auth | Mô tả                         |
|--------|---------------------|------|--------------------------------|
| GET    | `/api/history/me`   | ✓    | Sinh viên xem lịch sử ra vào  |

### Check-in Routes (`/api/checkin`) — Trạm quét

| Method | Endpoint                    | Auth | Role             | Mô tả                          |
|--------|----------------------------|------|------------------|---------------------------------|
| POST   | `/api/checkin`              | ✓    | LIBRARIAN, ADMIN | Ghi nhận check-in/check-out     |
| POST   | `/api/checkin/sync`         | ✓    | LIBRARIAN, ADMIN | Đồng bộ log offline             |
| GET    | `/api/checkin/current-status`| ✓   | Tất cả           | Kiểm tra trạng thái đang có mặt |

### Config Routes (`/api/config`) — Cấu hình hệ thống

| Method | Endpoint         | Auth | Role  | Mô tả                    |
|--------|------------------|------|-------|---------------------------|
| GET    | `/api/config`    | ✓    | Tất cả | Đọc cấu hình hệ thống   |
| PUT    | `/api/config`    | ✓    | ADMIN | Cập nhật cấu hình        |

### Admin Routes (`/api/admin`) — Quản trị (yêu cầu ADMIN hoặc LIBRARIAN)

**Quản lý cổng / trạm quét:**

| Method | Endpoint              | Auth | Role             | Mô tả                         |
|--------|-----------------------|------|------------------|-------------------------------|
| GET    | `/api/admin/gates`    | ✓    | LIBRARIAN, ADMIN | Xem danh sách và trạng thái cổng |
| POST   | `/api/admin/gates`    | ✓    | ADMIN            | Tạo cổng mới                  |
| PATCH  | `/api/admin/gates/:id`| ✓    | ADMIN            | Cập nhật tên, vị trí, trạng thái |

**Quản lý thành viên:**

| Method | Endpoint                        | Auth | Role             | Mô tả                      |
|--------|---------------------------------|------|------------------|-----------------------------|
| GET    | `/api/admin/users`              | ✓    | LIBRARIAN, ADMIN | Danh sách thành viên        |
| POST   | `/api/admin/users`              | ✓    | LIBRARIAN, ADMIN | Tạo thành viên mới          |
| GET    | `/api/admin/users/:id`          | ✓    | LIBRARIAN, ADMIN | Chi tiết thành viên         |
| PUT    | `/api/admin/users/:id`          | ✓    | LIBRARIAN, ADMIN | Cập nhật thành viên         |
| PATCH  | `/api/admin/users/:id/status`   | ✓    | LIBRARIAN, ADMIN | Khóa/Mở khóa tài khoản     |
| DELETE | `/api/admin/users/:id`          | ✓    | ADMIN            | Xóa thành viên (chỉ Admin) |

**Theo dõi thời gian thực:**

| Method | Endpoint                                | Auth | Role             | Mô tả                            |
|--------|-----------------------------------------|------|------------------|------------------------------------|
| GET    | `/api/admin/realtime/present`           | ✓    | LIBRARIAN, ADMIN | Danh sách đang có mặt trong thư viện |
| GET    | `/api/admin/realtime/stats`             | ✓    | LIBRARIAN, ADMIN | Thống kê thời gian thực           |
| POST   | `/api/admin/realtime/checkout/:userId`  | ✓    | LIBRARIAN, ADMIN | Buộc check-out sinh viên          |

**Báo cáo & Thống kê:**

| Method | Endpoint                                | Auth | Role             | Mô tả                     |
|--------|-----------------------------------------|------|------------------|----------------------------|
| GET    | `/api/admin/reports/checkin`            | ✓    | LIBRARIAN, ADMIN | Báo cáo check-in/out       |
| GET    | `/api/admin/reports/users/:id/history`  | ✓    | LIBRARIAN, ADMIN | Lịch sử ra vào của 1 user |
| GET    | `/api/admin/reports/export`             | ✓    | LIBRARIAN, ADMIN | Xuất báo cáo (CSV)        |

**Cấu hình:**

| Method | Endpoint           | Auth | Role  | Mô tả              |
|--------|--------------------|------|-------|----------------------|
| PUT    | `/api/admin/config`| ✓    | ADMIN | Cập nhật cấu hình   |

---

## KIẾN TRÚC THÔNG BÁO ĐẨY QUA FIREBASE CLOUD MESSAGING (FCM)

### 1. Tổng quan & Luồng Tích Hợp

Hệ thống sử dụng **Firebase Cloud Messaging (FCM)** theo mô hình Push Notification chuẩn di động:
* **Flutter Mobile Client:** Khởi tạo `Firebase.initializeApp()`, lấy token qua `FirebaseMessaging.instance.getToken()`, lắng nghe token refresh và gửi token lên Backend qua API `POST /api/users/register-device`.
* **Backend Node.js:** Sử dụng `firebase-admin` SDK để gửi thông báo bất đồng bộ (asynchronous non-blocking) đến thiết bị của sinh viên mà không làm chậm luồng xử lý quét thẻ lõi.
* **Cơ sở dữ liệu:** Trường `device_token` trong collection `users` lưu giữ Registration Token mới nhất của từng người dùng.

```text
[Flutter Client] ── 1. getToken() ──► [FCM Server]
      │                                     │
      ├── 2. POST /api/users/register-device ─┼──► [Node.js Backend] ── Save device_token ──► [MongoDB]
      │                                     │              │
      │                                     │         (Sự kiện kích hoạt:
      │                                     │          Check-in/out, Khóa thẻ,
      │                                     │          Đóng cửa, Hết hạn thẻ)
      │                                     │              │
      │                                     │        3. admin.messaging().send()
      │                                     │              ▼
      │◄─────── 4. Push Notification ───────┴──────── [FCM Service]
```

### 2. Bốn (04) Kịch Bản Kích Hoạt Thông Báo Đẩy (Event Triggers)

| STT | Sự Kiện Kích Hoạt | Đối Tượng Nhận | Tiêu Đề (Title) | Nội Dung Thông Báo (Body) & Dữ Liệu Kèm Theo | Mã Loại (`type`) |
|:---:|:---|:---|:---|:---|:---|
| **1** | **Quẹt thẻ Check-in / Check-out thành công** | Sinh viên vừa quẹt thẻ | `Check-in Thư Viện Thành Công` / `Check-out Thư Viện Thành Công` | • Check-in: "Chào [Họ Tên]! Bạn đã vào thư viện lúc [Giờ]. Chúc bạn học tập hiệu quả!"<br>• Check-out: "Bạn đã rời thư viện. Tổng thời gian tự học: [X] phút. Hẹn gặp lại!"<br>*Tác dụng an ninh: Giúp sinh viên phát hiện ngay nếu bị kẻ gian chụp lén và quét trộm mã QR.* | `CHECK_IN_SUCCESS`<br>`CHECK_OUT_SUCCESS` |
| **2** | **Thẻ bị Khóa / Mở khóa** (`updateUserStatus`) | Sinh viên bị khóa thẻ | `Cảnh Báo: Thẻ Thư Viện Đã Bị Khóa` / `Thông Báo: Thẻ Đã Mở Khóa` | • Khóa: "Thẻ thư viện của bạn đã bị khóa bởi quản trị viên. Lý do: [Lý do]. Vui lòng liên hệ thủ thư tại quầy."<br>• Mở: "Thẻ thư viện của bạn đã được kích hoạt lại. Bạn có thể tiếp tục sử dụng dịch vụ." | `CARD_LOCKED`<br>`CARD_UNLOCKED` |
| **3** | **Cảnh báo Sắp đến giờ đóng cửa thư viện** | Toàn bộ sinh viên đang có mặt (`is_inside: true`) | `Thư Viện Sắp Đóng Cửa` | "Thư viện sẽ đóng cửa sau [WARNING_MINUTES_BEFORE_CLOSE] phút nữa (lúc [CLOSE_TIME]). Vui lòng thu dọn đồ đạc và quét thẻ check-out tại cửa." | `LIBRARY_CLOSING_ALERT` |
| **4** | **Nhắc nhở Thẻ thư viện sắp hết hạn** | Sinh viên có thẻ còn <= 7 ngày hết hạn | `Nhắc Nhở Gia Hạn Thẻ Thư Viện` | "Thẻ thư viện của bạn sẽ hết hạn vào ngày [DD/MM/YYYY]. Vui lòng đến bàn thủ thư để làm thủ tục gia hạn thẻ." | `CARD_EXPIRING_SOON` |

### 3. Cấu Trúc Message Payload Chuẩn FCM

Tất cả message gửi đi đều chứa cả hai phần `notification` (hiển thị notification banner ở khay hệ thống) và `data` (chứa dữ liệu có cấu trúc để Flutter xử lý điều hướng):

```json
{
  "token": "eXamPLe_fcm_dEviCe_tOkEn_123456789...",
  "notification": {
    "title": "Check-in Thư Viện Thành Công",
    "body": "Chào Nguyễn Văn A! Bạn đã vào thư viện lúc 08:30:15. Chúc bạn học tập hiệu quả!"
  },
  "data": {
    "type": "CHECK_IN_SUCCESS",
    "studentId": "HE190001",
    "timestamp": "2026-11-10T08:30:15.000Z",
    "location": "Cổng chính Tầng 1",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  },
  "android": {
    "priority": "high",
    "notification": {
      "channelId": "library_access_channel",
      "sound": "default",
      "icon": "ic_notification"
    }
  },
  "apns": {
    "payload": {
      "aps": {
        "sound": "default",
        "badge": 1
      }
    }
  }
}
```

### 4. Xử Lý Ngoại Lệ & Quản Lý Vòng Đời Device Token
1. **Token hết hạn hoặc App bị gỡ (Stale/Invalid Token):**
   - Khi `admin.messaging().send()` trả về mã lỗi `messaging/registration-token-not-registered` hoặc `messaging/invalid-registration-token`:
   - Backend tự động thực hiện set `device_token = ''` cho người dùng tương ứng trong MongoDB để tránh tốn tài nguyên gửi lại trong các lần sau.
2. **Người dùng Đăng xuất (Logout):**
   - Khi sinh viên gọi `POST /api/auth/logout`, Client gửi yêu cầu xóa token hoặc Backend chủ động xóa `device_token` nhằm ngăn chặn trường hợp người dùng khác đăng nhập trên cùng thiết bị nhận nhầm thông báo cá nhân.

---

## PHÂN CÔNG THÀNH VIÊN THEO VAI TRÒ & MÀN HÌNH

| Thành viên | Mảng phụ trách | Màn hình & UI Components đảm nhiệm | Chức năng Backend & Logic cụ thể | Tài liệu & Kiểm thử |
|:---|:---|:---|:---|:---|
| **Minh** *(Leader)* | Nền tảng, Auth & Cấu hình hệ thống | • `LoginScreen` (Màn hình Đăng nhập phân luồng Role)<br>• `RegisterScreen` (Màn hình Đăng ký tài khoản)<br>• Khung điều hướng & Routing Guard (`AppRouter`): Tự động điều hướng theo Role (Student $\rightarrow$ `StudentHomeScreen`, Librarian $\rightarrow$ `LibrarianDashboardScreen`, Admin $\rightarrow$ `AdminDashboardScreen`)<br>• Khung vỏ Dashboard đa Tab cho Thủ thư & Admin<br>• Tab `SystemConfigTab` (Màn hình Quản trị cấu hình động - dành riêng cho Admin) | • Kiến trúc Clean Architecture, kết nối MongoDB `db.js`<br>• Middleware xác thực JWT `authenticate`, phân quyền `requireAdmin`, `requireStaff`<br>• Backend API Auth (`/api/auth/*`)<br>• Backend API System Config (`/api/config/*`, `PUT /api/admin/config`)<br>• Model `system_configs` & `roles` | • SRS tổng & Tài liệu kiến trúc hệ thống<br>• DB Schema chung, quy ước Git & API Contract<br>• Review & Merge mã nguồn, chuẩn bị kịch bản demo |
| **Mạnh** | Access Control Engine & Trạm quét | • Tab `QrScannerTab` (Trạm quét kiểm soát dành cho Thủ thư & Admin):<br>&nbsp;&nbsp;- Giao diện quét camera QR Code<br>&nbsp;&nbsp;- **Giao diện nhập tay MSSV dự phòng** khi camera lỗi<br>&nbsp;&nbsp;- Popup kết quả quét thẻ (Ảnh, Tên, MSSV, hành động Vào/Ra, âm thanh & màu sắc)<br>&nbsp;&nbsp;- Badge trạng thái kết nối mạng (Online/Offline) và nút bấm đồng bộ thủ công | • Thuật toán lõi Access Control Engine (`checkin_controller.js`): Kiểm tra điều kiện vào (thẻ còn hạn, không bị khóa, thư viện còn chỗ, trong giờ mở cửa)<br>• Cơ chế Toggle tự động (Vào $\rightarrow$ Ra / Ra $\rightarrow$ Vào), tự động tính `total_minutes`<br>• Parse & giải mã chuỗi QR `LIB:MSSV:ID:EXP`<br>• Cơ chế fallback tra cứu thẻ theo `student_id` | • Đặc tả thuật toán Engine (Flowchart, Bảng quyết định logic)<br>• Sequence Diagram luồng Check-in/Check-out<br>• Viết và thực hiện Test case TC-03, TC-04, TC-05 |
| **Dương** | Giám sát Realtime & Offline Sync | • Tab `LiveOccupancyTab` (Màn hình Giám sát người có mặt realtime dành cho Thủ thư & Admin):<br>&nbsp;&nbsp;- Thanh đo sức chứa realtime (Occupancy Gauge: Số người hiện tại / Sức chứa tối đa)<br>&nbsp;&nbsp;- Danh sách sinh viên đang có mặt trong thư viện theo thời gian thực<br>&nbsp;&nbsp;- Thanh tìm kiếm nhanh sinh viên đang có mặt<br>&nbsp;&nbsp;- **Nút Cưỡng chế Check-out (Forced Check-out)** tại quầy khi sinh viên quên quẹt ra | • Quản lý SQLite cục bộ trên trạm quét (`local_db_helper.dart`), hàng đợi log offline khi mất mạng<br>• Backend API đồng bộ log ngoại tuyến `/api/checkin/sync` (xử lý xung đột, chống trùng lặp theo `local_id`)<br>• Backend API Realtime `/api/admin/realtime/*` (danh sách có mặt, thống kê tức thời, cưỡng chế check-out) | • Thiết kế giải pháp đồng bộ dữ liệu ngoại tuyến (Offline-first)<br>• Thuật toán giải quyết xung đột log khi trạm online trở lại<br>• Viết và thực hiện Test case TC-06, TC-10 |
| **An** | Phân hệ Sinh viên, Quản lý thành viên & Khóa thẻ | • **Phân hệ Sinh viên (Student Portal):**<br>&nbsp;&nbsp;- `StudentHomeScreen`: Thẻ sinh viên điện tử (E-Card), render mã QR `LIB:MSSV:ID:EXP`, tự động đổi màu thẻ theo cờ vị trí `is_inside` thời gian thực (Xanh khi trong thư viện, Xám khi ở ngoài)<br>&nbsp;&nbsp;- `StudentHistoryScreen`: Xem danh sách nhật ký ra/vào cá nhân và tổng thời gian lưu trú<br>&nbsp;&nbsp;- `StudentProfileScreen`: Xem thông tin thẻ, đổi mật khẩu<br>• **Phân hệ Thủ thư & Admin:**<br>&nbsp;&nbsp;- Tab `UserManagementTab`: Tìm kiếm sinh viên, xem chi tiết thẻ, công tắc Khóa/Mở khóa thẻ tức thì (chế độ Thủ thư); Thêm mới, phân quyền Role, và **nút Xóa mềm thành viên** (chế độ Admin) | • Schema & Model `users`, `library_cards`<br>• Backend API User cho Sinh viên (`/api/users/me`, `/api/users/me/qr`, `/api/history/me`)<br>• Backend API Quản lý thành viên (`/api/admin/users/*`)<br>• API Khóa/Mở khóa thẻ (`PATCH /api/admin/users/:id/status`) đồng bộ 2 chiều giữa `users.status` và `library_cards.status`<br>• Xử lý nghiệp vụ TC-07 (Chặn vào nhưng vẫn cho phép check-out ra về khi thẻ bị khóa) | • Đặc tả chi tiết Schema `users` & `library_cards`<br>• Đặc tả thiết kế UI/UX Thẻ sinh viên điện tử<br>• Viết và thực hiện Test case TC-07 |
| **Cầm** | Thống kê, Báo cáo & QA Tổng | • Tab `ReportStatsTab` (Màn hình Thống kê báo cáo dành cho Thủ thư & Admin):<br>&nbsp;&nbsp;- Biểu đồ trực quan sử dụng thư viện `fl_chart` (Biểu đồ cột/đường theo Giờ trong ngày, theo Ngày trong tuần, theo Tuần trong tháng)<br>&nbsp;&nbsp;- Thẻ KPI trực quan: Giờ cao điểm, ngày cao điểm, tổng số lượt phục vụ<br>&nbsp;&nbsp;- Nút **Xuất file CSV** (hỗ trợ chuẩn UTF-8 BOM hiển thị tiếng Việt trên Excel) | • Backend API Báo cáo & Thống kê (`/api/admin/reports/checkin`, `/api/admin/reports/users/:id/history`, `/api/admin/reports/export`)<br>• Xây dựng MongoDB Aggregation Pipelines để tổng hợp dữ liệu thống kê theo khung thời gian hiệu năng cao<br>• Xử lý xuất luồng file CSV UTF-8 có BOM | • Đặc tả mẫu báo cáo và chỉ số thống kê<br>• Tạo bộ dữ liệu mẫu (Seed Data)<br>• Viết và thực hiện Test case TC-08, TC-09<br>• **Tổng hợp Testing Report toàn diện**, chụp ảnh minh chứng và tổ chức test chéo toàn hệ thống |
