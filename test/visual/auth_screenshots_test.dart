// Chụp ảnh các màn hình auth bằng font thật để kiểm tra giao diện bằng mắt.
// Mặc định bị bỏ qua (cần mạng để tải font Google).
//
//   SCREENSHOTS=1 flutter test --update-goldens test/visual/auth_screenshots_test.dart
//
// ignore_for_file: depend_on_referenced_packages
//
// Ảnh ra ở test/visual/shots/. Test cũng thất bại nếu có lỗi tràn layout (overflow)
// với font thật ở cả khung 390px và 320px.
import 'dart:async';
import 'dart:io';

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../helpers/app_harness.dart';
import 'package:farmer_mobile/data/models/address.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:farmer_mobile/features/profile/providers/profile_providers.dart';
import 'package:farmer_mobile/features/products/data/catalog_models.dart';
import 'package:farmer_mobile/features/products/providers/catalog_providers.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/catalog_fakes.dart';
import '../helpers/profile_fakes.dart';
import '../helpers/order_fakes.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';

final _on = Platform.environment['SCREENSHOTS'] == '1';

Future<void> shoot(WidgetTester tester, String name) async {
  // Chờ hết hiệu ứng (chữ lỗi của ô nhập mờ dần ~170ms).
  await tester.pump(const Duration(milliseconds: 400));
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.createTempSync('gf').path;
}

/// Nạp font icon Material từ SDK (flutter test không tự nạp).
Future<void> _loadMaterialIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final file = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!file.existsSync()) return;
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  await loader.load();
}

bool _fontsReady = false;

/// Tải font thật TRƯỚC khi dựng giao diện, ngoài vùng fake-async (nếu để widget
/// tự kích hoạt thì việc tải nằm trong vùng fake và không bao giờ hoàn tất).
Future<void> useRealFonts(WidgetTester tester) async {
  if (_fontsReady) return;
  HttpOverrides.global = null; // cho phép tải font thật
  PathProviderPlatform.instance = _FakePathProvider();
  await _loadMaterialIcons();
  GoogleFonts.config.allowRuntimeFetching = true;
  await tester.runAsync(() async {
    final done = Completer<void>();
    // google_fonts cố lưu cache font qua path_provider (không có trong test);
    // lỗi đó vô hại nên bỏ qua, font vẫn nằm trong bộ nhớ.
    runZonedGuarded(() async {
      for (final w in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
        FontWeight.w800,
      ]) {
        GoogleFonts.inter(fontWeight: w);
        GoogleFonts.beVietnamPro(fontWeight: w);
      }
      await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 90));
      done.complete();
    }, (e, s) {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
  });
  _fontsReady = true;
}

