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
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:farmer_mobile/features/auth/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class _FilePicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final f = File('${Directory.systemTemp.path}/e2e_leaf.png')
      ..writeAsBytesSync(base64Decode(_png));
    return PickedPhoto(path: f.path, name: 'e2e_leaf.png', sizeBytes: f.lengthSync());
  }

  @override
  Future<PickedPhoto?> recoverLost() async => null;
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
    // Danh sách dựng lười: mục ở dưới màn hình chưa có trong cây widget → cuộn tới khi thấy.
    if (scroll && f.evaluate().isEmpty) {
      try {
        await t.scrollUntilVisible(f, 300,
            scrollable: find.byType(Scrollable).first, maxScrolls: 20);
      } catch (_) {}
    }
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
    // Ô đã có chữ cũ chỉ nhận chữ mới khi đã được chạm (lấy focus) trước.
    await t.tap(find.byKey(k));
    await t.pump(const Duration(milliseconds: 150));
    await t.enterText(find.byKey(k), text);
    await settle(t, 200);
  }

  Future<void> back(WidgetTester t) async {
    // Emulator chậm: chờ nút Back của AppBar sẵn sàng (vd. đang chờ server trả lời).
    final backButton = find.byType(BackButton);
    for (var i = 0; i < 60 && backButton.evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
    // Không dùng t.pageBack(): nó tìm nút theo tooltip tiếng Anh "Back", app dùng tiếng Việt ("Quay lại").
    await t.tap(backButton.last);
    await settle(t, 800);
  }

  /// Quay lại cho tới khi thấy thanh tab (tối đa 4 lần).
  Future<void> backToTabs(WidgetTester t) async {
    for (var i = 0; i < 4 && find.text('Tài khoản').evaluate().isEmpty; i++) {
      await back(t);
    }
  }

  Future<void> launch(WidgetTester t, {Object? key}) async {
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(ProviderScope(
      key: ValueKey(key ?? 'app'),
      overrides: [
        photoPickerProvider.overrideWithValue(_FilePicker()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
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

  testWidgets(
      'hồ sơ, địa chỉ, tìm kiếm, đổi mật khẩu: sửa tên → thêm/sửa/đặt mặc định/xoá địa chỉ → tìm sản phẩm → đổi mật khẩu → đăng nhập mật khẩu mới',
      (tester) async {
    final rnd = Random.secure();
    final phone = '09${List.generate(8, (_) => rnd.nextInt(10)).join()}';
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final name = 'TEST Mobile E2E2 $suffix';
    const password = 'Test@12345678';
    const newPassword = 'Test@87654321';

    await const FlutterSecureStorage().deleteAll();
    await binding.convertFlutterSurfaceToImage();
    await launch(tester, key: 'second');

    // ── Đăng ký nhanh ─────────────────────────────────────────────
    await pumpUntil(tester, find.text('Bỏ qua'), what: 'onboarding');
    await tap(tester, find.text('Bỏ qua'));
    await pumpUntil(tester, find.text('Tạo tài khoản mới'));
    await tap(tester, find.text('Tạo tài khoản mới'));
    await pumpUntil(tester, find.byKey(const Key('register_name')));
    await type(tester, const Key('register_name'), name);
    await type(tester, const Key('register_phone'), phone);
    await type(tester, const Key('register_password'), password);
    await type(tester, const Key('register_confirm'), password);
    await tap(tester, find.byType(AuthSubmitButton));
    await pumpUntil(tester, find.byKey(const Key('home_greeting')),
        what: 'Trang chủ sau đăng ký');

    // ── Tìm kiếm sản phẩm ─────────────────────────────────────────
    await tap(tester, find.text('Sản phẩm'));
    await pumpUntil(tester, find.byKey(const Key('product_count')), what: 'danh sách sản phẩm');
    final all = tester.widget<Text>(find.byKey(const Key('product_count'))).data;
    await tester.enterText(find.byKey(const Key('product_search')), 'zzzkhongco999');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntil(tester, find.textContaining('Không tìm thấy sản phẩm'),
        what: 'kết quả tìm kiếm rỗng');
    await shot(tester, '30_search_empty');
    await tap(tester, find.text('Xoá tìm kiếm'));
    await pumpUntil(tester, find.byKey(const Key('product_count')),
        what: 'danh sách sau khi xoá tìm kiếm');
    await settle(tester, 1500);
    expect(tester.widget<Text>(find.byKey(const Key('product_count'))).data, all,
        reason: 'xoá từ khoá phải trả lại đủ danh sách');

    // ── Sửa hồ sơ ─────────────────────────────────────────────────
    await tap(tester, find.text('Tài khoản').last);
    await pumpUntil(tester, find.text('Thông tin cá nhân'));
    await tap(tester, find.text('Thông tin cá nhân'));
    await pumpUntil(tester, find.byKey(const Key('profile_name')));
    final renamed = '$name sửa';
    await tap(tester, find.byKey(const Key('profile_name')));
    await tester.enterText(find.byKey(const Key('profile_name')), renamed);
    await settle(tester, 300);
    expect(
        tester.widget<TextFormField>(find.byKey(const Key('profile_name'))).controller?.text,
        renamed,
        reason: 'ô tên phải nhận chữ vừa nhập');
    await shot(tester, '31_profile_edit');
    await tap(tester, find.text('Lưu thay đổi'));
    await pumpUntil(tester, find.textContaining('Đã cập nhật thông tin cá nhân'),
        what: 'báo lưu hồ sơ');
    await backToTabs(tester);
    await tap(tester, find.text('Tài khoản').last);
    await pumpUntil(tester, find.text(renamed), what: 'tên mới ở trang Tài khoản');

    // ── Sổ địa chỉ: thêm → sửa → thêm thứ hai đặt mặc định → xoá ──
    Future<void> fillAddress(String recipient, String line) async {
      await type(tester, const Key('addr_name'), recipient);
      await type(tester, const Key('addr_phone'), phone);
      await type(tester, const Key('addr_province'), 'Cần Thơ');
      await type(tester, const Key('addr_line'), line);
    }

    bool keyStarts(Widget w, String prefix) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith(prefix);
    }

    await tap(tester, find.text('Quản lý địa chỉ'));
    // Chưa có địa chỉ: chỉ có nút "Thêm địa chỉ" ở giữa (nút dưới chỉ hiện khi đã có địa chỉ).
    await pumpUntil(tester, find.text('Thêm địa chỉ'), what: 'sổ địa chỉ trống');
    await shot(tester, '32_addresses_empty');
    await tap(tester, find.text('Thêm địa chỉ'));
    await pumpUntil(tester, find.byKey(const Key('addr_name')));
    await fillAddress('Người nhận A', 'Số 1 đường A');
    await tap(tester, find.text('Lưu địa chỉ'));
    await pumpUntil(tester, find.byKey(const Key('address_add')), what: 'quay về danh sách sau khi thêm A');
    expect(find.text('Người nhận A'), findsOneWidget);
    await shot(tester, '33_address_added');

    await tap(tester, find.byWidgetPredicate((w) => keyStarts(w, 'address_edit_')));
    await pumpUntil(tester, find.byKey(const Key('addr_line')));
    await type(tester, const Key('addr_line'), 'Số 2 đường A (đã sửa)');
    await tap(tester, find.text('Lưu địa chỉ'));
    await pumpUntil(tester, find.byKey(const Key('address_add')), what: 'quay về danh sách sau khi sửa A');
    expect(find.textContaining('đã sửa'), findsOneWidget);

    await tap(tester, find.byKey(const Key('address_add')));
    await pumpUntil(tester, find.byKey(const Key('addr_name')));
    await fillAddress('Người nhận B', 'Số 3 đường B');
    await tap(tester, find.byKey(const Key('addr_default')));
    await tap(tester, find.text('Lưu địa chỉ'));
    await pumpUntil(tester, find.byKey(const Key('address_add')), what: 'quay về danh sách sau khi thêm B');
    expect(find.text('Người nhận B'), findsOneWidget);
    await shot(tester, '34_address_two');

    // Xoá một địa chỉ (nút Xoá cuối cùng thuộc địa chỉ không mặc định).
    final deletes = find.byWidgetPredicate((w) => keyStarts(w, 'address_delete_'));
    expect(deletes, findsWidgets);
    await tap(tester, deletes.last);
    await pumpUntil(tester, find.byKey(const Key('address_delete_confirm')));
    await tap(tester, find.byKey(const Key('address_delete_confirm')));
    await settle(tester, 1500);
    await shot(tester, '35_address_deleted');
    await backToTabs(tester);

    // ── Đổi mật khẩu → bị đăng xuất → đăng nhập bằng mật khẩu mới ──
    await tap(tester, find.text('Tài khoản').last);
    await pumpUntil(tester, find.text('Đổi mật khẩu'));
    await tap(tester, find.text('Đổi mật khẩu'));
    await pumpUntil(tester, find.byKey(const Key('cp_current')));
    await type(tester, const Key('cp_current'), password);
    await type(tester, const Key('cp_new'), newPassword);
    await type(tester, const Key('cp_confirm'), newPassword);
    await tap(tester, find.text('Cập nhật mật khẩu'));
    await pumpUntil(tester, find.text('Đăng nhập'), what: 'về màn Chào mừng sau đổi mật khẩu');
    await shot(tester, '36_after_password_change');
    await tap(tester, find.text('Đăng nhập').first);
    await pumpUntil(tester, find.byKey(const Key('login_identifier')));
    await type(tester, const Key('login_identifier'), phone);
    await type(tester, const Key('login_password'), password);
    await tap(tester, find.byType(AuthSubmitButton));
    await pumpUntil(tester, find.textContaining('không đúng'), what: 'từ chối mật khẩu cũ');
    await type(tester, const Key('login_password'), newPassword);
    await tap(tester, find.byType(AuthSubmitButton));
    await pumpUntil(tester, find.byKey(const Key('home_greeting')),
        what: 'đăng nhập bằng mật khẩu mới');
    await shot(tester, '37_login_new_password');
  });
}
