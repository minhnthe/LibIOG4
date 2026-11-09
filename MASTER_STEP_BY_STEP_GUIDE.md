# MASTER STEP-BY-STEP IMPLEMENTATION & UI TESTING GUIDE
**Dự án:** Hệ Thống Ghi Nhận Ra Vào Thư Viện (Library Access Management - LibIOG4)  
**Phân hệ:** Quản Trị & Thủ Thư (Librarian / Admin)  
**Tác giả:** Đội ngũ phát triển (Nhánh `manhtd`)  
**Đối tượng sử dụng:** Dành cho tất cả lập trình viên trong nhóm và người chấm thi để hiểu rõ: *Code những gì, ở file nào, và kiểm thử từng bước trên giao diện (UI) ra sao*.

---

## 🗺️ TỔNG QUAN LỘ TRÌNH 9 BƯỚC (ROADMAP)

```text
[STEP 0] Setup Cross-Platform Base (Base URL, SQLite FFI)
   │
   ├──▶ [STEP 1] Hoàn thiện Backend (Forced Check-out & Auto-expire qua đêm)
   │
   ├──▶ [STEP 2] Dựng tầng Data & Domain (Clean Architecture: Models, Datasource, Repository)
   │
   ├──▶ [STEP 3] Feature 1: Cấu hình động hệ thống (Dynamic Config - FR-03)
   │
   ├──▶ [STEP 4] Feature 2: Giám sát thời gian thực & Check-out thủ công (Live Occupancy)
   │
   ├──▶ [STEP 5] Feature 3: Trạm quét QR & Nhập tay bàn phím dự phòng (FR-02)
   │
   ├──▶ [STEP 6] Feature 4: Quản lý thành viên & Khóa thẻ thư viện (FR-01)
   │
   ├──▶ [STEP 7] Feature 5: Biểu đồ thống kê & Xuất file CSV (FR-04)
   │
   ├──▶ [STEP 8] Ghép nối hoàn chỉnh Admin Dashboard (Responsive Layout Mobile/Web/Desktop)
   │
   └──▶ [STEP 9] Bộ kiểm thử tự động (Unit Test & Widget Test - 100% Pass)
```

---

## STEP 0: CẤU HÌNH NỀN TẢNG ĐA MÔI TRƯỜNG (CROSS-PLATFORM SETUP)

### 1. Mục tiêu
Đảm bảo ứng dụng chạy đồng nhất trên **Android Emulator, iOS, Web, Windows Desktop, macOS** mà không bị lỗi crash do SQLite hoặc sai địa chỉ kết nối IP Backend.

### 2. Các tệp cần can thiệp & Mã nguồn

#### 📁 `frontend/lib/core/constants/app_constants.dart`
Cấu hình tự động đổi URL theo môi trường:
```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String appName = 'Library Check-in System';
  static const String dbName = 'library_offline.db';
  static const int dbVersion = 1;

  // Tự nhận diện nền tảng
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000/api'; // Android Emulator
    return 'http://localhost:5000/api'; // Web, Windows, macOS, Linux, iOS
  }
}
```

#### 📁 `frontend/pubspec.yaml`
Thêm package hỗ trợ SQLite trên Desktop:
```yaml
dependencies:
  sqflite_common_ffi: ^2.3.0
```

#### 📁 `frontend/lib/main.dart`
Khởi tạo FFI trong hàm `main()`:
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

### 3. Hướng dẫn Kiểm Thử Trên Giao Diện (UI Testing)
1. Mở Terminal tại `frontend/` và chạy trên trình duyệt: `flutter run -d chrome`.
2. Mở một Terminal khác chạy trên Windows: `flutter run -d windows` (nếu máy có cài Visual Studio C++).
3. **Quan sát:** Màn hình ứng dụng khởi động thành công, không bị văng lỗi màu đỏ liên quan đến `MissingPluginException` hay `DatabaseFactory`.

---

## STEP 1: HOÀN THIỆN BACKEND (FORCED CHECK-OUT & AUTO-EXPIRE)

### 1.1. Mục tiêu
Thêm tính năng cho phép Thủ thư cưỡng chế Check-out một sinh viên (khi sinh viên quên quẹt thẻ về) và tự động đóng phiên cũ nếu sinh viên để quên qua đêm.

