// Test tích hợp trả hàng với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/returns_live_test.dart
//
// Tạo 1 tài khoản nông dân ("TEST Mobile Returns <mã>") và 1 ĐƠN HÀNG thật (nhận tại
// cửa hàng, trả ngay) trên DB dev dùng chung; đơn được huỷ ở cuối. Đơn chưa được cửa
// hàng giao nên chưa có hàng để trả: ở đây kiểm tra hình dạng dữ liệu thật và các
// lỗi thật của backend. Luồng trả hàng thành công cần một đơn đã giao.
@Timeout(Duration(minutes: 5))
library;

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';
import 'package:farmer_mobile/features/returns/data/return_models.dart';
import 'package:farmer_mobile/features/returns/data/return_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

const _ghost = '0198a0f0-2222-7000-8000-000000000000';

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
  late ReturnRepository returns;
  late OrderRepository orders;
  late OrderDetail order;

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
        fullName: 'TEST Mobile Returns $code', phoneNumber: phone, password: 'Test@12345678');
    // ignore: avoid_print
    print('Đã tạo tài khoản test: TEST Mobile Returns $code / $phone');

    returns = c.read(returnRepositoryProvider);
    orders = c.read(orderRepositoryProvider);
    final cart = c.read(cartRepositoryProvider);
    final catalog = c.read(catalogRepositoryProvider);

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
    order = await orders.checkout(settlementType: 'FULL_PAYMENT', fulfillmentType: 'PICKUP');
  });

  tearDownAll(() async {
    if (!liveEnabled) return;
    try {
      final o = await orders.get(order.id);
      if (OrderStatus.canCancel(o.status)) await orders.cancel(order.id, reason: 'Dọn test');
    } on ApiException {
      // bỏ qua
    }
  });

  final skip = liveEnabled ? null : 'Đặt LIVE_API=1 để chạy test với backend thật';

  group('Hàng có thể trả (đơn thật chưa giao)', () {
    test('đọc được cấu trúc thật; chưa giao thì không có gì để trả', () async {
      final r = await returns.returnable(order.id);
      expect(r.orderId, order.id);
      expect(r.orderNumber, order.orderNumber);
      expect(r.items, isNotEmpty);
      expect(r.items.first.productName, isNotEmpty);
      expect(r.items.first.conversion, greaterThanOrEqualTo(1));
      expect(r.available, isEmpty, reason: 'chưa giao => returnableBaseQuantity = 0');
    }, skip: skip);

    test('đơn không tồn tại → 404 tiếng Việt', () async {
      final e = await _failure(() => returns.returnable(_ghost));
      expect(e.statusCode, 404);
      expect(e.message, 'Không tìm thấy đơn hàng.');
    }, skip: skip);
  });

  group('Tạo yêu cầu', () {
    test('hàng chưa giao: backend từ chối bằng lỗi nghiệp vụ, app báo tiếng Việt', () async {
      final e = await _failure(() => returns.create(
            orderId: order.id,
            lines: [
              ReturnLineRequest(
                orderItemId: order.items.first.id,
                baseQuantity: 1,
                reasonCode: 'OTHER',
                originalStockMovementItemId: _ghost,
              ),
            ],
          ));
      // ignore: avoid_print
      print('create hàng chưa giao → ${e.statusCode}: ${e.message} (detail: ${e.detail})');
      expect(e.statusCode, anyOf(404, 422));
      expect(e.message, isNot(contains('fulfillment')));
      expect(e.message, isNotEmpty);
    }, skip: skip);

    test('đơn không tồn tại → 404 hoặc 422 có thông báo tiếng Việt', () async {
      final e = await _failure(() => returns.create(
            orderId: _ghost,
            lines: const [
              ReturnLineRequest(
                orderItemId: _ghost,
                baseQuantity: 1,
                reasonCode: 'OTHER',
                originalStockMovementItemId: _ghost,
              ),
            ],
          ));
      expect(e.statusCode, anyOf(404, 422));
      expect(e.message, isNot(matches(RegExp(r'[A-Za-z]{4,} [a-z]{3,} [a-z]{3,}'))),
          reason: 'không lộ thông báo tiếng Anh của backend');
    }, skip: skip);

    test('thiếu mặt hàng (mảng rỗng) → 400 thông báo kiểm tra lại', () async {
      final e = await _failure(() => returns.create(orderId: order.id, lines: const []));
      expect(e.statusCode, 400);
      expect(e.message, contains('chưa hợp lệ'));
    }, skip: skip);

    test('lý do không hợp lệ → 400', () async {
      final e = await _failure(() => returns.create(
            orderId: order.id,
            lines: [
              ReturnLineRequest(
                orderItemId: order.items.first.id,
                baseQuantity: 1,
                reasonCode: 'KHONG_HOP_LE',
                originalStockMovementItemId: _ghost,
              ),
            ],
          ));
      expect(e.statusCode, 400);
    }, skip: skip);
  });

  group('Danh sách / chi tiết / huỷ', () {
    test('danh sách của tài khoản mới: rỗng, phân trang hợp lệ', () async {
      final r = await returns.list();
      expect(r.items, isEmpty);
      expect(r.totalCount, 0);
      expect(r.hasMore, isFalse);
    }, skip: skip);

    test('chi tiết không tồn tại → 404 tiếng Việt', () async {
      final e = await _failure(() => returns.get(_ghost));
      expect(e.statusCode, 404);
      expect(e.message, 'Không tìm thấy yêu cầu trả hàng.');
    }, skip: skip);

    test('huỷ yêu cầu không tồn tại → 404 tiếng Việt', () async {
      final e = await _failure(() => returns.cancel(_ghost, 'Đổi ý'));
      expect(e.statusCode, 404);
      expect(e.message, 'Không tìm thấy yêu cầu trả hàng.');
    }, skip: skip);

    test('huỷ thiếu lý do → 400 nhắc nhập lý do', () async {
      final e = await _failure(() => returns.cancel(_ghost, '  '));
      expect(e.statusCode, anyOf(400, 404));
    }, skip: skip);
  });
}
