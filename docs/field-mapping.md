# Bảng Ánh Xạ Dữ Liệu & Quy Chuẩn Kiến Trúc (Field Mapping Specification)

Tài liệu chuẩn hóa cấu trúc dữ liệu theo **Thiết kế gốc (Single Source of Truth)** của Hệ thống Quản lý Ra Vào Thư viện (Library Access Management System).

---

## 1. Bảng ánh xạ Schema 6 Collections

### 1.1. Collection: `roles` (Phân quyền người dùng)
* **Tên collection MongoDB:** `roles`
* **Mục đích:** Quản lý các vai trò trong hệ thống với chuẩn RBAC nghiêm ngặt.

| Trường cũ (v1) | Trường chuẩn (v2) | Kiểu dữ liệu | Giá trị hợp lệ / Ràng buộc | Ghi chú chuyển đổi |
|---|---|---|---|---|
| *(N/A - lưu string)* | `_id` | `ObjectId` | Primary Key | Tự sinh bởi MongoDB |
| `role` (string) | `role_name` | `String` | `'STUDENT'`, `'LIBRARIAN'`, `'ADMIN'` | Unique, Index, Viết hoa toàn bộ |
| *(chưa có)* | `description` | `String` | Text mô tả | Diễn giải quyền hạn của vai trò |

---

### 1.2. Collection: `users` (Tài khoản & Trạng thái vị trí Real-time)
* **Tên collection MongoDB:** `users`
* **Mục đích:** Lưu thông tin tài khoản người dùng và cờ vị trí thời gian thực.

| Trường cũ (v1) | Trường chuẩn (v2) | Kiểu dữ liệu | Giá trị hợp lệ / Ràng buộc | Ghi chú chuyển đổi |
|---|---|---|---|---|
| `studentId` | `student_id` | `String` | Unique, Index, Trim | Mã định danh sinh viên / cán bộ |
| `name` | `full_name` | `String` | Trim, Required | Họ và tên đầy đủ |
| `email` | `email` | `String` | Unique, Index, Lowercase | Email trường cấp |
| `password` | `password_hash` | `String` | Bcrypt hash | Không bao giờ trả về client |
| `phone` | `phone` | `String` | Default: `""` | Số điện thoại liên hệ |
| `role` (string) | `role_id` | `ObjectId` | Ref: `'Role'`, Required, Index | Tham chiếu sang collection `roles` |
| `status` | `status` | `String` | `'ACTIVE'`, `'BLOCKED'` | **Chuẩn hóa chữ hoa**, không còn `'deleted'` |
| `isInsideLibrary` | `is_inside` | `Boolean` | Default: `false`, Index | Cờ vị trí tức thời (Đang ở trong / ngoài) |
| `lastCheckIn` | `last_check_in` | `Date` | Default: `null` | Thời điểm quét thẻ vào gần nhất |
| *(chưa có)* | `deleted_at` | `Date` | Default: `null`, Index | **Xóa mềm (Soft delete)**: null = hoạt động |
| `avatarUrl` | `avatar_url` | `String` | URL chuỗi ảnh đại diện | Giữ lại để hiển thị UI |
| `deviceToken` | `device_token` | `String` | Chuỗi FCM Token | Phục vụ push notification |
| `refreshToken` | `refresh_token` | `String` | JWT Refresh Token hash | Xác thực phiên đăng nhập |
| `cardExpiry` | *(Đã tách)* | - | - | **Chuyển toàn bộ sang collection `library_cards`** |

---

### 1.3. Collection: `library_cards` (Thẻ thư viện điện tử)
* **Tên collection MongoDB:** `library_cards`
* **Mục đích:** Quản lý thông tin chu kỳ sống của thẻ thư viện tách biệt khỏi thông tin cá nhân.

| Trường cũ (v1) | Trường chuẩn (v2) | Kiểu dữ liệu | Giá trị hợp lệ / Ràng buộc | Ghi chú chuyển đổi |
|---|---|---|---|---|
| *(N/A - nhúng user)* | `_id` | `ObjectId` | Primary Key | Mã định danh thẻ (dùng trong QR) |
| *(N/A)* | `user_id` | `ObjectId` | Ref: `'User'`, Required, Index | Liên kết 1-1 với tài khoản sinh viên |
| *(N/A)* | `qr_code_hash` | `String` | Unique, Index | Chuỗi băm bí mật chống làm giả QR |
| `createdAt` | `issue_date` | `Date` | Default: `now` | Ngày cấp thẻ |
| `cardExpiry` | `expiry_date` | `Date` | Required, Index | Ngày hết hạn của thẻ thư viện |
| *(N/A)* | `status` | `String` | `'ACTIVE'`, `'EXPIRED'`, `'LOCKED'` | Trạng thái thẻ, đồng bộ với `users.status` |