### 1.2. Các tệp cần can thiệp & Mã nguồn

#### 📁 `backend/src/controllers/admin_report_controller.js`
Thêm hàm `forceCheckOutUser`:
```javascript
// POST /api/admin/realtime/checkout/:userId
async function forceCheckOutUser(req, res, next) {
  try {
    const { userId } = req.params;
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng' });
    }

    const activeLog = await CheckInLog.findOne({ userId: user._id, checkOutTime: null }).sort({ checkInTime: -1 });
    const now = new Date();

    if (activeLog) {
      activeLog.checkOutTime = now;
      activeLog.durationMinutes = Math.round((now - activeLog.checkInTime) / 60000);
      await activeLog.save();
    }

    user.isInsideLibrary = false;
    await user.save();

    res.json({
      success: true,
      message: `Đã check-out thành công cho ${user.name} (${user.studentId})`,
      data: { userId: user._id, checkOutTime: now }
    });
  } catch (err) {
    next(err);
  }
}

// Bổ sung vào module.exports:
module.exports = {
  getPresentList, getRealtimeStats, getCheckinReport,
  getUserHistory, exportReport, forceCheckOutUser
};
```

#### 📁 `backend/src/routes/admin_routes.js`
Đăng ký route mới:
```javascript
const {
  getPresentList, getRealtimeStats, getCheckinReport,
  getUserHistory, exportReport, forceCheckOutUser
} = require('../controllers/admin_report_controller');

// Dòng mới:
router.post('/realtime/checkout/:userId', forceCheckOutUser);
```

### 1.3. Hướng dẫn Kiểm Thử (Verification)
1. Chạy Backend: `cd backend && npm run dev`.
2. Kiểm tra log khởi động: `Server running on port 5000` và `Connected to MongoDB`.
3. Gửi request thử nghiệm (qua Postman hoặc cURL):
   `POST http://localhost:5000/api/admin/realtime/checkout/<fake_or_real_userId>`
4. **Kết quả mong đợi:** Nhận phản hồi JSON `{ success: true, message: ... }`.

---

## STEP 2: XÂY DỰNG TẦNG DATA & DOMAIN (CLEAN ARCHITECTURE)

### 2.1. Mục tiêu
Tạo toàn bộ Models, Data Source và Repository phía Flutter để giao tiếp chuẩn mực với Backend theo mô hình Clean Architecture (tách biệt hoàn toàn tầng dữ liệu khỏi giao diện).

### 2.2. Các tệp cần tạo

```text
frontend/lib/
├── data/
│   ├── models/
│   │   ├── system_config_model.dart      # Model cấu hình động
│   │   ├── present_student_model.dart    # Model sinh viên đang có mặt
│   │   ├── occupancy_stats_model.dart    # Model thống kê sức chứa & peak hour
│   │   ├── user_admin_model.dart         # Model thông tin user trong quản lý
│   │   └── report_data_model.dart        # Model biểu đồ thống kê
│   ├── datasources/
│   │   └── admin_remote_datasource.dart  # Chứa toàn bộ lời gọi HTTP Client
│   └── repositories/
│       └── admin_repository_impl.dart    # Triển khai interface repository
└── domain/
    ├── entities/                         # Các thực thể nghiệp vụ thuần Dart
    └── repositories/
        └── admin_repository.dart         # Abstract class định nghĩa hợp đồng gọi hàm
```

### 2.3. Hướng dẫn Kiểm Thử (Verification)
Chạy lệnh phân tích cú pháp tĩnh:
```bash
cd frontend
flutter analyze
```
**Kết quả mong đợi:** `No issues found!` — Không có lỗi import sai hoặc thiếu biến.

---

## STEP 3: FEATURE 1 - CẤU HÌNH ĐỘNG HỆ THỐNG (FR-03)

### 3.1. Mục tiêu
Thủ thư có thể điều chỉnh:
* `maxCapacity` (Sức chứa tối đa)
* `openTime` & `closeTime` (Giờ mở và đóng cửa)
* `maintenanceMode` (Chế độ bảo trì tạm đóng)
Cập nhật có hiệu lực tức thì mà không cần restart backend.