void main() {
  for (final width in [390.0, 320.0]) {
    final tag = width.toInt();

    Future<AppHarness> open(WidgetTester tester, String route,
        {bool signedIn = false}) async {
      await useRealFonts(tester);
      final h = AppHarness();
      if (signedIn) h.signIn();
      await h.pump(tester, initial: route);
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpAndSettle();
      return h;
    }

    group('ảnh $tag px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      testWidgets('welcome', (tester) async {
        await open(tester, '/welcome');
        await shoot(tester, '${tag}_welcome');
      });

      testWidgets('login: trống → lỗi validate → lỗi server', (tester) async {
        final h = await open(tester, '/login');
        h.repo.onLogin = (_, __) async => throw const ApiException(
            kind: ApiErrorKind.unauthorized,
            statusCode: 401,
            message: 'Số điện thoại/email hoặc mật khẩu không đúng.');
        await shoot(tester, '${tag}_login_1_empty');

        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
        await tester.pump();
        await shoot(tester, '${tag}_login_2_validation');

        await enter(tester, 'login_identifier', '0912345678');
        await enter(tester, 'login_password', 'saimatkhau');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_login_3_server_error');
      });

      testWidgets('register: lỗi validate và lỗi trùng tài khoản',
          (tester) async {
        final h = await open(tester, '/register');
        h.repo.onRegister = () async => throw const ApiException(
            kind: ApiErrorKind.conflict,
            statusCode: 409,
            message: 'Số điện thoại hoặc email này đã được đăng ký.');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
        await tester.pump();
        await shoot(tester, '${tag}_register_1_validation');

        await enter(tester, 'register_name', 'Nguyễn Văn A');
        await enter(tester, 'register_phone', '0912345678');
        await enter(tester, 'register_password', 'matkhau123');
        await enter(tester, 'register_confirm', 'matkhau123');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng ký'));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_register_2_conflict');
      });

      testWidgets('quên mật khẩu: form, 503, đã gửi', (tester) async {
        final h = await open(tester, '/forgot-password');
        var fail = true;
        h.repo.onForgot = () async {
          if (fail) {
            throw const ApiException(
                kind: ApiErrorKind.unavailable,
                statusCode: 503,
                message:
                    'Hiện chưa gửi được mã xác nhận. Vui lòng thử lại sau.');
          }
        };
        await shoot(tester, '${tag}_forgot_1_form');

        await enter(tester, 'forgot_identifier', 'nongdan@example.com');
        await tester
            .tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_forgot_2_unavailable');

        fail = false;
        await tester
            .tap(find.widgetWithText(ElevatedButton, 'Gửi mã xác nhận'));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_forgot_3_sent');
      });

      testWidgets('đặt lại mật khẩu', (tester) async {
        await open(tester, '/reset-password');
        await shoot(tester, '${tag}_reset_1_form');
        await tester
            .tap(find.widgetWithText(ElevatedButton, 'Đặt lại mật khẩu'));
        await tester.pump();
        await shoot(tester, '${tag}_reset_2_validation');
      });

      testWidgets('xác minh SĐT', (tester) async {
        await open(tester, '/otp-verify?channel=phone&to=0912345678',
            signedIn: true);
        await tester.pump();
        await shoot(tester, '${tag}_otp_1_sent');
        await tester.pump(const Duration(seconds: 4));
      });

      testWidgets('đổi mật khẩu: lỗi', (tester) async {
        final h = await open(tester, '/profile/password', signedIn: true);
        h.repo.onChangePassword = () async => throw const ApiException(
            kind: ApiErrorKind.unauthorized,
            statusCode: 401,
            message: 'Mật khẩu hiện tại không đúng.');
        await shoot(tester, '${tag}_changepw_1_form');
        await enter(tester, 'cp_current', 'saimatkhau');
        await enter(tester, 'cp_new', 'matkhaumoi1');
        await enter(tester, 'cp_confirm', 'matkhaumoi1');
        final b = find.widgetWithText(ElevatedButton, 'Cập nhật mật khẩu');
        await tester.ensureVisible(b);
        await tester.tap(b);
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_changepw_2_error');
      });

      testWidgets('hồ sơ: tên thật + mục xác minh + hộp thoại đăng xuất',
          (tester) async {
        final h = await open(tester, '/profile', signedIn: true);
        h.signIn(
            user: SessionUser.fromJson(
                meJson(email: 'tran.van.hai@example.com')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_profile_1');

        await tapText(tester, 'Đăng xuất');
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_profile_2_logout_dialog');
      });

      testWidgets('sửa hồ sơ', (tester) async {
        final h = await open(tester, '/profile/edit', signedIn: true);
        h.profile.profile =
            FarmerProfile.fromJson(profileJson(email: 'tran.van.hai@example.com'));
        h.container.invalidate(profileProvider);
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_editprofile_1');
      });

      testWidgets('sổ địa chỉ: rỗng, có dữ liệu, đủ 10, hộp thoại xoá',
          (tester) async {
        final h = await open(tester, '/profile/addresses', signedIn: true);
        await shoot(tester, '${tag}_addresses_1_empty');

        h.profile.addresses = [
          makeAddress('a',
              isDefault: true,
              name: 'Trần Văn Hải',
              line: 'Ấp Thới Phước, số nhà 123 đường liên xã',
              type: AddressType.farm),
          makeAddress('b', name: 'Nguyễn Thị Lan Hương (người nhận rất dài tên)'),
        ];
        await h.container.read(addressesProvider.notifier).refresh();
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_addresses_2_list');

        await tester.tap(field('address_delete_a'));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_addresses_3_delete_default');
        await tester.tap(find.text('Huỷ'));
        await tester.pumpAndSettle();

        h.profile.addresses = [
          for (var i = 0; i < 10; i++) makeAddress('x$i', isDefault: i == 0)
        ];
        await h.container.read(addressesProvider.notifier).refresh();
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_addresses_4_full');
      });

      testWidgets('form địa chỉ: trống → lỗi; sửa địa chỉ mặc định', (tester) async {
        final h = await open(tester, '/profile/addresses/add', signedIn: true);
        final b = find.widgetWithText(ElevatedButton, 'Lưu địa chỉ');
        await tester.tap(b);
        await tester.pump();
        await shoot(tester, '${tag}_addressform_1_validation');

        h.profile.addresses = [
          makeAddress('a', isDefault: true, name: 'Trần Văn Hải', line: 'Ấp 3')
        ];
        h.router.go('/profile/addresses/edit/a');
        await tester.pumpAndSettle();
        await tester.drag(find.byType(SingleChildScrollView).last,
            const Offset(0, -600));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_addressform_2_edit_default');
      });

      testWidgets('danh sách sản phẩm', (tester) async {
        final h = AppHarness()..signIn();
        h.catalog.all = [
          product('a', name: 'Lúa giống ST25 (bao 25 kg)', categoryName: 'Giống cây trồng', fromPrice: 32000),
          product('b', name: 'Phân hữu cơ vi sinh (bao 20 kg) - chưa có giá', fromPrice: null),
          product('c', name: 'Thuốc trừ bệnh đạo ôn Filia 525SE (chai 100 ml) loại đặc biệt', categoryName: 'Thuốc bảo vệ thực vật', fromPrice: 165000),
          product('d', name: 'Phân Ure (bao 50 kg)', fromPrice: 1150000),
        ];
        h.cart.cart = cartOf([line('x'), line('y', packagingId: 'k')]);
        await useRealFonts(tester);
        await h.pump(tester, initial: '/products');
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_products_1_list');

        h.catalog.all = [];
        await tester.enterText(find.byKey(const Key('product_search')), 'khong co');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_products_2_empty');
      });

      testWidgets('chi tiết sản phẩm', (tester) async {
        final h = AppHarness()..signIn();
        h.catalog.details['p1'] = ProductDetail.fromJson(detailJson(
          name: 'Thuốc trừ bệnh đạo ôn Filia 525SE (chai 100 ml)',
          brand: 'Syngenta',
          ingredients: [
            {'name': 'Propiconazole', 'concentration': '125 g/L'},
            {'name': 'Tricyclazole', 'concentration': '400 g/L'},
          ],
          usage: 'Pha 15-20 ml/bình 16 lít, phun khi bệnh chớm xuất hiện. Phun ướt đều hai mặt lá.',
        ));
        await useRealFonts(tester);
        await h.pump(tester, initial: '/products/p1');
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pack_bao')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_detail_1_top');

        await tester.tap(find.byKey(const Key('add_to_cart')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_detail_2_added');

        await tester.drag(find.byType(ListView).first, const Offset(0, -700));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_detail_3_bottom');
      });

      testWidgets('giỏ hàng: có dòng ngừng bán; giỏ trống', (tester) async {
        final h = AppHarness()..signIn();
        h.cart.cart = cartOf([
          line('a', name: 'Lúa giống ST25 (bao 25 kg)', quantity: 2),
          line('b', name: 'Phân Kali Clorua (bao 50 kg) loại hạt to nhập khẩu', packaging: 'Bao 50 kg', unitPrice: 800000, packagingId: 'k', quantity: 120),
          line('c', name: 'Phân hữu cơ vi sinh', packaging: 'Bao 20 kg', packagingId: 'h', available: false, reason: 'NO_PRICE'),
        ]);
        await useRealFonts(tester);
        await h.pump(tester, initial: '/cart');
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_cart_1_lines');

        h.cart.cart = Cart.empty;
        await h.container.read(cartProvider.notifier).refresh();
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_cart_2_empty');
      });

      Future<AppHarness> openAt(WidgetTester tester, String route,
          void Function(AppHarness) setup,
          {bool settle = true}) async {
        final h = AppHarness()..signIn();
        setup(h);
        await useRealFonts(tester);
        await h.pump(tester, initial: route);
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump();
          await tester.pump();
        }
        return h;
      }

      testWidgets('đặt hàng', (tester) async {
        final h = await openAt(tester, '/order-confirm', (h) {
          h.cart.cart = cartOf([
            line('a', name: 'Lúa giống ST25 (bao 25 kg)', quantity: 2),
            line('b', name: 'Phân Kali Clorua loại hạt to nhập khẩu', packaging: 'Bao 50 kg', unitPrice: 800000, packagingId: 'k', quantity: 120),
          ]);
          h.profile.addresses = [
            makeAddress('home', isDefault: true, name: 'Trần Văn Hải', line: 'Ấp Thới Phước, số nhà 123 đường liên xã'),
          ];
          h.credit.credit = creditOf(available: 1000000);
        });
        await shoot(tester, '${tag}_checkout_1_top');
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_checkout_2_bottom');
        expect(h.orders.calls, isEmpty);
      });

      testWidgets('danh sách đơn', (tester) async {
        await openAt(tester, '/orders', (h) {
          h.orders.list0 = [
            summaryOf('20261012-0001', status: 'PENDING_CONFIRMATION', total: 97560000),
            summaryOf('20261011-0007', status: 'PARTIALLY_FULFILLED', total: 450000, settlement: 'CREDIT'),
            summaryOf('20261009-0003', status: 'COMPLETED', total: 780000, fulfillment: 'PICKUP'),
            summaryOf('20261001-0001', status: 'CANCELLED', total: 32000),
          ];
        });
        await shoot(tester, '${tag}_orders_1_list');
      });

      testWidgets('chi tiết đơn: chờ thanh toán; đang giao', (tester) async {
        final h = await openAt(tester, '/orders/o1', (h) {
          seedOrder(h, orderOf(id: 'o1', note: 'Giao buổi sáng, gọi trước 15 phút'));
        });
        await shoot(tester, '${tag}_orderdetail_1_unpaid');

        seedOrder(h, orderOf(id: 'o2', status: 'PARTIALLY_FULFILLED'),
            payments: paymentsOf(paid: 1560000, items: [paymentItem('p1')]),
            deliveries: [
              deliveryOf('d1', status: 'RETRY_PENDING', attempts: [
                DeliveryAttempt(
                    number: 1,
                    status: 'FAILED',
                    startedAt: DateTime.utc(2026, 10, 12, 5, 10),
                    failureReasonCode: 'CUSTOMER_ABSENT'),
              ]),
            ]);
        h.router.go('/orders/o2');
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_orderdetail_2_top');
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_orderdetail_3_delivery');
      });

      testWidgets('thanh toán QR; hết hạn; kết quả', (tester) async {
        final h = await openAt(tester, '/payment/qr?orderId=o1', (h) {
          seedOrder(h, orderOf(id: 'o1'));
        }, settle: false);
        await shoot(tester, '${tag}_pay_1_waiting');

        h.payments.statuses.add('FAILED');
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        await shoot(tester, '${tag}_pay_2_expired');

        h.router.go('/payment/result?success=true&orderId=o1');
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_pay_3_success');
      });
    });
  }
}

void seedOrder(AppHarness h, OrderDetail o,
    {OrderPayments? payments, List<Delivery> deliveries = const []}) {
  h.orders.orders[o.id] = o;
  h.orders.paymentsByOrder[o.id] = payments ?? paymentsOf(total: o.totalAmount);
  h.orders.deliveriesByOrder[o.id] = deliveries;
}
