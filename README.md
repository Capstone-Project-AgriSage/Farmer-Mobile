# AgriSage — Farmer Mobile App

Flutter app cho nông dân trong hệ sinh thái AgriSage, kết nối backend ASP.NET
([Backend-Agrisage](https://github.com/Capstone-Project-AgriSage/Backend-Agrisage)).
App chỉ dành cho tài khoản role `FARMER`.

## Chức năng (đã nối API thật)
- **Tài khoản**: đăng ký, đăng nhập (ghi nhớ), quên/đặt lại mật khẩu, đổi mật khẩu, xác minh SĐT/email,
  hồ sơ, sổ địa chỉ, danh sách thiết bị đăng nhập và đăng xuất từng thiết bị/tất cả.
- **Mua hàng**: danh mục và tìm kiếm sản phẩm, giỏ hàng (giá do server tính), đặt hàng giao tận nơi hoặc nhận tại
  cửa hàng, trả ngay qua payOS hoặc mua ghi nợ theo hạn mức, danh sách/chi tiết đơn, theo dõi giao hàng, huỷ đơn.
- **Thanh toán payOS**: mở trang payOS trong WebView ngay trong app; link app ngân hàng (`intent://`, scheme riêng)
  chuyển cho hệ thống; trang trả về/huỷ được nhận ra theo đường dẫn và không bao giờ được tin: kết quả luôn hỏi server.
  Khoản thanh toán dở được lưu trước khi mở trang payOS nên app bị tắt (đang ở app ngân hàng) vẫn tìm lại được
  (banner ở Trang chủ). Đặt hàng bị timeout thì không cho đặt lại ngay mà nhắc kiểm tra mục Đơn hàng (tránh trùng đơn).
- **Công nợ**: hạn mức, tổng nợ, danh sách và chi tiết khoản nợ, khiếu nại, xem trước phân bổ và trả nợ qua payOS, lịch sử trả nợ.
- **Trả hàng**: chọn hàng đã nhận để yêu cầu trả, theo dõi tiến trình, hoàn tiền, huỷ yêu cầu.
- **Chẩn đoán bệnh lúa**: gửi ảnh lá lúa; chuyên gia của cửa hàng xem và kết luận (nông dân **không** thấy kết quả AI),
  kèm hướng dẫn điều trị và sản phẩm gợi ý.
- **Thông báo**: danh sách, số chưa đọc, đọc/xoá, mở đúng màn hình tương ứng.

Chưa có API ở backend nên app hiển thị "Sắp ra mắt" hoặc không có mục này: bài viết/tin tức, đánh giá sản phẩm,
cài đặt thông báo, thông báo đẩy (FCM), ảnh đại diện, đổi SĐT/email. Không có dữ liệu mẫu trong app.

## Tech stack
Flutter 3.47.4 (Dart 3.13) · Riverpod (không codegen) · GoRouter · Dio (interceptor Bearer + refresh token) ·
flutter_secure_storage · webview_flutter (trang payOS) · shared_preferences (thanh toán dở) · image_picker ·
cached_network_image · flutter_localizations (tiếng Việt).

## Cấu trúc
```
lib/
├── core/        # config, network (Dio, AuthInterceptor, ApiException, apiCall), auth (phiên), theme, utils
├── features/    # mỗi tính năng: data (model + repository) / providers / screens / widgets
│   ├── auth  home  products(catalog + giỏ + đơn)  orders  payment  debt  returns  ai_doctor  notifications  profile
├── router/      # GoRouter + guard đăng nhập
└── shared/      # widget dùng chung
test/            # unit + widget test, live test (backend thật), ảnh chụp font thật
integration_test/  # kiểm thử đầu-cuối trên emulator/thiết bị thật
```

## Chạy app
Cần backend chạy (mặc định `http://localhost:5206`).
```bash
flutter pub get
flutter run                                   # Android emulator tự dùng http://10.0.2.2:5206
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5206   # máy thật: IP LAN của máy chạy backend
```
Hoặc dùng file cấu hình: `flutter run --dart-define-from-file=env/emulator.json` (điện thoại thật: chép
`env/device.example.json` thành `env/device.json`, chạy `adb reverse tcp:5206 tcp:5206`). Hai file này bật
`SHOW_DEV_TOOLS`: màn Tài khoản có mục "Công cụ phát triển" để thử WebView payOS với trang giả
(`node`/`python -m http.server 8099` trong `tool/payos_webview_test/`).

Bản **release bắt buộc** build với `--dart-define=API_BASE_URL=https://<máy-chủ>` (không có thì app báo chưa cấu hình
thay vì gọi nhầm địa chỉ dev). Bản debug được phép dùng HTTP; bản release chỉ HTTPS.

## Kiểm thử
```bash
flutter analyze
flutter test                                  # unit + widget (live/ảnh chụp tự bỏ qua)

# Test với backend THẬT (tạo tài khoản "TEST Mobile ..." trên DB dev dùng chung)
LIVE_API=1 flutter test test/live/auth_live_test.dart      # tương tự profile/catalog/orders/debt/returns/diagnosis/notifications

# Ảnh chụp màn hình bằng font thật (cần mạng) ở 390px và 320px, ra test/visual/shots/
SCREENSHOTS=1 FLUTTER_ROOT=/path/to/flutter flutter test --update-goldens test/visual/

# Đầu-cuối trên emulator/thiết bị thật, ảnh ra build/e2e_shots/
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_flow_test.dart -d <device-id>
```
Backend giới hạn đăng nhập/đăng ký 10 yêu cầu/phút/IP nên các live test tự điều tốc.
CI (`.github/workflows/flutter-ci.yml`) chạy `flutter analyze` và `flutter test` cho mỗi PR và mỗi lần push lên `main`.
WebView không chạy trong `flutter test` (test dùng màn giả); kiểm tra WebView thật bằng mục "Công cụ phát triển".

## Màu sắc (bám sát Farmer-Web)
Primary `#2E7D32` · Background `#F5FBF4` · Text `#172118`