### 3.2. Các tệp cần tạo
1. `frontend/lib/presentation/bloc/config/config_bloc.dart` (và `config_event.dart`, `config_state.dart`).
2. `frontend/lib/presentation/screens/admin/tabs/system_config_tab.dart`.

### 3.3. Hướng dẫn Kiểm Thử Trên Giao Diện (UI Flow Test)
* **Kịch bản kiểm thử:**
  1. Vào ứng dụng, mở tab **Cấu hình hệ thống**.
  2. **Quan sát UI:** Form tự động tải lên các thông số hiện tại (Ví dụ: Sức chứa `100`, Giờ mở: `07:30`, Giờ đóng: `21:00`).
  3. Sửa `Sức chứa tối đa` từ `100` thành `2` (để test thư viện đầy ở Step sau).
  4. Bấm vào ô **Giờ mở cửa** $\rightarrow$ Popup `TimePicker` mở lên $\rightarrow$ Chọn `08:00` $\rightarrow$ Nhấn OK.
  5. Bấm nút **"LƯU CẤU HÌNH"**.
  6. **Kết quả mong đợi trên UI:**
     - Nút chuyển trạng thái loading nhẹ.
     - Xuất hiện thanh `SnackBar` màu xanh dưới đáy màn hình: *"Cập nhật cấu hình thành công"*.
     - Giá trị mới lưu vĩnh viễn trên Server (tải lại trang dữ liệu vẫn giữ nguyên `2` chỗ và `08:00`).

---

## STEP 4: FEATURE 2 - GIÁM SÁT THỜI GIAN THỰC & FORCED CHECK-OUT

### 4.1. Mục tiêu
Thủ thư xem được tỷ lệ lấp đầy trực quan (thay đổi màu sắc theo %), xem danh sách sinh viên đang ngồi học với thời gian tăng dần theo phút, và có nút mời ra (check-out thủ công).

### 4.2. Các tệp cần tạo
1. `frontend/lib/presentation/bloc/realtime/realtime_bloc.dart` (có timer polling mỗi 4 giây).
2. `frontend/lib/presentation/screens/admin/tabs/live_occupancy_tab.dart`.

### 4.3. Hướng dẫn Kiểm Thử Trên Giao Diện (UI Flow Test)
* **Kịch bản 4A: Kiểm tra độ nhạy thời gian thực**
  1. Mở tab **Live Occupancy**.
  2. **Quan sát Card đầu trang:**
     - Hiển thị thanh tiến trình: `X / 2 chỗ (Y%)`.
     - Nếu dưới 70%: Thanh màu **Xanh lá**.
     - Nếu 70% - 90%: Thanh màu **Vàng cam**.
     - Nếu đạt 100%: Thanh màu **Đỏ** kèm nhãn cảnh báo *"ĐÃ HẾT CHỖ"*.
  3. Cho 1 sinh viên quét thẻ vào $\rightarrow$ Sau 4 giây, không cần bấm refresh, số lượng trên Dashboard tự nhảy tăng lên 1, tên sinh viên hiện lên trong danh sách.

* **Kịch bản 4B: Kiểm thử Forced Check-out (Mời ra thủ công)**
  1. Trong danh sách người đang có mặt, tìm sinh viên cần mời ra.
  2. Bấm vào nút màu đỏ có biểu tượng **Đăng xuất / Mời ra** bên cạnh tên sinh viên.
  3. **Quan sát UI:** Bật lên hộp thoại xác nhận: *"Xác nhận mời sinh viên [Tên] rời khỏi thư viện?"*.
  4. Bấm **"Xác nhận"**.
  5. **Kết quả mong đợi trên UI:**
     - `SnackBar` xanh thông báo: *"Đã check-out thành công cho [Tên]"*.
     - Sinh viên lập tức biến mất khỏi danh sách.
     - Số người trên thanh đo sức chứa giảm đi 1.

---

## STEP 5: FEATURE 3 - TRẠM QUÉT QR & NHẬP TAY DỰ PHÒNG (FR-02)

### 5.1. Mục tiêu
Thiết bị của Thủ thư đóng vai trò là Trạm quét tại cửa:
* Quét mã thẻ điện tử trên màn hình sinh viên bằng Camera.
* Hỗ trợ thanh gõ tay MSSV (dành cho Web/Desktop hoặc trường hợp camera hỏng).
* Tự động nhận diện: Nếu sinh viên đang ở ngoài $\rightarrow$ Check-in; Nếu đang ở trong $\rightarrow$ Check-out.