---

### 1.4. Collection: `gates` (Cổng / Trạm quét kiểm soát)
* **Tên collection MongoDB:** `gates`
* **Mục đích:** Quản lý danh sách các cửa, cổng barrier và trạm quét thẻ.

| Trường cũ (v1) | Trường chuẩn (v2) | Kiểu dữ liệu | Giá trị hợp lệ / Ràng buộc | Ghi chú chuyển đổi |
|---|---|---|---|---|
| *(N/A)* | `_id` | `ObjectId` | Primary Key | Định danh trạm quét |
| `deviceId` | `gate_name` | `String` | Required (Vd: "Cổng chính") | Tên cổng ra vào |
| *(N/A)* | `location` | `String` | Vd: "Sảnh chính - Tầng 1" | Vị trí địa lý lắp đặt cổng |
| *(N/A)* | `status` | `String` | `'ACTIVE'`, `'INACTIVE'`, `'MAINTENANCE'` | Trạng thái kỹ thuật của cổng |

---

### 1.5. Collection: `check_in_logs` (Nhật ký ra vào & Phiên sử dụng)
* **Tên collection MongoDB:** `check_in_logs`
* **Mục đích:** Ghi nhận lịch sử quẹt thẻ chi tiết, tính toán thời lượng lưu trú và đồng bộ dữ liệu ngoại tuyến.

| Trường cũ (v1) | Trường chuẩn (v2) | Kiểu dữ liệu | Giá trị hợp lệ / Ràng buộc | Ghi chú chuyển đổi |
|---|---|---|---|---|
| `_id` | `_id` | `ObjectId` | Primary Key | Mã bản ghi log |
| `userId` | `user_id` | `ObjectId` | Ref: `'User'`, Required, Index | Sinh viên thực hiện quẹt thẻ |
| *(N/A)* | `card_id` | `ObjectId` | Ref: `'LibraryCard'`, Index | Thẻ thư viện được sử dụng |
| `deviceId` | `gate_id` | `ObjectId` | Ref: `'Gate'`, Index | Cổng tiếp nhận quét thẻ |
| `checkInTime` | `check_in_time` | `Date` | Required, Index | Thời điểm quẹt thẻ vào |
| `checkOutTime` | `check_out_time` | `Date` | Default: `null` | Thời điểm quẹt thẻ ra |
| `durationMinutes` | `total_minutes` | `Number` | Default: `null` | Thời gian lưu trú (tự tính khi check-out) |
| *(N/A)* | `action_type` | `String` | `'CHECK_IN'`, `'CHECK_OUT'` | Loại hành động của log |
| *(N/A)* | `status` | `String` | `'INSIDE'`, `'COMPLETED'` | Trạng thái phiên (Đang ngồi / Đã về) |
| *(N/A)* | `sync_status` | `String` | `'SYNCED'`, `'PENDING'` | Trạng thái đồng bộ của trạm quét offline |
| `localId` | `local_id` | `String` | Index, Default: `""` | Khóa chống trùng lặp khi đồng bộ offline |

---

### 1.6. Collection: `system_configs` (Cấu hình hệ thống động)
* **Tên collection MongoDB:** `system_configs`
* **Mục đích:** Lưu trữ các tham số vận hành có thể thay đổi nóng mà không cần dừng server.

| Trường cũ (v1) | Trường chuẩn (v2) | Kiểu dữ liệu | Giá trị hợp lệ / Ràng buộc | Ghi chú chuyển đổi |
|---|---|---|---|---|
| `key` | `config_key` | `String` | Primary Key, Unique, Uppercase | Ví dụ: `'MAX_CAPACITY'`, `'OPEN_TIME'` |
| `value` | `config_value` | `String` | Chuỗi giá trị cấu hình | Luôn lưu dạng chuỗi trong DB |
| *(N/A)* | `data_type` | `String` | `'INT'`, `'STRING'`, `'TIME'`, `'BOOLEAN'` | Kiểu dữ liệu gốc để parse & validate |
| *(N/A)* | `description` | `String` | Text giải thích ý nghĩa | Mô tả thông số cấu hình |
| `updatedAt` | `updated_at` | `Date` | Default: `now` | Thời điểm chỉnh sửa gần nhất |

