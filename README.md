# Hệ Thống Ghi Nhận Ra Vào Thư Viện (Library Access Management System)

Dự án quản lý và ghi nhận lượt ra/vào thư viện đa nền tảng, được phân chia theo kiến trúc Client - Server rõ ràng:

- **Frontend (Client):** Ứng dụng Flutter đa nền tảng (Android, iOS, Web, Desktop) theo mô hình Clean Architecture (BLoC Pattern).
- **Backend (Service):** REST API Server xây dựng bằng Node.js & Express.

---

## Danh Sách Thành Viên (Team Members)

- **Thành viên 1:** _Nguyễn Thanh Minh (Leader)_ - MSSV: HE194951
- **Thành viên 2:** _Trần Đức Mạnh_ - MSSV: HE190209
- **Thành viên 3:** _Bùi Tuấn Dương_ - MSSV: HE194936
- **Thành viên 4:** _Nguyễn Trần An_ - MSSV: HE194988
- **Thành viên 5:** _Nguyễn Đức Thiện Cầm_ - MSSV: HE195082

---

## Tổng Quan Dự Án

### Mục tiêu kỹ thuật

- **Nền tảng:** Đa nền tảng (Android, iOS >= 10.0, Web, macOS, Windows, Linux).
- **Frontend Framework:** Flutter & Dart.
- **Backend Framework:** Node.js & Express REST API.
- **Kiến trúc:**
  - Tách biệt rõ `frontend/` và `backend/`.
  - Frontend áp dụng Clean Architecture: phân tách rõ UI/Presentation, Domain/Logic, Data (Database/Remote API).
- **Design Pattern:** BLoC / Repository Pattern.
- **Tối ưu & Mở rộng:** Xử lý bất đồng bộ (`async`/`await`, `Streams`), đồng bộ dữ liệu ngoại tuyến (Offline Sync với SQLite), thông báo đẩy thời gian thực qua Firebase Cloud Messaging (FCM).
- **Kiểm thử (Testing):** Hỗ trợ đầy đủ Unit Test, Widget Test, Integration Test và API Test.

### Lộ trình thực hiện (Roadmap)

1. **SRS:** Xây dựng đặc tả yêu cầu hệ thống.
2. **Design:** Thiết kế giao diện (UI/UX), cơ sở dữ liệu (Database Schema), kiến trúc hệ thống và luồng thuật toán.
3. **Implementation:** Lập trình Frontend Flutter và Backend Services Node.js Express.
4. **Testing:** Triển khai test suites (Unit, Widget, Integration) và tổng hợp báo cáo.
5. **Release & Demo:** Đóng gói sản phẩm, viết báo cáo tổng kết và chuẩn bị demo.

---

## Cấu Trúc Thư Mục Dự Án (Project Structure)

```text
.
├── backend/                        # Node.js + Express REST API
│   ├── src/
│   │   ├── controllers/            # Xử lý logic API (Auth, Logs, Config)
│   │   │   ├── auth_controller.js
│   │   │   ├── checkin_controller.js
│   │   │   └── config_controller.js
│   │   ├── routes/                 # Định tuyến API
│   │   │   ├── auth_routes.js
│   │   │   ├── checkin_routes.js
│   │   │   └── config_routes.js
│   │   ├── middleware/             # Middleware (Error handling, CORS)
│   │   │   └── error_middleware.js
│   │   └── app.js                  # Cấu hình Express app
│   ├── server.js                   # Điểm khởi chạy backend (port 5000)
│   ├── package.json
│   ├── .env.example
│   └── .gitignore
├── frontend/                       # Flutter Application (Clean Architecture)
│   ├── android/                    # Mã nguồn nền tảng Android
│   ├── ios/                        # Mã nguồn nền tảng iOS
│   ├── linux/                      # Nền tảng Linux desktop
│   ├── macos/                      # Nền tảng macOS desktop
│   ├── web/                        # Nền tảng Web
│   ├── windows/                    # Nền tảng Windows desktop
│   ├── lib/
│   │   ├── core/                   # Cấu hình chung, Constants, ApiClient
│   │   │   ├── constants/app_constants.dart
│   │   │   ├── network/api_client.dart
│   │   │   └── utils/helpers.dart
│   │   ├── data/                   # Datasources, Models, Repositories Impl
│   │   │   ├── datasources/
│   │   │   │   ├── local_db_helper.dart
│   │   │   │   └── remote_api_service.dart
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/                 # Entities, Repository Interfaces, Use Cases
│   │   │   ├── entities/
│   │   │   └── repositories/
│   │   ├── presentation/           # Giao diện (Screens) và State Management (BLoC)
│   │   │   ├── bloc/
│   │   │   └── screens/
│   │   └── main.dart               # Entry point ứng dụng Flutter
│   ├── test/                       # Unit & Widget Tests
│   ├── pubspec.yaml                # Khai báo thư viện & tài nguyên Flutter
│   └── analysis_options.yaml
├── .gitignore                      # Root gitignore
└── README.md                       # Tài liệu dự án
```

---

## Hướng Dẫn Khởi Chạy (Quick Start)

### 1. Khởi chạy Backend (Node.js & MongoDB)

Cần có MongoDB đang chạy cục bộ (`mongodb://localhost:27017`) hoặc URI từ MongoDB Atlas qua biến môi trường `MONGODB_URI`.

```bash
cd backend
npm install
npm run seed     # Khởi chạy database với MongoDB
npm run dev      # Khởi chạy server development (port 5000)
```

Các endpoint chính:

- `GET /api/health` - Kiểm tra trạng thái máy chủ
- `POST /api/auth/register` - Đăng ký tài khoản mới
- `POST /api/auth/login` - Đăng nhập tài khoản
- `POST /api/users/register-device` - Đăng ký device token cho Firebase Push Notification
- `GET /api/auth/user/:id` - Lấy thông tin người dùng theo ID
- `GET /api/logs` - Lấy danh sách lượt ra vào từ MongoDB
- `POST /api/logs` - Ghi nhận lượt check-in/out mới
- `POST /api/logs/sync` - Đồng bộ dữ liệu log từ offline vào MongoDB
- `GET /api/config` - Lấy cấu hình hệ thống
- `PUT /api/config` - Cập nhật cấu hình hệ thống

### 2. Khởi chạy Frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run
```