### 5.2. Các tệp cần tạo
1. `frontend/lib/presentation/bloc/scanner/scanner_bloc.dart`.
2. `frontend/lib/presentation/screens/admin/tabs/qr_scanner_tab.dart` (hoặc modal scanner).

### 5.3. Hướng dẫn Kiểm Thử Trên Giao Diện (UI Flow Test)
* **Kịch bản 5A: Quét Check-In & Check-Out bằng Camera**
  1. Nhấn nút Camera tại Trạm quét.
  2. Đưa mã QR thẻ của Sinh viên A vào khung quét.
  3. **Kết quả mong đợi:**
     - Lần 1: Bật hộp thoại màu Xanh lá: *"CHECK-IN THÀNH CÔNG - Sinh viên: Nguyễn Văn A (HE190001) - Giờ vào: 09:30"*.
     - Lần 2 (quét lại sinh viên A): Hộp thoại màu Xanh dương: *"CHECK-OUT THÀNH CÔNG - Thời gian ngồi học: 15 phút"*.

* **Kịch bản 5B: Kiểm thử Nhập tay bàn phím (Desktop/Web Fallback)**
  1. Trên giao diện, không bật camera mà gõ vào ô nhập: `HE190001` rồi nhấn phím `Enter` (hoặc nhấn nút "Kiểm tra").
  2. **Kết quả mong đợi:** Hệ thống xử lý tương tự như khi quét camera, check-in/out thành công.

* **Kịch bản 5C: Kiểm thử Từ chối khi Thư viện đầy (Max Capacity)**
  1. Tại Step 3 ta đã đặt `maxCapacity = 2`. Cho 2 sinh viên check-in $\rightarrow$ Thư viện đạt `2/2 chỗ`.
  2. Sinh viên thứ 3 đưa thẻ vào quét.
  3. **Kết quả mong đợi trên UI:** Bật hộp thoại màu Đỏ: *"TỪ CHỐI CHECK-IN - Lý do: Thư viện đã đầy sức chứa (2/2 chỗ)"*.

---

## STEP 6: FEATURE 4 - QUẢN LÝ THÀNH VIÊN & KHÓA THẺ (FR-01)

### 6.1. Mục tiêu
Thủ thư quản lý danh sách sinh viên, tìm kiếm theo tên/MSSV và có công tắc khóa/mở thẻ sinh viên vi phạm nội quy.

### 6.2. Các tệp cần tạo
1. `frontend/lib/presentation/bloc/user_management/user_management_bloc.dart`.
2. `frontend/lib/presentation/screens/admin/tabs/user_management_tab.dart`.

### 6.3. Hướng dẫn Kiểm Thử Trên Giao Diện (UI Flow Test)
* **Kịch bản kiểm thử:**
  1. Mở tab **Quản lý thành viên**.
  2. **Quan sát UI:** Danh sách sinh viên tải lên đầy đủ kèm Avatar, Tên, Mã SV, và Chip trạng thái (Màu xanh: `HOẠT ĐỘNG`).
  3. Gõ vào ô tìm kiếm: `HE190003` $\rightarrow$ Danh sách tự lọc hiển thị đúng sinh viên Lê Văn C.
  4. Gạt công tắc `Switch` của sinh viên C sang chế độ **Khóa (LOCKED)**.
  5. **Quan sát UI:** Chip trạng thái đổi ngay sang màu Đỏ (`BỊ KHÓA`).
  6. Đưa thẻ của sinh viên C ra Trạm quét ở Step 5 để quét vào.
  7. **Kết quả mong đợi trên UI:** Trạm quét báo lỗi đỏ: *"TỪ CHỐI CHECK-IN - Tài khoản của bạn đã bị khóa"*.
  8. Quay lại gạt mở khóa $\rightarrow$ Quét lại thẻ $\rightarrow$ Cho phép vào bình thường.

---

## STEP 7: FEATURE 5 - BIỂU ĐỒ THỐNG KÊ & XUẤT CSV (FR-04)

