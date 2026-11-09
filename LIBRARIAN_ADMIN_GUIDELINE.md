# GUIDELINE CHI TIẾT TRIỂN KHAI VAI TRÒ THỦ THƯ / ADMIN
**Dự án:** Hệ Thống Ghi Nhận Ra Vào Thư Viện (Library Access Management System - LibIOG4)  
**Phân hệ:** Quản Trị & Thủ Thư (Librarian / Admin)  
**Mục tiêu:** Cung cấp lộ trình phát triển chi tiết từng Feature (Feature-Driven Development) từ Backend $\rightarrow$ Data $\rightarrow$ BLoC $\rightarrow$ UI, đảm bảo chuẩn Clean Architecture, hoạt động mượt mà đa nền tảng và kiểm thử đầy đủ.

---

## 📑 MỤC LỤC
1. [Tổng Quan 5 Feature Cốt Lõi Của Thủ Thư](#1-tổng-quan-5-feature-cốt-lõi-của-thủ-thư)
2. [Thiết Lập Nền Tảng Đa Môi Trường (Cross-Platform Base)](#2-thiết-lập-nền-tảng-đa-môi-trường-cross-platform-base)
3. [FEATURE 1: Cấu Hình Động Hệ Thống (Dynamic System Config - FR-03)](#feature-1-cấu-hình-động-hệ-thống-dynamic-system-config---fr-03)
4. [FEATURE 2: Giám Sát Thời Gian Thực & Forced Check-Out (Live Occupancy)](#feature-2-giám-sát-thời-gian-thực--forced-check-out-live-occupancy)
5. [FEATURE 3: Trạm Quét QR Điểm Danh & Nhập Tay Dự Phòng (FR-02)](#feature-3-trạm-quét-qr-điểm-danh--nhập-tay-dự-phòng-fr-02)
6. [FEATURE 4: Quản Lý Thành Viên & Khóa Thẻ Thư Viện (FR-01)](#feature-4-quản-lý-thành-viên--khóa-thẻ-thư-viện-fr-01)
7. [FEATURE 5: Thống Kê, Biểu Đồ & Xuất Báo Cáo CSV (FR-04)](#feature-5-thống-kê-biểu-đồ--xuất-báo-cáo-csv-fr-04)
8. [FEATURE 6: Lưu Trữ Ngoại Tuyến & Đồng Bộ Tự Động (Offline Sync)](#feature-6-lưu-trữ-ngoại-tuyến--đồng-bộ-tự-động-offline-sync)
9. [Triển Khai Kiểm Thử Toàn Diện (Unit Test & Widget Test)](#9-triển-khai-kiểm-thử-toàn-diện-unit-test--widget-test)
10. [Checklist Nghiệm Thu Sản Phẩm](#10-checklist-nghiệm-thu-sản-phẩm)

---

## 1. TỔNG QUAN 5 FEATURE CỐT LÕI CỦA THỦ THƯ

```text
                                  ┌───────────────────────────────┐
                                  │   ADMIN / THỦ THƯ DASHBOARD   │
                                  └───────────────┬───────────────┘
           ┌──────────────────────┬───────────────┼──────────────────────┬──────────────────────┐
           ▼                      ▼               ▼                      ▼                      ▼
    [ Feature 1 ]          [ Feature 2 ]   [ Feature 3 ]          [ Feature 4 ]          [ Feature 5 ]
   CẤU HÌNH ĐỘNG          LIVE OCCUPANCY    TRẠM QUÉT QR         QUẢN LÝ USER           THỐNG KÊ & CSV
 - Đổi sức chứa         - % Lấp đầy        - Quét camera         - Danh sách SV         - Biểu đồ fl_chart
 - Giờ mở/đóng cửa      - Danh sách có mặt - Gõ mã/MSSV dự phòng - Khóa/mở thẻ          - Xuất file CSV
 - Không cần restart    - Forced Check-out - Offline fallback    - Lọc theo MSSV        - Phân tích giờ cao điểm
```

---

## 2. THIẾT LẬP NỀN TẢNG ĐA MÔI TRƯỜNG (CROSS-PLATFORM BASE)

Trước khi viết từng Feature, cần chuẩn hóa các file nền tảng sau:

### 2.1. Tự động nhận diện Base URL theo môi trường
Chỉnh sửa file `frontend/lib/core/constants/app_constants.dart`:
```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String appName = 'Library Access Management';
  static const String dbName = 'library_offline.db';
  static const int dbVersion = 1;

  // Tự động nhận diện môi trường
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000/api'; // Android Emulator
    return 'http://localhost:5000/api'; // iOS, Windows, macOS, Linux
  }
}
```

### 2.2. Hỗ trợ SQLite Native trên Windows/macOS/Linux
Chỉnh sửa `frontend/lib/main.dart`:
```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}
```

---

## FEATURE 1: CẤU HÌNH ĐỘNG HỆ THỐNG (DYNAMIC SYSTEM CONFIG - FR-03)
*Mục tiêu:* Cho phép Thủ thư chỉnh sửa `maxCapacity`, `openTime`, `closeTime` trực tiếp từ ứng dụng và áp dụng ngay lập tức mà không cần restart server hay build lại app.

### Các bước phát triển:
1. **Backend Verification:**
   - Đảm bảo route `GET /api/config` và `PUT /api/config` trong `backend/src/routes/config_routes.js` đang trỏ tới `config_controller.js`.
2. **Data Layer (Flutter):**
   - **Model:** Tạo `frontend/lib/data/models/system_config_model.dart`:
     - Chứa các trường: `maxCapacity` (int), `openTime` (String), `closeTime` (String), `maintenanceMode` (bool).
     - Các hàm: `fromJson()`, `toJson()`.
   - **Datasource:** Thêm vào `AdminRemoteDataSource`:
     - `Future<SystemConfigModel> getConfigs()`: Gọi `GET /api/config`.
     - `Future<void> updateConfigs(Map<String, dynamic> data)`: Gọi `PUT /api/config`.
3. **Domain Layer (Flutter):**
   - **Entity:** `frontend/lib/domain/entities/system_config.dart`.
   - **Repository Interface:** Khai báo hàm `getConfig()` và `saveConfig()`.
4. **BLoC Layer (Flutter):**
   - Tạo `frontend/lib/presentation/bloc/config/`:
     - `config_event.dart`: `LoadConfigEvent`, `UpdateConfigEvent(Map<String, dynamic> newConfig)`.
     - `config_state.dart`: `ConfigLoading`, `ConfigLoaded(SystemConfig config)`, `ConfigUpdating`, `ConfigUpdateSuccess`, `ConfigError(String message)`.
     - `config_bloc.dart`: Xử lý logic gọi repository và phát state.
5. **Presentation Layer (Flutter):**
   - Tạo `frontend/lib/presentation/screens/admin/tabs/system_config_tab.dart`:
     - Giao diện gồm 3 Card:
       - Card 1: Ô nhập Sức chứa tối đa (Number keyboard).
       - Card 2: Hai ô chọn Giờ mở cửa / Giờ đóng cửa (Bật `showTimePicker`).
       - Card 3: Switch chế độ bảo trì (Maintenance Mode).
     - Nút "Lưu Cấu Hình": Gửi `UpdateConfigEvent` $\rightarrow$ Hiện `SnackBar` thông báo thành công.

---

## FEATURE 2: GIÁM SÁT THỜI GIAN THỰC & FORCED CHECK-OUT (LIVE OCCUPANCY)
*Mục tiêu:* Hiển thị chỉ số lấp đầy của thư viện theo thời gian thực (Live Dashboard), danh sách sinh viên đang ngồi học và cho phép Thủ thư check-out cưỡng chế (Mời ra).

### Các bước phát triển:
1. **Backend Enhancement:**
   - Mở `backend/src/controllers/admin_report_controller.js`, bổ sung hàm `forceCheckOutUser`:
     ```javascript
     async function forceCheckOutUser(req, res, next) {
       try {
         const { userId } = req.params;
         const user = await User.findById(userId);
         if (!user) return res.status(404).json({ success: false, message: 'User not found' });
         
         const activeLog = await CheckInLog.findOne({ userId: user._id, checkOutTime: null }).sort({ checkInTime: -1 });
         const now = new Date();
         if (activeLog) {
           activeLog.checkOutTime = now;
           activeLog.durationMinutes = Math.round((now - activeLog.checkInTime) / 60000);
           await activeLog.save();
         }
         user.isInsideLibrary = false;
         await user.save();
         res.json({ success: true, message: `Check-out thành công cho ${user.name}` });
       } catch (err) { next(err); }
     }
     ```
   - Thêm route vào `backend/src/routes/admin_routes.js`:
     ```javascript
     router.post('/realtime/checkout/:userId', forceCheckOutUser);
     ```
2. **Data & Domain Layer (Flutter):**
   - **Model:** Tạo `present_student_model.dart` (chứa `userId`, `studentId`, `name`, `checkInTime`, `durationMinutes`) và `occupancy_stats_model.dart` (`currentOccupancy`, `maxCapacity`, `occupancyPercent`).
   - **Datasource:** Thêm hàm `getPresentStudents()` (gọi `GET /api/admin/realtime/present`) và `forceCheckOut(String userId)`.
3. **BLoC Layer (Flutter):**
   - Tạo `frontend/lib/presentation/bloc/realtime/`:
     - `realtime_event.dart`: `FetchRealtimeDataEvent`, `StartAutoRefreshEvent`, `ForceCheckOutUserEvent(String userId)`.
     - `realtime_state.dart`: `RealtimeLoading`, `RealtimeLoaded(...)`, `RealtimeActionSuccess(String msg)`, `RealtimeError(String msg)`.
     - `realtime_bloc.dart`: Tích hợp `Timer.periodic` (4 giây lặp lại 1 lần) để tự động cập nhật số liệu thời gian thực.
4. **Presentation Layer (Flutter):**
   - Tạo `frontend/lib/presentation/screens/admin/tabs/live_occupancy_tab.dart`:
     - Phần trên: Card tròn hoặc thanh đo % lấp đầy (Xanh lá < 70%, Vàng 70-90%, Đỏ > 90%).
     - Phần dưới: Danh sách `ListView.builder` sinh viên đang có mặt. Cạnh mỗi sinh viên có:
       - Thời gian check-in & số phút đã ngồi.
       - Nút đỏ **"Check-out"** $\rightarrow$ Bật Dialog xác nhận $\rightarrow$ Gửi `ForceCheckOutUserEvent`.

---

## FEATURE 3: TRẠM QUÉT QR ĐIỂM DANH & NHẬP TAY DỰ PHÒNG (FR-02)
*Mục tiêu:* Thiết bị của Thủ thư đóng vai trò là Trạm quét tại cửa. Hỗ trợ cả 2 chế độ: Camera quét QR của sinh viên HOẶC gõ trực tiếp MSSV/Mã thẻ bằng bàn phím.

### Các bước phát triển:
1. **Backend Verification:**
   - API `POST /api/checkin` đã có sẵn trong `checkin_controller.js`. Đảm bảo trả về đúng phân loại `check_in` hoặc `check_out` và tính toán `durationMinutes`.
2. **Data & Domain Layer (Flutter):**
   - Thêm vào Datasource: `Future<CheckInResultModel> submitScan(String qrPayload, {String? deviceId})`.
3. **BLoC Layer (Flutter):**
   - Tạo `frontend/lib/presentation/bloc/scanner/`:
     - `scanner_event.dart`: `ProcessQrCodeEvent(String rawCode)`.
     - `scanner_state.dart`: `ScannerIdle`, `ScannerProcessing`, `ScannerSuccess(CheckInResult result)`, `ScannerFailed(String errorCode, String message)`.
4. **Presentation Layer (Flutter):**
   - Tạo `frontend/lib/presentation/screens/admin/tabs/qr_scanner_tab.dart`:
     - **Chế độ 1 (Camera):** Dùng widget `MobileScanner` để tự động nhận dạng mã thẻ sinh viên (`LIB:studentId:userId:epoch`).
     - **Chế độ 2 (Desktop / Web Fallback):** Một thanh `TextField` cho phép nhập trực tiếp MSSV hoặc cắm máy quét mã vạch USB rồi nhấn `Enter`.
     - **Dialog hiển thị kết quả:**
       - Thành công: Hộp thoại màu Xanh lá hiện Avatar, Tên SV, Hành động (VÀO / RA), Số phút đã ngồi.
       - Thất bại: Hộp thoại màu Đỏ hiện rõ lý do (Thư viện đã đầy, Thẻ hết hạn, Tài khoản bị khóa, Ngoài giờ mở cửa).

---

## FEATURE 4: QUẢN LÝ THÀNH VIÊN & KHÓA THẺ THƯ VIỆN (FR-01)
*Mục tiêu:* Danh sách toàn bộ người dùng, tìm kiếm theo MSSV/tên và quyền bật/tắt khóa tài khoản sinh viên.

### Các bước phát triển:
1. **Backend Verification:**
   - Các API trong `backend/src/routes/admin_routes.js`:
     - `GET /api/admin/users`: Danh sách sinh viên (có phân trang & search).
     - `PATCH /api/admin/users/:id/status`: Cập nhật `status = 'active' | 'locked'`.
2. **Data & Domain Layer (Flutter):**
   - **Model:** `user_admin_model.dart` (`id`, `studentId`, `name`, `email`, `status`, `role`, `isInsideLibrary`).
   - **Datasource:** `fetchUsers({String search, int page})` và `updateStatus(String userId, String newStatus)`.
3. **BLoC Layer (Flutter):**
   - Tạo `frontend/lib/presentation/bloc/user_management/`:
     - `user_event.dart`: `FetchUsersEvent(String query)`, `ToggleUserStatusEvent(String userId, String currentStatus)`.
     - `user_state.dart`: `UserLoading`, `UserLoaded(List<UserAdmin> users)`, `UserStatusUpdated`, `UserError`.
4. **Presentation Layer (Flutter):**
   - Tạo `frontend/lib/presentation/screens/admin/tabs/user_management_tab.dart`:
     - Thanh tìm kiếm SearchBar ở trên cùng (có debounce 300ms).
     - Danh sách sinh viên dạng `ListTile`:
       - Hiển thị: Mã SV, Họ tên, Trạng thái (Chip Xanh: `ACTIVE`, Chip Đỏ: `LOCKED`).
       - `Switch` bật/tắt trạng thái trực tiếp. Nếu gạt sang Khóa $\rightarrow$ Sinh viên không thể quét thẻ ở Feature 3.

---

## FEATURE 5: THỐNG KÊ, BIỂU ĐỒ & XUẤT BÁO CÁO CSV (FR-04)
*Mục tiêu:* Vẽ biểu đồ phân bố lượt ra vào theo khung giờ/ngày bằng thư viện `fl_chart` và tải báo cáo định dạng CSV chuẩn tiếng Việt.

### Các bước phát triển:
1. **Backend Verification:**
   - `GET /api/admin/reports/checkin?groupBy=hour|day|week`: Dữ liệu vẽ biểu đồ.
   - `GET /api/admin/reports/export`: Tải file CSV có kèm UTF-8 BOM.
2. **Data & Domain Layer (Flutter):**
   - **Model:** `report_data_model.dart` (chứa `labels: List<String>`, `checkIns: List<int>`, `totalVisits: int`, `avgDuration: int`).
   - **Datasource:** `fetchCheckinReport(String groupBy)` và `exportCsvUrl()`.
3. **BLoC Layer (Flutter):**
   - Tạo `frontend/lib/presentation/bloc/report/`:
     - `report_event.dart`: `ChangeFilterEvent(String groupBy: 'hour' | 'day')`, `ExportCsvEvent`.
     - `report_state.dart`: `ReportLoading`, `ReportLoaded(ReportData data)`, `ReportExportSuccess(String filePath)`, `ReportError`.
4. **Presentation Layer (Flutter):**
   - Tạo `frontend/lib/presentation/screens/admin/tabs/report_analytics_tab.dart`:
     - **Thẻ KPI đầu trang:** 3 số liệu: Tổng lượt vào hôm nay, Số người hiện tại, Thời gian ngồi trung bình.
     - **Biểu đồ cột `BarChart` (`fl_chart`):**
       - Trục hoành (X): Các khung giờ trong ngày (08:00, 10:00, 14:00,...) hoặc các ngày trong tuần.
       - Trục tung (Y): Số lượng lượt check-in.
     - **Nút "Xuất file CSV":** Nhấn vào tải file về máy và mở thông báo mở file thành công.

---

## FEATURE 6: LƯU TRỮ NGOẠI TUYẾN & ĐỒNG BỘ TỰ ĐỘNG (OFFLINE SYNC)
*Mục tiêu:* Khi trạm quét bị mất mạng, lượt quét được lưu vào SQLite cục bộ và tự động đồng bộ lên Server khi có mạng trở lại.

### Các bước phát triển:
1. **Database SQLite Helper:**
   - Cập nhật `frontend/lib/data/datasources/local_db_helper.dart`:
     ```sql
     CREATE TABLE offline_checkins(
       localId TEXT PRIMARY KEY,
       qrPayload TEXT,
       timestamp TEXT,
       deviceId TEXT,
       syncStatus TEXT -- 'PENDING', 'SYNCED'
     );
     ```
2. **Xử lý ngắt mạng:**
   - Khi Feature 3 (Quét QR) bị lỗi mạng (`SocketException` hoặc `TimeoutException`):
     $\rightarrow$ Bắt Exception, tự động gọi `LocalDbHelper.insertOfflineLog()`.
     $\rightarrow$ Báo thông báo màu Vàng: *"Đã lưu điểm danh ngoại tuyến vào máy"*.
3. **Đồng bộ tự động (Auto Sync):**
   - Khi có kết nối mạng trở lại, gọi API `POST /api/checkin/sync` gửi danh sách các log `PENDING` lên Server.
   - Server phản hồi thành công $\rightarrow$ Cập nhật cờ `SYNCED` trên SQLite.

---

## 9. TRIỂN KHAI KIỂM THỬ TOÀN DIỆN (UNIT TEST & WIDGET TEST)

1. **Unit Test BLoC (`frontend/test/presentation/bloc/`):**
   - `admin_config_bloc_test.dart`: Test các trường hợp `LoadConfigEvent` và `UpdateConfigEvent`.
   - `realtime_bloc_test.dart`: Test cập nhật số liệu khi nhận dữ liệu từ Repository.
2. **Widget Test Giao diện (`frontend/test/presentation/screens/`):**
   - `admin_dashboard_screen_test.dart`: Test khả năng chuyển đổi giữa 4 tab.
   - `system_config_tab_test.dart`: Test nhập liệu vào text field và bấm nút Lưu cấu hình.

---

## 10. CHECKLIST NGHIỆM THU SẢN PHẨM

- [ ] **Feature 1:** Thay đổi `maxCapacity` từ App $\rightarrow$ Áp dụng ngay lập tức cho lượt check-in tiếp theo.
- [ ] **Feature 2:** Thanh đo sức chứa đổi màu linh hoạt (Xanh/Vàng/Đỏ); Nút Forced Check-out xóa sinh viên khỏi danh sách có mặt ngay lập tức.
- [ ] **Feature 3:** Trạm quét nhận dạng mã QR thẻ và hỗ trợ cả gõ tay MSSV; Từ chối khi thư viện đầy hoặc thẻ hết hạn.
- [ ] **Feature 4:** Khóa thẻ sinh viên $\rightarrow$ Sinh viên bị chặn không cho vào thư viện.
- [ ] **Feature 5:** Biểu đồ `fl_chart` hiển thị trực quan các khung giờ cao điểm; Xuất được file CSV có dấu tiếng Việt.
- [ ] **Feature 6:** Ngắt mạng vẫn quét được thẻ; Bật mạng lại tự động đồng bộ lên MongoDB.
- [ ] **Cross-Platform:** Chạy được trên cả Web, Windows Desktop và Mobile (Android/iOS).
