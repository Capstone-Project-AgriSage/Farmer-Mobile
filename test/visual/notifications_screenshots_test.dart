// Chụp ảnh màn thông báo + chuông bằng font thật (cần mạng để tải font Google).
//
//   SCREENSHOTS=1 FLUTTER_ROOT=/d/Develop/flutter flutter test --update-goldens test/visual/notifications_screenshots_test.dart
//
// Ảnh ra ở test/visual/shots/ (xem xong thì xoá thư mục). Test cũng thất bại nếu
// có lỗi tràn layout với font thật ở cả khung 390px và 320px.
import 'dart:io';

import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/notifications/data/notification_repository.dart';
import 'package:farmer_mobile/features/notifications/widgets/notification_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import '../helpers/notification_fakes.dart';
import 'auth_screenshots_test.dart' show shoot, useRealFonts;

final _on = Platform.environment['SCREENSHOTS'] == '1';

void main() {
  for (final width in [390.0, 320.0]) {
    final tag = width.toInt();

    Future<AppHarness> open(WidgetTester tester, {void Function(AppHarness)? setup}) async {
      await useRealFonts(tester);
      final h = AppHarness()..signIn();
      final now = DateTime.now();
      h.notifications.items = [
        notifOf('a',
            title: 'Đơn hàng đang được giao',
            type: 'ORDER_STATUS_CHANGED',
            at: now.subtract(const Duration(minutes: 12))),
        notifOf('b',
            title: 'Có khoản công nợ quá hạn',
            type: 'DEBT_OVERDUE',
            entityType: 'DEBT_ENTRY',
            at: now.subtract(const Duration(hours: 3))),
        notifOf('c',
            title: 'Chuyên gia đã xét duyệt chẩn đoán',
            type: 'DIAGNOSIS_REVIEWED',
            entityType: 'DIAGNOSIS_CASE',
            read: true,
            at: now.subtract(const Duration(days: 1))),
        notifOf('d',
            title: 'Yêu cầu trả hàng được chấp thuận',
            type: 'RETURN_RESULT',
            entityType: 'SALES_RETURN',
            read: true,
            at: now.subtract(const Duration(days: 3))),
        notifOf('e',
            title: 'Đã xác nhận thanh toán công nợ',
            type: 'DEBT_PAYMENT_CONFIRMED',
            entityType: 'PAYMENT',
            read: true,
            at: DateTime(2026, 9, 5)),
      ];
      setup?.call(h);
      await h.pump(tester, initial: '/home/notifications');
      tester.view.physicalSize = Size(width * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpAndSettle();
      return h;
    }

    group('ảnh thông báo $tag px', skip: !_on ? 'đặt SCREENSHOTS=1' : false, () {
      testWidgets('danh sách', (tester) async {
        await open(tester);
        await shoot(tester, '${tag}_notif_list');
      });

      testWidgets('danh sách trống', (tester) async {
        await open(tester, setup: (h) => h.notifications.items = []);
        await shoot(tester, '${tag}_notif_empty');
      });

      testWidgets('lỗi mạng', (tester) async {
        await open(tester, setup: (h) => h.notifications.listError = notifNet);
        await shoot(tester, '${tag}_notif_error');
      });

      testWidgets('xoá xong có thông báo', (tester) async {
        await open(tester);
        await tester.tap(find.byKey(const Key('notif_delete_a')));
        await tester.pump(const Duration(milliseconds: 100));
        await shoot(tester, '${tag}_notif_deleted');
      });

      testWidgets('chuông: 0 / 5 / 120', (tester) async {
        await useRealFonts(tester);
        tester.view.physicalSize = Size(width * 2, 200);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        for (final n in [0, 5, 120]) {
          final repo = FakeNotificationRepository()..unread0 = n;
          await tester.pumpWidget(ProviderScope(
            key: ValueKey(n),
            overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: Scaffold(
                appBar: AppBar(
                  title: const Text('Xin chào, Trần Văn Hải'),
                  actions: const [NotificationBell(route: '/x')],
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          await shoot(tester, '${tag}_notif_bell_$n');
        }
      });
    });
  }
}
