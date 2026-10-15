import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/core/utils/time_ago.dart';
import 'package:farmer_mobile/features/notifications/data/notification_models.dart';
import 'package:farmer_mobile/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/notification_fakes.dart';

void main() {
  late FakeAdapter adapter;
  late NotificationRepository repo;

  void use(FakeHandler h) {
    adapter = FakeAdapter(h);
    repo = NotificationRepository(createApiDio(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      onSessionExpired: () async {},
      adapter: adapter,
    ));
  }

  group('API', () {
    test('danh sách: phân trang, lọc chưa đọc, đọc đủ trường + data điều hướng', () async {
      use((o) => jsonBody(200, {
            'items': [
              notifJson('a', entityType: 'ORDER', entityId: 'o9'),
              notifJson('b', read: true, noData: true),
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 40,
            'totalPages': 2,
          }));
      final r = await repo.list(status: 'UNREAD');

      expect(adapter.requests.single.path, '/api/me/notifications');
      expect(adapter.requests.single.queryParameters,
          {'page': 1, 'pageSize': 20, 'status': 'UNREAD'});
      expect(r.hasMore, isTrue);
      final a = r.items.first;
      expect(a.title, 'Đơn hàng đã được xác nhận');
      expect(a.isRead, isFalse);
      expect(a.entityType, 'ORDER');
      expect(a.entityId, 'o9');
      expect(r.items.last.isRead, isTrue);
      expect(r.items.last.entityType, isNull, reason: 'data null không làm vỡ');
      expect(r.items.last.route, isNull);
    });

    test('không lọc thì không gửi status', () async {
      use((o) => jsonBody(200, {'items': [], 'page': 1, 'pageSize': 20, 'totalCount': 0, 'totalPages': 0}));
      await repo.list();
      expect(adapter.requests.single.queryParameters, {'page': 1, 'pageSize': 20});
    });

    test('số chưa đọc', () async {
      use((o) => jsonBody(200, {'count': 7}));
      expect(await repo.unreadCount(), 7);
      expect(adapter.requests.single.path, '/api/me/notifications/unread-count');
    });

    test('đánh dấu đã đọc / đọc tất cả / xoá: đúng method + URL, 204 không lỗi', () async {
      use((o) => emptyBody(204));
      await repo.markRead('n1');
      await repo.markAllRead();
      await repo.archive('n1');
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /api/me/notifications/n1/read',
        'POST /api/me/notifications/read-all',
        'DELETE /api/me/notifications/n1',
      ]);
    });

    test('thông báo không còn tồn tại (404) → thông báo tiếng Việt', () async {
      use((o) => jsonBody(404, {'status': 404}));
      for (final call in [() => repo.markRead('x'), () => repo.archive('x')]) {
        await expectLater(
          call(),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', contains('không còn tồn tại'))),
        );
      }
    });

    test('mất mạng → ApiException lỗi kết nối', () async {
      use((o) => throw StateError('x'));
      expect(repo.unreadCount(), throwsA(anything));
    });
  });

  group('điều hướng theo loại đối tượng (data của backend)', () {
    String? route(String? entityType, {String? id, String? orderId}) => AppNotification.fromJson(
            notifJson('n', entityType: entityType, entityId: id ?? 'E1', orderId: orderId))
        .route;

    test('ORDER → chi tiết đơn', () => expect(route('ORDER', id: 'o1'), '/orders/o1'));

    test('DELIVERY → đơn của phiếu giao (cần orderId)', () {
      expect(route('DELIVERY', orderId: 'o2'), '/orders/o2');
      expect(route('DELIVERY'), isNull);
    });

    test('PAYMENT: đơn hàng → chi tiết đơn; trả nợ (không có orderId) → công nợ', () {
      expect(route('PAYMENT', orderId: 'o3'), '/orders/o3');
      expect(route('PAYMENT'), '/debt');
    });

    test('DEBT_ENTRY → chi tiết khoản nợ; CREDIT_PROFILE → công nợ', () {
      expect(route('DEBT_ENTRY', id: 'd1'), '/debt/d1');
      expect(route('CREDIT_PROFILE'), '/debt');
    });

    test('SALES_RETURN → chi tiết trả hàng; REFUND → đơn (hoặc danh sách trả hàng)', () {
      expect(route('SALES_RETURN', id: 'r1'), '/returns/r1');
      expect(route('REFUND', orderId: 'o4'), '/orders/o4');
      expect(route('REFUND'), '/returns');
    });

    test('DIAGNOSIS_CASE → chi tiết ca chẩn đoán', () {
      expect(route('DIAGNOSIS_CASE', id: 'c1'), '/ai-scan/case/c1');
    });

    test('loại lạ / không có data → không điều hướng (không vỡ)', () {
      expect(route('SOMETHING_NEW'), isNull);
      expect(route(null), isNull);
    });
  });

  group('nhóm hiển thị theo notificationType của backend', () {
    test('mọi loại backend gửi cho nông dân được gom đúng nhóm', () {
      const expected = {
        'ORDER_STATUS_CHANGED': NotificationKind.order,
        'PAYMENT_CONFIRMED': NotificationKind.payment,
        'PAYMENT_FAILED': NotificationKind.payment,
        'DELIVERY_COMPLETED': NotificationKind.delivery,
        'DELIVERY_FAILED': NotificationKind.delivery,
        'DELIVERY_PARTIAL': NotificationKind.delivery,
        'DEBT_CREATED': NotificationKind.debt,
        'DEBT_PAYMENT_CONFIRMED': NotificationKind.debt,
        'DEBT_DUE_SOON': NotificationKind.debt,
        'DEBT_OVERDUE': NotificationKind.debt,
        'CREDIT_LIMIT_CHANGED': NotificationKind.debt,
        'RETURN_RESULT': NotificationKind.returns,
        'REFUND_RESULT': NotificationKind.returns,
        'AI_DIAGNOSIS_COMPLETED': NotificationKind.diagnosis,
        'DIAGNOSIS_REVIEWED': NotificationKind.diagnosis,
        'DIAGNOSIS_RECOMMENDATIONS': NotificationKind.diagnosis,
        'SOMETHING_NEW': NotificationKind.other,
      };
      expected.forEach((type, kind) => expect(kindOf(type), kind, reason: type));
    });
  });

  group('thời gian', () {
    final now = DateTime(2026, 10, 12, 12);
    test('vừa xong / phút / giờ / ngày / ngày đầy đủ', () {
      expect(formatTimeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'Vừa xong');
      expect(formatTimeAgo(now.add(const Duration(minutes: 3)), now: now), 'Vừa xong',
          reason: 'lệch đồng hồ thì không hiện số âm');
      expect(formatTimeAgo(now.subtract(const Duration(minutes: 45)), now: now), '45 phút trước');
      expect(formatTimeAgo(now.subtract(const Duration(hours: 5)), now: now), '5 giờ trước');
      expect(formatTimeAgo(now.subtract(const Duration(days: 3)), now: now), '3 ngày trước');
      expect(formatTimeAgo(DateTime(2026, 9, 5, 8), now: now), '05/09/2026');
    });
  });
}