---

## 2. Quy chuẩn Định dạng QR Payload & Trạm quét

* **Cấu trúc chuẩn thiết kế gốc:**
  ```text
  LIB:{student_id}:{card_id}:{expireEpochSeconds}
  ```
  * Ví dụ: `LIB:HE190001:662cb8d9e2b10a45b9123456:1761638400`
* **Cơ chế Fallback (Dự phòng):**
  * Hỗ trợ trạm quét nhập tay trực tiếp mã số sinh viên `student_id` (Vd: `HE190001`).
  * Backend tự động tra cứu người dùng và thẻ thư viện hợp lệ tương ứng.

---

## 3. Quy tắc Nghiệp vụ Trọng yếu (Business Logic & Edge Cases)

1. **TC-07: Xử lý Sinh viên bị khóa khi đang ở trong thư viện:**
   * Sinh viên có trạng thái `users.status === 'BLOCKED'` hoặc `library_cards.status === 'LOCKED'`:
     * Nếu **đang ở ngoài** (`is_inside === false`): **CHẶN CHECK-IN** với mã lỗi `422 ACCOUNT_LOCKED`.
     * Nếu **đang ở trong** (`is_inside === true`): **CHO PHÉP CHECK-OUT** bình thường để ra ngoài, cập nhật `is_inside = false` và hoàn tất log. Sau khi ra ngoài, tiếp tục bị chặn nếu cố gắng vào lại.
2. **Đồng bộ trạng thái khóa hai chiều (Dual-status Lock Synchronization):**
   * Khi admin/thủ thư khóa tài khoản: `users.status = 'BLOCKED'` $\Longleftrightarrow$ `library_cards.status = 'LOCKED'`.
   * Khi mở khóa: `users.status = 'ACTIVE'` $\Longleftrightarrow$ `library_cards.status = 'ACTIVE'`.
3. **Phân quyền vai trò (RBAC):**
   * `STUDENT`: Chỉ xem thông tin bản thân, lấy mã QR, xem trạng thái có mặt của mình, đọc cấu hình hệ thống.
   * `LIBRARIAN`: Sử dụng trạm quét QR, nhập tay dự phòng, xem danh sách có mặt, cưỡng chế check-out tại quầy, xem danh sách người dùng và thống kê báo cáo. **Không được xóa người dùng, không được sửa cấu hình hệ thống.**
   * `ADMIN`: Toàn quyền quản trị, thêm/sửa/xóa mềm thành viên, cập nhật cấu hình hệ thống.
4. **Tương thích giao tiếp Frontend - Backend (Protocol Contract):**
   * CSDL MongoDB lưu trữ chuẩn `snake_case`.
   * REST API trả về DTO chuẩn `camelCase` thông qua virtual getters và `toSafeObject()`, đảm bảo Client Flutter hoạt động mượt mà không gặp lỗi giải mã JSON.
5. **Quy chuẩn Tích hợp Thông báo Đẩy qua Firebase Cloud Messaging (FCM):**
   * **Endpoint đăng ký thiết bị:** `POST /api/users/register-device` (Header: `Authorization: Bearer <token>`).
     * Body gửi lên: `{ "deviceToken": "<fcm_registration_token>" }` hoặc `{ "device_token": "..." }`.
     * Response: `{ "success": true, "message": "Đã đăng ký thiết bị" }`.
   * **Lưu trữ CSDL:** Cập nhật trực tiếp vào trường `users.device_token`.
   * **Kịch bản gửi thông báo từ Backend (`firebase-admin`):**
     * `CHECK_IN_SUCCESS`: Bắn khi check-in thành công.
     * `CHECK_OUT_SUCCESS`: Bắn khi check-out thành công.
     * `CARD_BLOCKED`: Bắn khi Admin/Thủ thư khóa thẻ qua `PATCH /api/admin/users/:id/status`.
     * `LIBRARY_CLOSING_ALERT`: Bắn cho toàn bộ user có `is_inside: true` khi đến giờ cảnh báo đóng cửa.
   * **Dọn dẹp Token:** Tự động set `device_token = ''` khi FCM báo token hết hạn hoặc khi user gọi `POST /api/auth/logout`.
