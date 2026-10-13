// Kiểm thử đầu-cuối TRÊN THIẾT BỊ/EMULATOR THẬT, gọi backend THẬT.
//
// Chạy (backend phải đang chạy; emulator thấy máy host qua 10.0.2.2:5206):
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_flow_test.dart -d <device-id>
//
// Ảnh chụp màn hình nằm ở build/e2e_shots/. Test tạo 1 tài khoản "TEST Mobile E2E ..."
// + 1 đơn hàng (huỷ ngay) + 1 ca chẩn đoán (huỷ ngay) trên DB dev dùng chung. Máy ảnh/thư
// viện ảnh được thay bằng ảnh PNG 1x1 có sẵn để không cần thao tác tay.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:farmer_mobile/app.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';
import 'package:farmer_mobile/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class _FilePicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final f = File('${Directory.systemTemp.path}/e2e_leaf.png')
      ..writeAsBytesSync(base64Decode(_png));
    return PickedPhoto(path: f.path, name: 'e2e_leaf.png', sizeBytes: f.lengthSync());
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(WidgetTester t, Finder f,
      {Duration timeout = const Duration(seconds: 40), String? what}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 150));
      if (f.evaluate().isNotEmpty) return;
    }
    try { await binding.takeScreenshot('FAIL_${(what ?? 'x').replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}'); } catch (_) {}
    throw TestFailure('Không thấy ${what ?? f} sau ${timeout.inSeconds}s');
  }

  Future<void> settle(WidgetTester t, [int ms = 600]) => t.pump(Duration(milliseconds: ms));

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t, 500);
    await binding.takeScreenshot(name);
  }

  Future<void> tap(WidgetTester t, Finder f, {bool scroll = true}) async {
    if (scroll && f.evaluate().isNotEmpty) {
      try {
        await t.ensureVisible(f.first);
      } catch (_) {}
    }
    await t.tap(f.first);
    await settle(t);
  }

  Future<void> type(WidgetTester t, Key k, String text) async {
    await t.ensureVisible(find.byKey(k));
    await t.enterText(find.byKey(k), text);
    await settle(t, 200);
  }

  Future<void> back(WidgetTester t) async {
    await t.pageBack();
    await settle(t, 800);
  }

  /// Quay lại cho tới khi thấy thanh tab (tối đa 4 lần).
  Future<void> backToTabs(WidgetTester t) async {
    for (var i = 0; i < 4 && find.text('Tài khoản').evaluate().isEmpty; i++) {
      await back(t);
    }
  }

  Future<void> launch(WidgetTester t, {Object? key}) async {
    await t.pumpWidget(ProviderScope(
      key: ValueKey(key ?? 'app'),
      overrides: [photoPickerProvider.overrideWithValue(_FilePicker())],
      child: const AgriSageApp(),
    ));
  }

  testWidgets(
      'luồng chính: đăng ký → mua hàng → huỷ đơn → hồ sơ → chẩn đoán → đăng xuất/đăng nhập → khôi phục phiên',
      (tester) async {
    final rnd = Random.secure();
    final phone = '09${List.generate(8, (_) => rnd.nextInt(10)).join()}';
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final name = 'TEST Mobile E2E $suffix';
    const password = 'Test@12345678';

    await const FlutterSecureStorage().deleteAll();
    await binding.convertFlutterSurfaceToImage();
    await launch(tester);

    // ── Giới thiệu → Chào mừng → Đăng ký ──────────────────────────
    await pumpUntil(tester, find.text('Bỏ qua'), what: 'onboarding');
    await shot(tester, '01_onboarding');
    await tap(tester, find.text('Bỏ qua'));
    await pumpUntil(tester, find.text('Tạo tài khoản mới'));
    await shot(tester, '02_welcome');
    await tap(tester, find.text('Tạo tài khoản mới'));
    await pumpUntil(tester, find.byKey(const Key('register_name')));
    await type(tester, const Key('register_name'), name);
    await type(tester, const Key('register_phone'), phone);
    await type(tester, const Key('register_password'), password);
    await type(tester, const Key('register_confirm'), password);
    await shot(tester, '03_register_filled');
    await tap(tester, find.byType(AuthSubmitButton));

    // ── Trang chủ (dữ liệu thật của tài khoản mới) ────────────────
    await pumpUntil(tester, find.byKey(const Key('home_greeting')),
        what: 'Trang chủ sau đăng ký');
    await pumpUntil(tester, find.byKey(const Key('home_orders_none')), what: 'thẻ đơn hàng');
    expect(find.textContaining(suffix), findsWidgets);
    await shot(tester, '04_home_new_account');

    // ── Sản phẩm → chi tiết → thêm vào giỏ ────────────────────────
    await tap(tester, find.text('Sản phẩm'));
    await pumpUntil(tester, find.byKey(const Key('product_count')), what: 'danh sách sản phẩm');
    await shot(tester, '05_products');
    bool isProductCard(Widget w) {
      final k = w.key;
      if (k is! ValueKey<String>) return false;
      final v = k.value;
      return v.startsWith('product_') && v != 'product_count' && v != 'product_search';
    }

    final cards = find.byWidgetPredicate(isProductCard);
    await pumpUntil(tester, cards, what: 'thẻ sản phẩm');
    var added = false;
    final tries = min(cards.evaluate().length, 6);
    for (var i = 0; i < tries && !added; i++) {
      await tap(tester, cards.at(i));
      await pumpUntil(tester, find.byKey(const Key('add_to_cart')), what: 'chi tiết sản phẩm');
      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('add_to_cart')));
      if (btn.onPressed != null) {
        await shot(tester, '06_product_detail');
        await tap(tester, find.byKey(const Key('add_to_cart')));
        await settle(tester, 800);
        added = true;
      }
      await back(tester);
      await pumpUntil(tester, cards, what: 'danh sách sản phẩm sau khi quay lại');
    }
    expect(added, isTrue, reason: 'phải có ít nhất 1 sản phẩm đặt mua được');

    // ── Giỏ → xác nhận → đặt hàng nhận tại cửa hàng ───────────────
    await tap(tester, find.byKey(const Key('cart_button')));
    await pumpUntil(tester, find.byKey(const Key('cart_checkout')), what: 'giỏ hàng');
    await shot(tester, '07_cart');
    await tap(tester, find.byKey(const Key('cart_checkout')));
    await pumpUntil(tester, find.byKey(const Key('opt_pickup')), what: 'xác nhận đặt hàng');
    await tap(tester, find.byKey(const Key('opt_pickup')));
    await tap(tester, find.byKey(const Key('order_agree')));
    await shot(tester, '08_checkout');
    await tap(tester, find.byKey(const Key('checkout_submit')));
    await pumpUntil(tester, find.byKey(const Key('order_number')),
        what: 'chi tiết đơn vừa đặt');
    await shot(tester, '09_order_detail');

    // ── Huỷ đơn ───────────────────────────────────────────────────
    await tap(tester, find.byKey(const Key('order_cancel')));
    await pumpUntil(tester, find.byKey(const Key('cancel_confirm')));
    await shot(tester, '10_cancel_dialog');
    await tap(tester, find.byKey(const Key('cancel_confirm')));
    await pumpUntil(tester, find.text('Đã huỷ'), what: 'trạng thái Đã huỷ');
    await shot(tester, '11_order_cancelled');

    // ── Hồ sơ: thiết bị đăng nhập, trả hàng, trợ giúp ─────────────
    await backToTabs(tester);
    await tap(tester, find.text('Tài khoản').last);
    await pumpUntil(tester, find.text('Thiết bị đăng nhập'));
    await shot(tester, '12_profile');
    await tap(tester, find.text('Thiết bị đăng nhập'));
    await pumpUntil(tester, find.text('Thiết bị này'), what: 'phiên đăng nhập thật');
    await shot(tester, '13_sessions');
    await back(tester);
    await tap(tester, find.text('Yêu cầu trả hàng'));
    await pumpUntil(tester, find.textContaining('Bạn chưa có yêu cầu trả hàng nào'));
    await shot(tester, '14_returns_empty');
    await back(tester);
    await tap(tester, find.text('Trợ giúp & Hỗ trợ'));
    await pumpUntil(tester, find.byKey(const Key('help_contact')));
    await shot(tester, '15_help');
    await back(tester);

    // ── Công nợ (chưa có hạn mức) ─────────────────────────────────
    await tap(tester, find.text('Công nợ').last);
    await pumpUntil(tester, find.textContaining('chưa có hạn mức'),
        what: 'trạng thái chưa có hạn mức');
    await shot(tester, '16_debt_none');

    // ── Chẩn đoán: gửi ảnh thật lên backend ───────────────────────
    await tap(tester, find.text('Chẩn đoán AI').last);
    await pumpUntil(tester, find.text('Chụp ảnh ngay'));
    await shot(tester, '17_ai_home');
    await tap(tester, find.text('Chụp ảnh ngay'));
    await pumpUntil(tester, find.byKey(const Key('cap_gallery')));
    await tap(tester, find.byKey(const Key('cap_gallery')));
    await pumpUntil(tester, find.byKey(const Key('cap_send')), what: 'nút gửi ảnh');
    await shot(tester, '18_capture_ready');
    await tap(tester, find.byKey(const Key('cap_send')));
    await pumpUntil(tester, find.byKey(const Key('case_number')),
        timeout: const Duration(seconds: 90), what: 'chi tiết ca chẩn đoán sau khi gửi');
    await shot(tester, '19_case_waiting');
    await tap(tester, find.byKey(const Key('case_cancel')));
    await pumpUntil(tester, find.byKey(const Key('case_cancel_yes')));
    await tap(tester, find.byKey(const Key('case_cancel_yes')));
    await pumpUntil(tester, find.byKey(const Key('case_cancelled')), what: 'ca đã huỷ');
    await shot(tester, '20_case_cancelled');

    // ── Thông báo (có thể đã có thông báo huỷ đơn do tiến trình nền sinh ra) ──
    await back(tester);
    await tap(tester, find.text('Trang chủ').last);
    await pumpUntil(tester, find.byKey(const Key('home_greeting')));
    try {
      await pumpUntil(tester, find.byKey(const Key('bell_badge')),
          timeout: const Duration(seconds: 45), what: 'số chưa đọc ở chuông');
    } on TestFailure {
      // Worker thông báo có thể chưa chạy: không coi là lỗi của app.
    }
    await shot(tester, '21_home_after');
    await tap(tester, find.byKey(const Key('bell')));
    await pumpUntil(tester, find.text('Thông báo'));
    await shot(tester, '22_notifications');
    await back(tester);

    // ── Đăng xuất → đăng nhập lại ─────────────────────────────────
    await tap(tester, find.text('Tài khoản').last);
    await pumpUntil(tester, find.text('Đăng xuất'));
    await tap(tester, find.text('Đăng xuất').last);
    await pumpUntil(tester, find.byKey(const Key('logout_confirm')));
    await tap(tester, find.byKey(const Key('logout_confirm')));
    await pumpUntil(tester, find.text('Đăng nhập'), what: 'màn Chào mừng sau đăng xuất');
    await shot(tester, '23_logged_out');
    await tap(tester, find.text('Đăng nhập').first);
    await pumpUntil(tester, find.byKey(const Key('login_identifier')));
    await type(tester, const Key('login_identifier'), phone);
    await type(tester, const Key('login_password'), password);
    await tap(tester, find.byType(AuthSubmitButton));
    await pumpUntil(tester, find.byKey(const Key('home_greeting')),
        what: 'Trang chủ sau đăng nhập lại');
    await shot(tester, '24_logged_in_again');

    // ── Khởi động lại app: phiên phải được khôi phục từ keystore thật ──
    await launch(tester, key: 'restarted');
    await pumpUntil(tester, find.byKey(const Key('home_greeting')),
        timeout: const Duration(seconds: 30),
        what: 'Trang chủ sau khi khởi động lại (khôi phục phiên)');
    await shot(tester, '25_session_restored');
  });
}
