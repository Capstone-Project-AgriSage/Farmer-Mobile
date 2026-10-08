# AgriSage — Farmer Mobile App

Ứng dụng Flutter (Android) cho nông dân: xem sản phẩm, đặt hàng giao tận nơi, thanh toán payOS hoặc ghi nợ, theo dõi đơn và giao hàng, xem Sổ nợ. Nói chuyện với backend AgriSage (`Backend-Agrisage`).

> Tình trạng: đang chuyển từ giao diện dữ liệu giả sang API thật theo từng lát (xem "Lộ trình"). Màn nào chưa có API ở backend (Bác sĩ AI, Tin tức, Thông báo) hiện "Sắp ra mắt".

## Công cụ
- Flutter **3.44.0** (Dart 3.12). Pin phiên bản này khi build và trong CI.
- JDK **17 trở lên** (đang dùng JDK 21): `flutter config --jdk-dir "<đường dẫn JDK 21>"`.
- Android SDK (platform 34 trở lên) và `adb` trong PATH.
- Thư viện chính: `go_router`, `flutter_riverpod` (viết tay, không sinh code), `dio`, `flutter_secure_storage`, `webview_flutter` (trang thanh toán payOS), `image_picker`.

## Chạy app
1. Chạy backend bằng profile **http** (không dùng profile https: nó chuyển hướng sang cổng 7068 có chứng chỉ không tin cậy):
   ```bash
   dotnet run --project src/AgriSage.Api --launch-profile http   # http://localhost:5206
   ```
   Cấu hình `appsettings.Local.json` của bạn (khóa payOS, `PayOS:Mode=Simulated` nếu muốn thanh toán thử) giữ như lâu nay.
2. Emulator (đã tạo sẵn `agrisage_pixel7`) hoặc điện thoại:
   ```bash
   flutter emulators --launch agrisage_pixel7
   flutter run --dart-define-from-file=env/emulator.json      # emulator gọi máy chủ qua 10.0.2.2
   ```
   Điện thoại cắm USB: `adb reverse tcp:5206 tcp:5206`, chép `env/device.example.json` thành `env/device.json` rồi
   `flutter run --dart-define-from-file=env/device.json`.
3. Tài khoản thử: lấy trong `NOTE/demo-accounts.txt` (mật khẩu không nằm trong code hay git).

## Kiểm tra trước khi gửi PR
```bash
flutter pub get
flutter analyze        # phải 0 lỗi
flutter test
flutter build apk --debug
```
CI (`.github/workflows/flutter-ci.yml`) chạy `analyze` và `test` cho mỗi PR.

## Thanh toán payOS và công cụ dev
- Thanh toán mở `checkoutUrl` trong WebView; app chặn link trả về/hủy (so theo **path**, cấu hình `PAYOS_RETURN_PATH` / `PAYOS_CANCEL_PATH`) và luôn hỏi server kết quả, không tin `status=PAID` trên link.
- Backend ở chế độ `PayOS:Mode=Simulated` thì link chính là trang trả về: màn kết quả hiện nút "Thanh toán nhanh (môi trường thử)".
- Khi `SHOW_DEV_TOOLS=true` (có trong `env/emulator.json`), màn Tài khoản có mục "Công cụ phát triển" để thử WebView với trang giả: xem `tool/payos_webview_test/README.md`.

## Cấu trúc
```
lib/
├── core/           # Cấu hình, mạng (dio), phiên đăng nhập, tiện ích, widget dùng chung, theme
├── features/       # Mỗi module: data (model, repository), providers, screens
├── router/         # GoRouter + chặn truy cập khi chưa đăng nhập
└── shared/         # Khung điều hướng (app_shell)
env/                # Cấu hình theo môi trường (--dart-define-from-file)
```

## Quy ước làm việc
- Nhánh: `feature/mobile-<tên lát>` (ví dụ `feature/mobile-auth`), mỗi lát một PR. Chỉ merge khi trưởng nhóm đồng ý.
- Không commit bí mật (khóa, mật khẩu, token). `env/device.json` nằm ngoài git.
- Dữ liệu thử ghi vào DB dùng chung phải có tiền tố `TEST-`.
- Hợp đồng API nằm ở `Backend-Agrisage/docs/reference/api-flows/` (đọc `FE_GUIDE_FLOW_2.md` và `FE_GUIDE_FLOW_4.md`).

## Màu sắc (bám sát Farmer-Web)
- Primary `#2E7D32`, nền `#F5FBF4`, chữ `#172118`.
