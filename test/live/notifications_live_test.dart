// Test tích hợp thông báo với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/notifications_live_test.dart
//
// Tạo 1 tài khoản nông dân ("TEST Mobile Notif <mã>") và 1 đơn hàng thật (huỷ ngay) trên
// DB dev dùng chung để thử sinh thông báo. Thông báo do tiến trình nền của backend tạo
// (nếu BackgroundJobs chưa bật thì sẽ không có): khi đó phần kiểm tra dữ liệu thật được
// BỎ QUA, không tính là đạt.
@Timeout(Duration(minutes: 5))
library;

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:farmer_mobile/features/notifications/data/notification_models.dart';
import 'package:farmer_mobile/features/notifications/data/notification_repository.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

const _ghost = '0198a0f0-4444-7000-8000-000000000000';

Future<ApiException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  fail('Cần ApiException nhưng không có lỗi');
}

void main() {
  late ProviderContainer c;
  late NotificationRepository repo;
  late OrderRepository orders;
  var generated = false;

  setUpAll(() async {
    if (!liveEnabled) return;
    final storage = MemoryTokenStorage();
    c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWith((ref) => createApiDio(
            baseUrl: liveBaseUrl,
            storage: storage,
            onSessionExpired: () async =>
                ref.read(sessionProvider.notifier).markUnauthenticated(),
            adapter: liveAdapter,
          )),
    ]);
    addTearDown(c.dispose);
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final phone = randomPhone();
    await c.read(authControllerProvider).register(
        fullName: 'TEST Mobile Notif $code', phoneNumber: phone, password: 'Test@12345678');
    // ignore: avoid_print
    print('Đã tạo tài khoản test: TEST Mobile Notif $code / $phone');
    repo = c.read(notificationRepositoryProvider);
    orders = c.read(orderRepositoryProvider);
  });

  final skip = liveEnabled ? null : 'Đặt LIVE_API=1 để chạy test với backend thật';

  group('Tài khoản mới', () {
    test('chưa có thông báo: số chưa đọc = 0, danh sách rỗng', () async {
      expect(await repo.unreadCount(), 0);
      final r = await repo.list();
      expect(r.items, isEmpty);
      expect(r.totalCount, 0);
    }, skip: skip);

    test('lọc UNREAD được backend chấp nhận', () async {
      final r = await repo.list(status: NotificationStatus.unread);
      expect(r.items, isEmpty);
    }, skip: skip);

    test('đọc tất cả khi không có gì → thành công (204)', () async {
      await repo.markAllRead();
    }, skip: skip);

    test('đánh dấu / xoá thông báo không tồn tại → 404 tiếng Việt', () async {
      final a = await _failure(() => repo.markRead(_ghost));
      expect(a.statusCode, 404);
      expect(a.message, contains('không còn tồn tại'));
      final b = await _failure(() => repo.archive(_ghost));
      expect(b.statusCode, 404);
    }, skip: skip);
  });

  group('Thông báo thật do backend sinh ra (cần tiến trình nền)', () {
    test('đặt đơn rồi huỷ → chờ tối đa 45 giây xem có thông báo cho nông dân', () async {
      final catalog = c.read(catalogRepositoryProvider);
      final cart = c.read(cartRepositoryProvider);
      String? productId;
      String? packId;
      final all = await catalog.products(pageSize: 100);
      for (final p in all.items) {
        final d = await catalog.product(p.id);
        if (d.purchasable.isNotEmpty) {
          productId = d.id;
          packId = d.purchasable.first.id;
          break;
        }
      }
      await cart.clear();
      await cart.add(storeProductId: productId!, packagingId: packId!, quantity: 1);
      final order = await orders.checkout(settlementType: 'FULL_PAYMENT', fulfillmentType: 'PICKUP');
      await orders.cancel(order.id, reason: 'TEST thông báo');

      for (var i = 0; i < 15 && !generated; i++) {
        await Future<void>.delayed(const Duration(seconds: 3));
        generated = (await repo.unreadCount()) > 0;
      }
      if (!generated) {
        markTestSkipped('Backend không sinh thông báo (BackgroundJobs chưa bật?) — chưa kiểm tra được dữ liệu thật');
        return;
      }

      final page = await repo.list();
      final n = page.items.first;
      // ignore: avoid_print
      print('Thông báo thật: ${n.type} | ${n.title} | entity=${n.entityType}/${n.entityId} order=${n.orderId} → ${n.route}');
      expect(n.title, isNotEmpty);
      expect(n.message, isNotEmpty);
      expect(n.isRead, isFalse);
      expect(n.kind, isNot(NotificationKind.other), reason: 'loại ${n.type} phải được app nhận diện');
      expect(n.route, isNotNull, reason: 'phải mở được màn hình tương ứng');
    }, skip: skip);

    test('đánh dấu đã đọc → số chưa đọc giảm; xoá → biến mất khỏi danh sách', () async {
      if (!generated) {
        markTestSkipped('Chưa có thông báo thật để thử');
        return;
      }
      final before = await repo.unreadCount();
      final n = (await repo.list()).items.first;
      await repo.markRead(n.id);
      expect(await repo.unreadCount(), before - 1);
      await repo.markRead(n.id); // idempotent
      await repo.archive(n.id);
      final after = await repo.list();
      expect(after.items.map((x) => x.id), isNot(contains(n.id)));
    }, skip: skip);
  });
}
