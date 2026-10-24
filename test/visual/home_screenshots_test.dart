// Chụp ảnh Trang chủ (dữ liệu thật), Hồ sơ, Thiết bị đăng nhập, Trợ giúp, Sắp ra mắt
// và Không tìm thấy trang bằng font thật (cần mạng để tải font Google).
//
//   SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/home_screenshots_test.dart
//
// Ảnh ra ở test/visual/shots/ (xem xong thì xoá thư mục). Test cũng thất bại nếu
// có lỗi tràn layout với font thật ở cả khung 390px và 320px.
import 'dart:io';

import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';
import 'package:farmer_mobile/shared/widgets/not_found_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/app_harness.dart';
import '../helpers/debt_fakes.dart';
import '../helpers/diagnosis_fakes.dart';
import '../helpers/notification_fakes.dart';
import '../helpers/order_fakes.dart';
import 'auth_screenshots_test.dart' show shoot, useRealFonts;

final _on = Platform.environment['SCREENSHOTS'] == '1';

void main() {
  for (final width in [390.0, 320.0]) {
    final tag = width.toInt();

    Future<AppHarness> open(WidgetTester tester, String route,
        {void Function(AppHarness)? setup}) async {
      await useRealFonts(tester);
      final h = AppHarness()..signIn();
      h.realHome = true;
      setup?.call(h);
      await h.pump(tester, initial: route);
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpAndSettle();
      return h;
    }

    void seedFull(AppHarness h) {
      h.orders.list0 = [
        summaryOf('new', status: 'PENDING_CONFIRMATION', total: 1560000),
        summaryOf('c1', status: 'CONFIRMED'),
        summaryOf('c2', status: 'PREPARING'),
        for (var i = 1; i <= 12; i++) summaryOf('d$i', status: 'COMPLETED'),
        summaryOf('x1', status: 'CANCELLED'),
      ];
      h.diagnosis.list0 = [
        diagSummaryOf('v',
            status: 'AI_COMPLETED', code: 'LEAF_BLAST', name: 'Leaf Blast', certainty: 'CONFIDENT'),
      ];
      h.diagnosis.cases['v'] = caseOf('v',
          status: 'AI_COMPLETED',
          withImage: false,
          result: aiResultJson(products: [
            {'storeProductId': 'sp1', 'productId': 'p1', 'name': 'Thuốc đặc trị đạo ôn Fuji-One 40WP', 'sku': 'F1', 'rankOrder': 1},
            {'storeProductId': 'sp2', 'productId': 'p2', 'name': 'Phân NPK 20-20-15', 'sku': 'N1', 'rankOrder': 2},
          ]));
      h.debt.account0 = accountOf(balance: 4100000, overdue: 2350000);
      h.credit.credit = creditOf();
      h.notifications.items = [notifOf('a'), notifOf('b'), notifOf('c')];
    }

    group('ảnh trang chủ & hồ sơ $tag px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      testWidgets('trang chủ: đầy đủ dữ liệu (cuộn 2 đoạn)', (tester) async {
        await open(tester, '/home', setup: seedFull);
        await shoot(tester, '${tag}_home_full_top');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_home_full_bottom');
      });

      testWidgets('trang chủ: tài khoản mới (chưa có gì)', (tester) async {
        await open(tester, '/home');
        await shoot(tester, '${tag}_home_empty');
      });

      testWidgets('trang chủ: AI chưa chắc, chưa nợ', (tester) async {
        await open(tester, '/home', setup: (h) {
          h.orders.list0 = [summaryOf('a', status: 'CONFIRMED')];
          h.diagnosis.list0 = [
            diagSummaryOf('u',
                status: 'AI_COMPLETED',
                code: 'BACTERIAL_LEAF_BLIGHT',
                name: 'Bacterial Leaf Blight',
                certainty: 'UNCERTAIN'),
          ];
        });
        await shoot(tester, '${tag}_home_uncertain');
      });

      testWidgets('trang chủ: AI đang phân tích', (tester) async {
        await open(tester, '/home', setup: (h) {
          h.diagnosis.list0 = [diagSummaryOf('w')];
        });
        await shoot(tester, '${tag}_home_waiting');
      });

      testWidgets('trang chủ: lỗi mạng ở các thẻ', (tester) async {
        await open(tester, '/home', setup: (h) {
          const net = ApiException(kind: ApiErrorKind.network, message: 'x');
          h.orders.listError = net;
          h.diagnosis.listError = net;
        });
        await shoot(tester, '${tag}_home_errors');
      });

      testWidgets('hồ sơ', (tester) async {
        await open(tester, '/profile');
        await shoot(tester, '${tag}_profile_top');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_profile_bottom');
      });

      testWidgets('thiết bị đăng nhập', (tester) async {
        final now = DateTime.now();
        await open(tester, '/profile/sessions', setup: (h) {
          h.repo.sessions0 = [
            AuthSession(id: 'a', createdAt: now.subtract(const Duration(days: 1)), lastUsedAt: now.subtract(const Duration(minutes: 2)), expiresAt: now.add(const Duration(days: 29)), isCurrent: true),
            AuthSession(id: 'b', createdAt: now.subtract(const Duration(days: 9)), lastUsedAt: now.subtract(const Duration(days: 3)), expiresAt: now.add(const Duration(days: 21)), isCurrent: false),
          ];
        });
        await shoot(tester, '${tag}_sessions');
        await tester.tap(find.byKey(const Key('session_revoke_b')));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_sessions_dialog');
      });

      testWidgets('trợ giúp', (tester) async {
        await open(tester, '/profile/help');
        await tester.tap(find.text('Làm sao để trả hàng?'));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_help');
      });

      testWidgets('cài đặt thông báo (sắp ra mắt)', (tester) async {
        await open(tester, '/profile/notifications');
        await shoot(tester, '${tag}_coming_soon');
      });

      testWidgets('không tìm thấy trang', (tester) async {
        await useRealFonts(tester);
        tester.view.physicalSize = Size(width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        final router = GoRouter(
          initialLocation: '/khong-co',
          errorBuilder: (_, __) => const NotFoundScreen(),
          routes: [GoRoute(path: '/home', builder: (_, __) => const SizedBox())],
        );
        await tester.pumpWidget(MaterialApp.router(debugShowCheckedModeBanner: false, theme: AppTheme.light, routerConfig: router));
        await tester.pumpAndSettle();
        await shoot(tester, '${tag}_not_found');
      });
    });
  }
}
