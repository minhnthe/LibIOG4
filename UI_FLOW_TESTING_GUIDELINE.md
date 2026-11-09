# GUIDELINE KIỂM THỬ FLOW TRÊN GIAO DIỆN (UI FLOW TESTING)
**Dự án:** Hệ Thống Ghi Nhận Ra Vào Thư Viện (LibIOG4)  
**Phân hệ:** Quản Trị & Thủ Thư (Admin / Librarian)  
**Mục đích:** Hướng dẫn chi tiết từng bước kiểm thử luồng thực tế (End-to-End Flow Test) trên giao diện ứng dụng để nghiệm thu tính năng, chuẩn bị kịch bản Demo và đưa vào Báo cáo kiểm thử (Testing Report).

---

## 📑 MỤC LỤC
1. [Chuẩn Bị Môi Trường & Dữ Liệu Test](#1-chuẩn-bị-môi-trường--dữ-liệu-test)
2. [Flow 1: Đăng Nhập & Phân Quyền Thủ Thư](#flow-1-đăng-nhập--phân-quyền-thủ-thư)
3. [Flow 2: Kiểm Thử Cấu Hình Động Hệ Thống (FR-03)](#flow-2-kiểm-thử-cấu-hình-động-hệ-thống-fr-03)
4. [Flow 3: Kiểm Thử Trạm Quét QR & Access Control Engine (FR-02)](#flow-3-kiểm-thử-trạm-quét-qr--access-control-engine-fr-02)
5. [Flow 4: Kiểm Thử Giám Sát Thời Gian Thực & Forced Check-Out](#flow-4-kiểm-thử-giám-sát-thời-gian-thực--forced-check-out)
6. [Flow 5: Kiểm Thử Quản Lý Thành Viên & Khóa Thẻ (FR-01)](#flow-5-kiểm-thử-quản-lý-thành-viên--khóa-thẻ-fr-01)
7. [Flow 6: Kiểm Thử Biểu Đồ Thống Kê & Xuất Báo Cáo CSV (FR-04)](#flow-6-kiểm-thử-biểu-đồ-thống-kê--xuất-báo-cáo-csv-fr-04)
8. [Flow 7: Kiểm Thử Chế Độ Ngoại Tuyến (Offline Mode & Sync)](#flow-7-kiểm-thử-chế-độ-ngoại-tuyến-offline-mode--sync)
9. [Bảng Tổng Hợp Ma Trận Kiểm Thử (Test Execution Matrix)](#9-bảng-tổng-hợp-ma-trận-kiểm-thử-test-execution-matrix)

---

## 1. CHUẨN BỊ MÔI TRƯỜNG & DỮ LIỆU TEST

### 1.1. Khởi động Backend & Cơ sở dữ liệu
```bash
# Terminal 1: Khởi động Backend
cd backend
npm install
npm run dev
# Server lắng nghe tại: http://localhost:5000 (MongoDB đã kết nối)
```

### 1.2. Khởi động Frontend Flutter
Chạy trên môi trường bất kỳ (Web, Windows Desktop hoặc Mobile):
```bash
# Terminal 2: Khởi động Flutter
cd frontend
flutter pub get
flutter run -d chrome       # Hoặc: flutter run -d windows / flutter run
```

### 1.3. Tài khoản & Dữ liệu mẫu chuẩn bị sẵn
| Tài khoản | Email / Tên đăng nhập | Mật khẩu | Vai trò | Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| **Admin** | `admin@library.com` | `admin123` | `admin` | Thủ thư quản trị |
| **Sinh viên A** | `HE190001` (Nguyễn Văn A) | `123456` | `student` | Thẻ ACTIVE, còn hạn |
| **Sinh viên B** | `HE190002` (Trần Thị B) | `123456` | `student` | Dùng test sức chứa |
| **Sinh viên C** | `HE190003` (Lê Văn C) | `123456` | `student` | Dùng test khóa tài khoản |

---

## FLOW 1: ĐĂNG NHẬP & PHÂN QUYỀN THỦ THƯ

* **Mục tiêu:** Đảm bảo hệ thống nhận diện đúng vai trò Admin và điều hướng chính xác vào Dashboard Quản trị.

| Bước | Thao tác trên giao diện | Dữ liệu nhập | Kết quả mong đợi (UI) |
| :---: | :--- | :--- | :--- |
| **1.1** | Mở ứng dụng, hiển thị màn hình Đăng nhập. | URL backend hiển thị đúng theo platform. | Màn hình hiển thị form: Tên đăng nhập, Mật khẩu, Nút Đăng nhập. |
| **1.2** | Nhập sai mật khẩu để test validation. | Email: `admin@library.com`<br>Pass: `wrongpass` | Nút đăng nhập loading $\rightarrow$ Hiện thông báo đỏ: *"Sai email hoặc mật khẩu"*. |
| **1.3** | Nhập đúng thông tin Admin và bấm **Đăng nhập**. | Email: `admin@library.com`<br>Pass: `admin123` | Chuyển hướng ngay sang **Admin Dashboard Screen**, hiển thị AppBar *"Quản trị hệ thống"* và 4 Tab điều hướng. |
| **1.4** | Thử đăng nhập bằng tài khoản Sinh viên. | Email: `HE190001`<br>Pass: `123456` | Ứng dụng điều hướng vào màn hình Thẻ sinh viên, **không cho phép** truy cập vào Admin Dashboard. |

---

## FLOW 2: KIỂM THỬ CẤU HÌNH ĐỘNG HỆ THỐNG (FR-03)

* **Mục tiêu:** Kiểm tra khả năng thay đổi sức chứa tối đa và giờ mở/đóng cửa trực tiếp trên App mà **không cần re-deploy hay khởi động lại server**.

| Bước | Thao tác trên giao diện | Dữ liệu nhập | Kết quả mong đợi (UI) |
| :---: | :--- | :--- | :--- |
| **2.1** | Chuyển sang **Tab 2: Cấu hình hệ thống**. | - | Form hiển thị các giá trị hiện tại (VD: Sức chứa: 100, Mở: 07:30, Đóng: 21:00). |
| **2.2** | Thay đổi sức chứa tối đa xuống `2` chỗ (để chuẩn bị test kịch bản quá tải ở Flow 3). | `maxCapacity` = `2` | Ô nhập nhận giá trị số 2. |
| **2.3** | Bấm vào ô **Giờ mở cửa** / **Giờ đóng cửa**. | Chọn giờ hiện tại $\pm$ 2 tiếng | Popup `TimePicker` mở ra mượt mà, chọn giờ xong cập nhật lên text field. |
| **2.4** | Bấm nút **"Lưu cấu hình"**. | - | Nút loading $\rightarrow$ Hiện `SnackBar` xanh: *"Cập nhật cấu hình thành công"*. |
| **2.5** | Quay lại **Tab 1: Live Occupancy**. | - | Thấy ngay thông số sức chứa tối đa đã đổi thành `/2 chỗ` ngay lập tức. |

---

## FLOW 3: KIỂM THỬ TRẠM QUÉT QR & ACCESS CONTROL ENGINE (FR-02)

* **Mục tiêu:** Kiểm tra trạm quét tại quầy của Thủ thư, thử nghiệm cả 2 cách: Camera quét QR và Gõ mã thủ công.

### Kịch bản 3A: Quét Check-In thành công
1. **Thao tác:** 
   - Tại Tab 1 hoặc Tab Quét mã, bấm mở Camera (hoặc gõ chuỗi QR thẻ mẫu của SV A: `LIB:HE190001:USER_ID_A:1999999999`).
   - Bấm **"Ghi nhận"**.
2. **Kết quả mong đợi:**
   - Popup/Card thông báo màu xanh: *"Check-in thành công: Nguyễn Văn A (HE190001)"*.
   - Chỉ số sức chứa trên Dashboard tăng từ `0/2` lên `1/2` (50% - Màu xanh lá).
   - Tên sinh viên A xuất hiện ngay trong danh sách người đang có mặt cùng thời gian check-in.

### Kịch bản 3B: Quét Check-In khi THƯ VIỆN ĐÃ ĐẦY SỨC CHỨA
1. **Tiền điều kiện:** `maxCapacity` đang đặt là `2`. Đã có 2 sinh viên check-in (sức chứa đạt `2/2` - 100% - Thanh chuyển sang Màu Đỏ).
2. **Thao tác:** Sinh viên C quét mã QR muốn vào thư viện.
3. **Kết quả mong đợi:**
   - Hệ thống từ chối vào.
   - Popup cảnh báo màu đỏ: *"Từ chối Check-in: Thư viện đã đầy (2/2 chỗ)"*.
   - Số người không tăng, không tạo thêm log sai.

### Kịch bản 3C: Quét ngoài giờ mở cửa
1. **Thao tác:** Vào Tab Cấu hình, chỉnh `openTime` và `closeTime` thành khung giờ trong quá khứ $\rightarrow$ Quét thử mã sinh viên.
2. **Kết quả mong đợi:**
   - Hệ thống từ chối: *"Thư viện mở cửa lúc XX:XX - YY:YY"*.

### Kịch bản 3D: Quét Check-Out thành công
1. **Thao tác:** Quét lại mã QR của Sinh viên A (người đang ở trong thư viện).
2. **Kết quả mong đợi:**
   - Hệ thống tự nhận diện sinh viên đang ở trong $\rightarrow$ Chuyển thành hành động **Check-out**.
   - Popup xanh: *"Check-out thành công. Thời gian ngồi: X phút"*.
   - Số người giảm từ `2/2` xuống `1/2`.
   - Sinh viên A lập tức biến mất khỏi danh sách người đang có mặt.

---

## FLOW 4: KIỂM THỬ GIÁM SÁT THỜI GIAN THỰC & FORCED CHECK-OUT

* **Mục tiêu:** Đảm bảo Admin theo dõi được danh sách sinh viên theo thời gian thực và xử lý được trường hợp sinh viên ra về mà quên quẹt thẻ.

| Bước | Thao tác trên giao diện | Dữ liệu test | Kết quả mong đợi (UI) |
| :---: | :--- | :--- | :--- |
| **4.1** | Mở **Tab 1: Live Occupancy**. | Có 2 sinh viên đang ở bên trong. | Danh sách hiển thị: Họ tên, MSSV, Giờ vào, Số phút đã ngồi (tự tăng theo thời gian). |
| **4.2** | Giả lập sinh viên B về nhưng quên quét thẻ. | Sinh viên B `HE190002` | Thủ thư thấy sinh viên B vẫn còn hiển thị trên danh sách. |
| **4.3** | Thủ thư bấm vào nút màu đỏ **"Mời ra / Check-out"** cạnh tên sinh viên B. | - | Hiển thị Dialog xác nhận: *"Bạn có chắc muốn check-out thủ công cho Trần Thị B?"*. |
| **4.4** | Bấm **"Xác nhận"**. | - | Gọi API `POST /api/admin/realtime/checkout/:userId` $\rightarrow$ Hiện thông báo: *"Đã check-out thành công"*. |
| **4.5** | Quan sát giao diện Dashboard. | - | Sinh viên B biến mất khỏi danh sách, số chỗ trống tăng thêm 1 ngay lập tức. |

---

## FLOW 5: KIỂM THỬ QUẢN LÝ THÀNH VIÊN & KHÓA THẺ (FR-01)

* **Mục tiêu:** Kiểm tra chức năng tìm kiếm, xem hồ sơ và khóa/mở thẻ sinh viên khi vi phạm nội quy.

| Bước | Thao tác trên giao diện | Dữ liệu test | Kết quả mong đợi (UI) |
| :---: | :--- | :--- | :--- |
| **5.1** | Chuyển sang **Tab 3: Quản lý thành viên**. | - | Danh sách sinh viên tải lên dạng thẻ (Card/ListTile) kèm avatar, MSSV và Badge trạng thái (`ACTIVE` / `LOCKED`). |
| **5.2** | Gõ vào ô tìm kiếm MSSV. | `HE190003` | Danh sách tự động lọc ra đúng sinh viên Lê Văn C. |
| **5.3** | Gạt nút Switch trạng thái sang **Khóa (LOCKED)**. | - | Trạng thái chuyển thành màu Đỏ (`LOCKED`), gọi API `PATCH /users/:id/status`. |
| **5.4** | Đưa sinh viên Lê Văn C ra quẹt thẻ tại Trạm quét. | Quét mã QR của C | Trạm quét báo lỗi đỏ: *"Tài khoản bị khóa - Không thể check-in"*. |
| **5.5** | Quay lại Tab 3, gạt mở khóa lại (`ACTIVE`). | - | Quẹt lại thẻ $\rightarrow$ Cho phép Check-in bình thường. |

---

## FLOW 6: KIỂM THỬ BIỂU ĐỒ THỐNG KÊ & XUẤT BÁO CÁO CSV (FR-04)

* **Mục tiêu:** Kiểm tra khả năng trực quan hóa dữ liệu và trích xuất báo cáo lưu lượng phục vụ công tác thư viện.

| Bước | Thao tác trên giao diện | Thao tác chi tiết | Kết quả mong đợi (UI) |
| :---: | :--- | :--- | :--- |
| **6.1** | Chuyển sang **Tab 4: Thống kê & Báo cáo**. | - | Hiển thị 3 chỉ số tổng quan đầu trang: Tổng lượt ra vào hôm nay, Số người hiện tại, Giờ cao điểm (Peak hour). |
| **6.2** | Xem biểu đồ phân bố lưu lượng (`fl_chart`). | Chuyển bộ lọc: Theo Giờ / Theo Ngày / Theo Tuần | Biểu đồ cột tự động vẽ lại các cột tương ứng với số lượt check-in. Rê chuột/chạm vào cột hiển thị tooltip số lượng. |
| **6.3** | Nhấn nút **"Xuất file CSV"**. | Bấm nút Tải xuống / Export CSV | Trình duyệt hoặc hệ điều hành bật popup tải file `library_report_*.csv`. |
| **6.4** | Mở file CSV vừa tải bằng Excel hoặc Notepad. | Kiểm tra nội dung file | Dữ liệu có đủ cột: `STT, Mã SV, Họ tên, Giờ vào, Giờ ra, Thời gian lưu`, hiển thị đúng font tiếng Việt UTF-8 không lỗi. |

---

## FLOW 7: KIỂM THỬ CHẾ ĐỘ NGOẠI TUYẾN (OFFLINE MODE & SYNC)

* **Mục tiêu:** Thể hiện tiêu chí điểm cao của đề bài: Hệ thống vẫn hoạt động ghi nhận khi mất mạng và tự động đồng bộ khi có mạng trở lại.

| Bước | Thao tác thực hiện | Mô phỏng | Kết quả mong đợi (UI) |
| :---: | :--- | :--- | :--- |
| **7.1** | Ngắt kết nối mạng (Tắt Wi-Fi hoặc tạm dừng Backend `Ctrl+C`). | Mất mạng | Trên Header của ứng dụng hiện thông báo/icon cảnh báo: *"Chế độ Offline (Chưa có kết nối)"*. |
| **7.2** | Quét thẻ sinh viên A tại quầy. | Quét mã QR | Ứng dụng **không bị crash**, hiển thị thông báo vàng: *"Đã lưu log ngoại tuyến vào bộ nhớ máy (Chờ đồng bộ)"*. Dữ liệu lưu vào SQLite cục bộ. |
| **7.3** | Bật lại kết nối mạng (hoặc chạy lại `npm run dev`). | Có mạng lại | Icon trạng thái chuyển sang Xanh (Online). |
| **7.4** | Bấm nút **"Đồng bộ ngay"** (hoặc để tự động chạy nền). | Gọi API `/api/checkin/sync` | Thông báo xanh: *"Đồng bộ thành công X lượt ghi nhận lên máy chủ"*. Dashboard cập nhật lại số liệu chính xác. |

---

## 9. BẢNG TỔNG HỢP MA TRẬN KIỂM THỬ (TEST EXECUTION MATRIX)

*Dùng bảng này để tích dấu kiểm tra và chụp màn hình đưa vào Báo Cáo Đồ Án (Testing Report):*

| Test ID | Tên Kịch Bản Kiểm Thử | Phân loại | Kết quả (Pass/Fail) | Người thực hiện |
| :--- | :--- | :--- | :---: | :---: |
| **TC-01** | Đăng nhập Admin & Phân quyền chuẩn xác | Functional | [ ] Pass | ManhTD |
| **TC-02** | Điều chỉnh cấu hình động không cần restart | Functional | [ ] Pass | ManhTD |
| **TC-03** | Check-in / Check-out thẻ hợp lệ qua QR & Nhập tay | Functional | [ ] Pass | ManhTD |
| **TC-04** | Chặn Check-in khi vượt quá sức chứa tối đa | Logic/Engine | [ ] Pass | ManhTD |
| **TC-05** | Chặn Check-in ngoài khung giờ mở cửa | Logic/Engine | [ ] Pass | ManhTD |
| **TC-06** | Forced Check-out cho sinh viên quên quẹt thẻ | Admin Action | [ ] Pass | ManhTD |
| **TC-07** | Khóa thẻ sinh viên vi phạm & Chặn quét thẻ | Security/Admin | [ ] Pass | ManhTD |
| **TC-08** | Vẽ biểu đồ thống kê lưu lượng bằng `fl_chart` | UI/Analytics | [ ] Pass | ManhTD |
| **TC-09** | Xuất báo cáo CSV chuẩn tiếng Việt UTF-8 | Reporting | [ ] Pass | ManhTD |
| **TC-10** | Quét thẻ Offline lưu SQLite & Auto-sync khi Online | Offline/Async | [ ] Pass | ManhTD |
