import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/core/network/realtime_events.dart';
import 'dart:async';
import 'package:farmer_mobile/features/ai_doctor/screens/diagnose_case_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_detail_screen.dart';
import 'package:farmer_mobile/features/notifications/data/notification_repository.dart';
import 'package:farmer_mobile/features/notifications/widgets/notification_bell.dart';
import 'package:farmer_mobile/features/products/screens/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/order_fakes.dart';

Future<AppHarness> open(WidgetTester tester,
    {void Function(AppHarness)? setup, String route = '/home/notifications'}) async {
  final h = AppHarness()..signIn();
  h.orders.orders['o1'] = orderOf(id: 'o1', status: 'CONFIRMED');
  setup?.call(h);
  await h.pump(tester, initial: route);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  group('Danh sách thông báo', () {
    testWidgets('hiện tiêu đề, nội dung, thời gian; chưa đọc có chấm đỏ, đã đọc thì không', (tester) async {
      await open(tester, setup: (h) {
        h.notifications.items = [
          notifOf('a', title: 'Đơn hàng đang được giao', type: 'ORDER_STATUS_CHANGED'),
          notifOf('b', title: 'Giao hàng thành công', type: 'DELIVERY_COMPLETED', read: true),
        ];
      });
      expect(find.text('Đơn hàng đang được giao'), findsOneWidget);
      expect(find.text('Nội dung a'), findsOneWidget);
      expect(find.text('5 phút trước'), findsNWidgets(2));
      expect(find.byKey(const Key('notif_dot_a')), findsOneWidget);
      expect(find.byKey(const Key('notif_dot_b')), findsNothing);
    });

    testWidgets('trống: thông báo; lọc chưa đọc mà trống: nêu rõ', (tester) async {
      await open(tester);
      expect(find.text('Bạn không có thông báo nào'), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const Key('notif_read_all'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('notif_filter_UNREAD')));
      await tester.pumpAndSettle();
      expect(find.text('Không có thông báo chưa đọc'), findsOneWidget);
    });

    testWidgets('lọc Chưa đọc gọi API với status=UNREAD', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a'), notifOf('b', read: true)];
      });
      await tester.tap(find.byKey(const Key('notif_filter_UNREAD')));
      await tester.pumpAndSettle();
      expect(h.notifications.listCalls.last, (page: 1, status: 'UNREAD'));
      expect(find.byKey(const Key('notif_a')), findsOneWidget);
      expect(find.byKey(const Key('notif_b')), findsNothing);
    });

    testWidgets('lỗi mạng: Thử lại', (tester) async {
      final h = await open(tester, setup: (h) => h.notifications.listError = notifNet);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
      h.notifications.listError = null;
      h.notifications.items = [notifOf('a')];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notif_a')), findsOneWidget);
    });

    testWidgets('nhiều trang: Xem thêm', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.pageSize0 = 2;
        h.notifications.items = [for (var i = 1; i <= 3; i++) notifOf('n$i')];
      });
      expect(find.byKey(const Key('notif_n3')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('notif_load_more')));
      await tester.tap(find.byKey(const Key('notif_load_more')));
      await tester.pumpAndSettle();
      expect(h.notifications.listCalls.last.page, 2);
      expect(find.byKey(const Key('notif_n3')), findsOneWidget);
    });
  });

  group('Bấm vào thông báo', () {
    testWidgets('đơn hàng: đánh dấu đã đọc rồi mở chi tiết đơn', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a', entityType: 'ORDER', entityId: 'o1')];
      });
      await tester.tap(find.byKey(const Key('notif_a')));
      await tester.pumpAndSettle();
      expect(h.notifications.read, ['a']);
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    });

    testWidgets('khoản nợ → chi tiết công nợ; ca chẩn đoán → chi tiết ca', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [
          notifOf('d', type: 'DEBT_DUE_SOON', entityType: 'DEBT_ENTRY', entityId: 'd1'),
          notifOf('c', type: 'DIAGNOSIS_REVIEWED', entityType: 'DIAGNOSIS_CASE', entityId: 'c1'),
        ];
      });
      await tester.tap(find.byKey(const Key('notif_d')));
      await tester.pumpAndSettle();
      expect(find.byType(DebtDetailScreen), findsOneWidget);
      h.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notif_c')));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnoseCaseScreen), findsOneWidget);
    });

    testWidgets('thông báo không có nơi để mở: chỉ đánh dấu đã đọc, ở lại màn hình', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('x', entityType: null)];
      });
      await tester.tap(find.byKey(const Key('notif_x')));
      await tester.pumpAndSettle();
      expect(h.notifications.read, ['x']);
      expect(find.byKey(const Key('notif_dot_x')), findsNothing);
      expect(find.text('Thông báo'), findsWidgets);
    });

    testWidgets('đánh dấu đã đọc thất bại: hoàn lại chấm đỏ, báo lỗi, vẫn mở màn hình', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a', entityType: 'ORDER', entityId: 'o1')];
        h.notifications.readError = notifNet;
      });
      await tester.tap(find.byKey(const Key('notif_a')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget, reason: 'lỗi đánh dấu không chặn việc mở');
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notif_dot_a')), findsOneWidget);
    });

    testWidgets('bấm thông báo đã đọc: không gọi API đánh dấu lại', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a', read: true, entityType: 'ORDER', entityId: 'o1')];
      });
      await tester.tap(find.byKey(const Key('notif_a')));
      await tester.pumpAndSettle();
      expect(h.notifications.calls.where((c) => c.startsWith('read:')), isEmpty);
    });
  });

  group('Đọc tất cả / xoá', () {
    testWidgets('đọc tất cả: hết chấm đỏ, nút khoá, báo thành công', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a'), notifOf('b')];
      });
      await tester.tap(find.byKey(const Key('notif_read_all')));
      await tester.pumpAndSettle();
      expect(h.notifications.calls, contains('readAll'));
      expect(find.byKey(const Key('notif_dot_a')), findsNothing);
      expect(find.byKey(const Key('notif_dot_b')), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const Key('notif_read_all'))).onPressed, isNull);
      expect(find.text('Đã đánh dấu tất cả là đã đọc'), findsOneWidget);
    });

    testWidgets('đọc tất cả thất bại: hoàn lại và báo lỗi', (tester) async {
      await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a')];
        h.notifications.readAllError = notifNet;
      });
      await tester.tap(find.byKey(const Key('notif_read_all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notif_dot_a')), findsOneWidget);
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
    });

    testWidgets('xoá bằng nút ×: biến mất ngay và gọi API', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a'), notifOf('b')];
      });
      await tester.tap(find.byKey(const Key('notif_delete_a')));
      await tester.pumpAndSettle();
      expect(h.notifications.archived, ['a']);
      expect(find.byKey(const Key('notif_a')), findsNothing);
      expect(find.byKey(const Key('notif_b')), findsOneWidget);
      expect(find.text('Đã xoá thông báo'), findsOneWidget);
    });

    testWidgets('xoá bằng vuốt sang trái', (tester) async {
      final h = await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a')];
      });
      await tester.drag(find.byKey(const Key('notif_a')), const Offset(-900, 0));
      await tester.pumpAndSettle();
      expect(h.notifications.archived, ['a']);
      expect(find.byKey(const Key('notif_a')), findsNothing);
    });

    testWidgets('xoá thất bại: thông báo quay lại đúng chỗ, báo lỗi', (tester) async {
      await open(tester, setup: (h) {
        h.notifications.items = [notifOf('a'), notifOf('b')];
        h.notifications.archiveError = notifNet;
      });
      await tester.tap(find.byKey(const Key('notif_delete_a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notif_a')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('notif_a'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('notif_b'))).dy));
      expect(find.textContaining('Không kết nối được máy chủ'), findsOneWidget);
    });
  });

  group('Chuông ở Home', () {
    late StreamController<String> events;
    setUp(() { events = StreamController<String>.broadcast(); });
    tearDown(() async { await events.close(); });
    Future<FakeNotificationRepository> pumpBell(WidgetTester tester,
        {int? count, Object? countError, Duration poll = const Duration(seconds: 60)}) async {
      final repo = FakeNotificationRepository()
        ..unread0 = count
        ..countError = countError;
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Row(children: [NotificationBell(route: '/n', pollInterval: poll)]),
          ),
        ),
        GoRoute(path: '/n', builder: (_, __) => const Scaffold(body: Text('NOTIF'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo), realtimeEventsProvider.overrideWith((ref) => events.stream)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('không có chưa đọc: không hiện số', (tester) async {
      await pumpBell(tester, count: 0);
      expect(find.byKey(const Key('bell_badge')), findsNothing);
    });

    testWidgets('có chưa đọc: hiện đúng số; trên 99 hiện 99+', (tester) async {
      await pumpBell(tester, count: 7);
      expect(find.text('7'), findsOneWidget);
      await pumpBell(tester, count: 250);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('lỗi mạng: không hiện số (không báo sai)', (tester) async {
      await pumpBell(tester, countError: notifNet);
      expect(find.byKey(const Key('bell_badge')), findsNothing);
      expect(find.byKey(const Key('bell')), findsOneWidget);
    });

    testWidgets('sự kiện realtime cập nhật chuông, đứng yên không polling', (tester) async {
      final repo = await pumpBell(tester, count: 1, poll: const Duration(seconds: 5));
      expect(find.text('1'), findsOneWidget);
      repo.unread0 = 4;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      events.add('notifications');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('bấm chuông mở màn thông báo và hỏi lại số khi quay về', (tester) async {
      final repo = await pumpBell(tester, count: 3);
      await tester.tap(find.byKey(const Key('bell')));
      await tester.pumpAndSettle();
      expect(find.text('NOTIF'), findsOneWidget);
      repo.unread0 = 0;
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bell_badge')), findsNothing);
    });

  });
}