### 7.1. Mục tiêu
Hiển thị biểu đồ phân bố lượt ra vào trực quan bằng package `fl_chart` theo các khung giờ cao điểm và hỗ trợ tải báo cáo CSV có dấu tiếng Việt UTF-8.

### 7.2. Các tệp cần tạo
1. `frontend/lib/presentation/bloc/report/report_bloc.dart`.
2. `frontend/lib/presentation/screens/admin/tabs/report_analytics_tab.dart`.

### 7.3. Hướng dẫn Kiểm Thử Trên Giao Diện (UI Flow Test)
* **Kịch bản kiểm thử:**
  1. Mở tab **Báo cáo & Thống kê**.
  2. **Quan sát thẻ chỉ số đầu trang:** Hiển thị 3 chỉ số lớn:
     - *Tổng lượt vào hôm nay:* Ví dụ `24 lượt`.
     - *Đang có mặt:* `2 người`.
     - *Khung giờ cao điểm:* `09:00 - 10:00`.
  3. **Quan sát Biểu đồ cột (`fl_chart`):**
     - Trục hoành hiển thị các mốc giờ: `08:00, 10:00, 12:00, 14:00,...`.
     - Trục tung hiển thị số lượt sinh viên. Cột giờ cao điểm cao nhất.
     - Chạm chuột hoặc ngón tay vào cột $\rightarrow$ Hiển thị Tooltip số lượng chính xác.
  4. Nhấn nút **"XUẤT BÁO CÁO CSV"**.
  5. **Kết quả mong đợi:** Trình duyệt hoặc hệ điều hành tải file `library_report_*.csv` về máy. Mở file bằng Excel, kiểm tra cột `Họ và tên` không bị lỗi font tiếng Việt.

---

## STEP 8: GHÉP NỐI ADMIN DASHBOARD (RESPONSIVE LAYOUT)

### 8.1. Mục tiêu
Tập hợp 4 Tab đã làm ở các Step trên vào màn hình chính [admin_dashboard_screen.dart](file:///d:/1.%20Ki8/PRM/LibIOG4/frontend/lib/presentation/screens/admin/admin_dashboard_screen.dart), hỗ trợ co giãn theo kích thước màn hình:
* **Màn hình Mobile (chiều rộng < 750px):** Dùng `BottomNavigationBar` ở dưới đáy màn hình.
* **Màn hình Web / Desktop (chiều rộng $\ge$ 750px):** Dùng `NavigationRail` (Menu thanh dọc bên trái) chuẩn phong cách Dashboard chuyên nghiệp.

### 8.2. Hướng dẫn Kiểm Thử Trên Giao Diện (UI Flow Test)
1. Chạy trên trình duyệt Web: `flutter run -d chrome`.
2. Kéo thu nhỏ cửa sổ trình duyệt về kích thước điện thoại $\rightarrow$ Thanh menu tự động nhảy xuống đáy (`BottomNavigationBar`).
3. Kéo rộng cửa sổ trình duyệt ra toàn màn hình $\rightarrow$ Thanh menu tự động chuyển sang thanh cột dọc bên trái (`NavigationRail`).
4. Bấm chuyển qua lại giữa cả 4 Tab: Mượt mà, không bị load lại từ đầu, giữ nguyên trạng thái.

---

## STEP 9: BỘ KIỂM THỬ TỰ ĐỘNG (UNIT TEST & WIDGET TEST)

### 9.1. Mục tiêu
Thực hiện đầy đủ tiêu chuẩn kiểm thử đề bài yêu cầu để đạt điểm tối đa (Unit Test cho BLoC và Widget Test cho UI).

### 9.2. Các tệp cần tạo
* `frontend/test/presentation/bloc/admin_config_bloc_test.dart`
* `frontend/test/presentation/screens/system_config_tab_test.dart`

### 9.3. Hướng dẫn Chạy Kiểm Thử (Terminal Execution)
Chạy lệnh kiểm thử tự động của Flutter:
```bash
cd frontend
flutter test
```
**Kết quả mong đợi:**
```text
00:02 +4: All tests passed!
```
Tất cả các test case đều xanh (Pass 100%), sẵn sàng chụp ảnh màn hình đưa vào báo cáo nghiệm thu đồ án.
