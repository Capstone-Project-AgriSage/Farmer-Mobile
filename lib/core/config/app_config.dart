import 'package:flutter/foundation.dart';

/// Cấu hình môi trường. Ghi đè bằng:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5206`
/// (máy thật cần IP LAN của máy chạy backend, cùng mạng Wi-Fi).
abstract class AppConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const int _port = 5206;

  /// Bản release PHẢI truyền `API_BASE_URL` (địa chỉ HTTPS của máy chủ): địa chỉ
  /// mặc định bên dưới chỉ dành cho máy dev nên bản release không có nó thì
  /// không dùng được. `main()` chặn khởi động và báo rõ thay vì gọi nhầm máy chủ.
  static bool get isConfigured => _override.isNotEmpty || !kReleaseMode;

  /// Android emulator thấy máy host qua 10.0.2.2, không phải localhost.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_port';
    }
    return 'http://localhost:$_port';
  }

  /// Nguồn gửi lên khi đặt hàng (`CheckoutRequest.source`).
  static const String orderSource = 'FARMER_MOBILE';

  /// Hai trang payOS đưa người mua quay lại (thanh toán xong / bấm huỷ). So khớp CHỈ
  /// theo đường dẫn nên đổi máy chủ web vẫn chạy. Ghi đè bằng `--dart-define`.
  static const String payosReturnPath = String.fromEnvironment(
    'PAYOS_RETURN_PATH',
    defaultValue: '/payments/payos/return',
  );
  static const String payosCancelPath = String.fromEnvironment(
    'PAYOS_CANCEL_PATH',
    defaultValue: '/payments/payos/cancel',
  );

  /// Hiện mục "Công cụ phát triển" ở màn Tài khoản (chỉ build thử, xem `env/*.json`).
  static const bool showDevTools = bool.fromEnvironment('SHOW_DEV_TOOLS');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Upload ảnh (AI Doctor) có thể chậm hơn, kèm bước gọi AI phía server.
  static const Duration uploadTimeout = Duration(seconds: 90);
}
