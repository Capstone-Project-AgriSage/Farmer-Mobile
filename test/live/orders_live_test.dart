// Test tích hợp đặt hàng / thanh toán / hạn mức với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/orders_live_test.dart
//
// Tạo 1 tài khoản nông dân ("TEST Mobile Orders <mã>") và vài ĐƠN HÀNG thật trên DB
// dev dùng chung; mọi đơn được huỷ ở cuối (đơn đã huỷ vẫn còn trong DB).
@Timeout(Duration(minutes: 10))
library;

import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/data/models/address.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

const _ghost = '0198a0f0-0000-7000-8000-000000000000';

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
  late OrderRepository orders;
  late PaymentRepository pay;
  late CreditRepository credit;
  late CartRepository cart;
  late CatalogRepository catalog;
  late ProfileRepository profile;

  late String productId;
  late String packId;
  late Address address;
  final created = <String>[];

  Future<void> fillCart({int qty = 1}) async {
    await cart.clear();
    await cart.add(storeProductId: productId, packagingId: packId, quantity: qty);
  }

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
        fullName: 'TEST Mobile Orders $code', phoneNumber: phone, password: 'Test@12345678');
    // ignore: avoid_print
    print('Đã tạo tài khoản test: TEST Mobile Orders $code / $phone');

    orders = c.read(orderRepositoryProvider);
    pay = c.read(paymentRepositoryProvider);
    credit = c.read(creditRepositoryProvider);
    cart = c.read(cartRepositoryProvider);
    catalog = c.read(catalogRepositoryProvider);
    profile = c.read(profileRepositoryProvider);

    final all = await catalog.products(pageSize: 100);
    for (final p in all.items) {
      final d = await catalog.product(p.id);
      if (d.purchasable.isNotEmpty) {
        productId = d.id;
        packId = d.purchasable.first.id;
        break;
      }
    }
    address = await profile.createAddress(const AddressInput(
        recipientName: 'Nguyễn Test',
        recipientPhone: '0912345678',
        addressLine: 'Ấp Test',
        province: 'Cần Thơ',
        ward: 'Tân Phú',
        district: 'Cái Răng',
        addressType: AddressType.farm));
  });

  tearDownAll(() async {
    if (!liveEnabled) return;
    for (final id in created) {
      try {
        final o = await orders.get(id);
        if (OrderStatus.canCancel(o.status)) await orders.cancel(id, reason: 'Dọn test');
      } on ApiException {
        // bỏ qua
      }
    }
  });

  group('đặt hàng', skip: !liveEnabled ? 'đặt LIVE_API=1 để chạy' : false, () {
    test('giỏ trống → 422 tiếng Việt', () async {
      await cart.clear();
      final e = await _failure(() => orders.checkout(
          settlementType: 'FULL_PAYMENT', fulfillmentType: 'PICKUP'));
      expect(e.statusCode, 422);
      expect(e.message, contains('Giỏ hàng đang trống'));
    });

    test('giao hàng mà không có địa chỉ → 400', () async {
      await fillCart();
      final e = await _failure(() => orders.checkout(
          settlementType: 'FULL_PAYMENT', fulfillmentType: 'DELIVERY'));
      expect(e.statusCode, 400);
    });

    test('địa chỉ không tồn tại → thông báo chọn lại', () async {
      await fillCart();
      final e = await _failure(() => orders.checkout(
          settlementType: 'FULL_PAYMENT',
          fulfillmentType: 'DELIVERY',
          addressId: _ghost));
      expect(e.statusCode, anyOf(404, 422));
    });

    test('hạn mức: tài khoản mới chưa được cấp (null) và mua ghi nợ bị từ chối rõ ràng',
        () async {
      expect(await credit.mine(), isNull);
      await fillCart();
      final e = await _failure(() => orders.checkout(
          settlementType: 'CREDIT', fulfillmentType: 'PICKUP'));
      expect(e.statusCode, 422);
      expect(e.message, contains('chưa được cửa hàng cấp hạn mức'));
      // Đơn bị từ chối thì giỏ KHÔNG bị mất.
      expect((await cart.get()).isEmpty, isFalse);
    });

    test('nhận tại cửa hàng, trả ngay: tạo đơn, giỏ được làm rỗng', () async {
      await fillCart(qty: 2);
      final before = await cart.get();

      final o = await orders.checkout(
          settlementType: 'FULL_PAYMENT',
          fulfillmentType: 'PICKUP',
          note: '  Test nhận tại cửa hàng ');
      created.add(o.id);

      expect(o.status, OrderStatus.pending);
      expect(o.fulfillmentType, 'PICKUP');
      expect(o.address, isNull);
      expect(o.note, 'Test nhận tại cửa hàng');
      expect(o.items.single.quantity, 2);
      expect(o.totalAmount, before.subtotal);
      expect(o.orderNumber, isNotEmpty);
      expect((await cart.get()).isEmpty, isTrue, reason: 'giỏ đã chuyển thành đơn');
    });

    test('giao hàng tận nơi: lưu địa chỉ ở thời điểm đặt (không đổi khi sửa sổ địa chỉ)',
        () async {
      await fillCart();
      final o = await orders.checkout(
          settlementType: 'FULL_PAYMENT',
          fulfillmentType: 'DELIVERY',
          addressId: address.id);
      created.add(o.id);

      expect(o.address?.recipientName, 'Nguyễn Test');
      expect(o.address?.fullAddress, 'Ấp Test, Tân Phú, Cái Răng, Cần Thơ');

      await profile.updateAddress(
          address.id,
          const AddressInput(
              recipientName: 'Tên khác',
              recipientPhone: '0912345678',
              addressLine: 'Số mới',
              province: 'An Giang',
              addressType: AddressType.home));
      final again = await orders.get(o.id);
      expect(again.address?.recipientName, 'Nguyễn Test');
    });

    test('danh sách đơn: mới nhất trước, lọc trạng thái, phân trang', () async {
      final all = await orders.list();
      expect(all.items.length, greaterThanOrEqualTo(2));
      expect(all.items.first.createdAt.isAfter(all.items.last.createdAt) ||
          all.items.first.createdAt.isAtSameMomentAs(all.items.last.createdAt), isTrue);

      final pending = await orders.list(status: OrderStatus.pending);
      expect(pending.items.every((o) => o.status == OrderStatus.pending), isTrue);
      final none = await orders.list(status: OrderStatus.completed);
      expect(none.items, isEmpty);

      final small = await orders.list(page: 1);
      expect(small.totalCount, all.totalCount);
    });

    test('chi tiết đơn và đơn của người khác/không tồn tại → 404', () async {
      final id = created.first;
      final o = await orders.get(id);
      expect(o.items, isNotEmpty);
      final e = await _failure(() => orders.get(_ghost));
      expect(e.kind, ApiErrorKind.notFound);
      expect(e.message, 'Không tìm thấy đơn hàng.');
    });

    test('tóm tắt thanh toán: chưa trả gì, còn phải trả = tổng đơn', () async {
      final o = await orders.get(created.first);
      final p = await orders.payments(created.first);
      expect(p.orderTotal, o.totalAmount);
      expect(p.paidAmount, 0);
      expect(p.remainingToPay, o.totalAmount);
      expect(p.isFullyPaid, isFalse);
    });

    test('giao hàng của đơn chưa xác nhận: danh sách rỗng', () async {
      expect(await orders.deliveries(created.last), isEmpty);
    });
  });

  group('payOS', skip: !liveEnabled ? 'đặt LIVE_API=1 để chạy' : false, () {
    test('tạo link: hoặc có QR + hạn dùng, hoặc 503 (chưa cấu hình) với thông báo tiếng Việt',
        () async {
      final id = created.first;
      PayOsLink? link;
      try {
        link = await pay.createForOrder(id);
      } on ApiException catch (e) {
        expect(e.kind, ApiErrorKind.unavailable);
        expect(e.message, contains('thanh toán tại cửa hàng'));
        // ignore: avoid_print
        print('payOS chưa cấu hình trên server dev (503): bỏ qua phần link');
        return;
      }
      expect(link.checkoutUrl, startsWith('http'));
      expect(link.amount, (await orders.get(id)).totalAmount);
      expect(link.status, PaymentStatus.pending);
      // ignore: avoid_print
      print('payOS tạo link được: qr=${link.qrCode != null} hết hạn=${link.expiresAt}');

      final p = await pay.get(link.paymentId);
      expect(p.isPending, isTrue);

      // Tạo link mới thì link cũ bị huỷ (mỗi đơn chỉ một link chờ).
      final second = await pay.createForOrder(id);
      expect(second.paymentId, isNot(link.paymentId));
      expect((await pay.get(link.paymentId)).isPending, isFalse);

      final summary = await orders.payments(id);
      expect(summary.pendingPayOs?.id, second.paymentId);

      // Hỏi payOS: vẫn chờ (không ai trả tiền).
      expect((await pay.sync(second.paymentId)).isPending, isTrue);

      // Dev server giả lập: đánh dấu đã trả; môi trường thật trả 404.
      try {
        final paid = await pay.simulatePaid(second.paymentId);
        expect(paid.isPaid, isTrue);
        final after = await orders.payments(id);
        expect(after.isFullyPaid, isTrue);
        expect(after.paidAmount, after.orderTotal);
      } on ApiException catch (e) {
        expect(e.statusCode, 404);
        await pay.cancel(second.paymentId);
        expect((await pay.get(second.paymentId)).status, PaymentStatus.cancelled);
      }
    });

    test('thanh toán đơn của người khác / không tồn tại → 404', () async {
      final e = await _failure(
          () => pay.createForOrder(_ghost));
      expect(e.statusCode, anyOf(404, 503));
    });
  });

  group('huỷ đơn', skip: !liveEnabled ? 'đặt LIVE_API=1 để chạy' : false, () {
    test('huỷ đơn chờ xác nhận (có lý do) → CANCELLED', () async {
      final id = created.last;
      final c1 = await orders.cancel(id, reason: 'Đổi ý (test)');
      expect(c1.status, OrderStatus.cancelled);
      expect(c1.cancelReason, 'Đổi ý (test)');
      expect(c1.cancelledAt, isNotNull);
    });

    test('huỷ lần nữa → 422 "liên hệ cửa hàng"', () async {
      final e = await _failure(() => orders.cancel(created.last));
      expect(e.statusCode, 422);
      expect(e.message, contains('liên hệ cửa hàng'));
    });

    test('đơn đã huỷ không thanh toán được', () async {
      final e = await _failure(() => pay.createForOrder(created.last));
      expect(e.statusCode, anyOf(422, 503));
    });

    test('huỷ đơn có thanh toán đã trả (nếu server giả lập) hoặc đơn còn lại', () async {
      final id = created.first;
      final o = await orders.get(id);
      if (OrderStatus.canCancel(o.status)) {
        final r = await orders.cancel(id);
        expect(r.status, OrderStatus.cancelled);
      }
      final p = await orders.payments(id);
      // Đã trả mà huỷ → phải có yêu cầu hoàn tiền.
      if (p.paidAmount > 0) expect(p.refundCount, greaterThan(0));
    });

    test('đơn đã huỷ hiện đúng ở danh sách lọc "Đã huỷ"', () async {
      final cancelled = await orders.list(status: OrderStatus.cancelled);
      expect(cancelled.items.map((o) => o.id), containsAll(created.take(1)));
    });
  });
}
