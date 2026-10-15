import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/order_fakes.dart';

void main() {
  late FakeAdapter adapter;
  late OrderRepository orders;
  late PaymentRepository pay;
  late CreditRepository credit;

  void use(FakeHandler h) {
    adapter = FakeAdapter(h);
    final dio = createApiDio(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      onSessionExpired: () async {},
      adapter: adapter,
    );
    orders = OrderRepository(dio);
    pay = PaymentRepository(dio);
    credit = CreditRepository(dio);
  }

  Future<ApiException> checkoutFails(Map<String, dynamic> body, {int status = 422}) async {
    use((o) => jsonBody(status, body));
    try {
      await orders.checkout(settlementType: 'CREDIT', fulfillmentType: 'PICKUP');
    } on ApiException catch (e) {
      return e;
    }
    fail('phải lỗi');
  }

  group('đặt hàng', () {
    test('giao hàng: gửi source FARMER_MOBILE, addressId, ghi chú đã trim', () async {
      use((o) => jsonBody(201, orderJson()));

      final o = await orders.checkout(
          settlementType: 'FULL_PAYMENT',
          fulfillmentType: 'DELIVERY',
          addressId: 'a1',
          note: '  Giao buổi sáng  ');

      expect(adapter.requests.single.path, '/api/me/orders');
      expect(adapter.requests.single.data, {
        'source': 'FARMER_MOBILE',
        'settlementType': 'FULL_PAYMENT',
        'fulfillmentType': 'DELIVERY',
        'addressId': 'a1',
        'note': 'Giao buổi sáng',
      });
      expect(o.orderNumber, 'DH-20261012-0001');
      expect(o.address?.fullAddress, 'Ấp 3, Tân Phú, Cái Răng, Cần Thơ');
      expect(o.items.single.quantity, 2);
    });

    test('nhận tại cửa hàng: KHÔNG gửi địa chỉ; ghi chú rỗng thì bỏ', () async {
      use((o) => jsonBody(201, orderJson(fulfillment: 'PICKUP')));

      await orders.checkout(
          settlementType: 'FULL_PAYMENT',
          fulfillmentType: 'PICKUP',
          addressId: 'a1', // bị bỏ qua
          note: '   ');

      expect(adapter.requests.single.data, {
        'source': 'FARMER_MOBILE',
        'settlementType': 'FULL_PAYMENT',
        'fulfillmentType': 'PICKUP',
      });
    });

    test('lý do từ chối mua ghi nợ → thông báo tiếng Việt cụ thể', () async {
      final cases = {
        'Credit refused: OVERDUE_DEBT.': 'nợ quá hạn',
        'Credit refused: INSUFFICIENT_CREDIT.': 'không đủ',
        'Credit refused: CREDIT_DISABLED.': 'chưa được cửa hàng cấp',
        'Credit refused: NO_CREDIT_LIMIT.': 'chưa được cửa hàng cấp',
        'Credit refused: NO_CREDIT_TERM.': 'chưa được cửa hàng cấp',
        'Not enough sellable stock for the credit order.': 'không đủ hàng',
        'The cart is empty.': 'Giỏ hàng đang trống',
        'An order can have at most 100 lines.': 'quá nhiều sản phẩm',
      };
      for (final entry in cases.entries) {
        final e = await checkoutFails(problem(422, entry.key));
        expect(e.message, contains(entry.value), reason: entry.key);
        expect(e.statusCode, 422);
      }
    });

    test('dòng giỏ không còn bán (errors.items[i]) → nhắc kiểm tra giỏ', () async {
      final e = await checkoutFails(problem(422, 'Only ACTIVE sale packagings can be ordered.',
          errors: {
            'items[0]': ['Only ACTIVE sale packagings can be ordered.']
          }));
      expect(e.message, contains('kiểm tra lại giỏ hàng'));
    });

    test('địa chỉ không phải của mình / đã xoá (404) → chọn lại địa chỉ', () async {
      final e = await checkoutFails(problem(404, 'User address not found'), status: 404);
      expect(e.message, contains('Địa chỉ giao hàng không còn tồn tại'));
    });

    test('lỗi 422 lạ (tiếng Anh): câu tiếng Việt chung, vẫn giữ detail gốc', () async {
      final e = await checkoutFails(problem(422, 'Something new.'));
      expect(e.message, contains('Không đặt được đơn hàng'));
      expect(e.detail, 'Something new.');
    });

    test('lỗi 422 lạ nhưng đã là tiếng Việt: hiện nguyên văn', () async {
      final e = await checkoutFails(problem(422, 'Cửa hàng tạm ngưng nhận đơn.'));
      expect(e.message, 'Cửa hàng tạm ngưng nhận đơn.');
    });
  });

  group('đơn của tôi', () {
    test('danh sách: lọc trạng thái, phân trang', () async {
      use((o) => jsonBody(200, {
            'items': [
              {
                'id': 'o1',
                'orderNumber': 'DH-1',
                'source': 'FARMER_MOBILE',
                'customerType': 'REGISTERED',
                'customerName': 'A',
                'settlementType': 'CREDIT',
                'fulfillmentType': 'PICKUP',
                'status': 'CONFIRMED',
                'totalAmount': 500000.0,
                'itemCount': 3,
                'createdAt': '2026-10-12T02:30:00Z',
                'confirmedAt': null,
              }
            ],
            'page': 1,
            'pageSize': 20,
            'totalCount': 1,
            'totalPages': 1,
          }));

      final page = await orders.list(status: 'CONFIRMED');
      await orders.list(page: 2);

      expect(adapter.requests[0].queryParameters,
          {'page': 1, 'pageSize': 20, 'status': 'CONFIRMED'});
      expect(adapter.requests[1].queryParameters, {'page': 2, 'pageSize': 20});
      final o = page.items.single;
      expect(o.itemCount, 3);
      expect(o.settlementType, SettlementType.credit);
      expect(o.createdAt.isUtc, isFalse); // đã đổi sang giờ máy
    });

    test('huỷ: gửi lý do nếu có; 422 → "liên hệ cửa hàng"', () async {
      use((o) => o.path.endsWith('/x/cancel')
          ? jsonBody(422, problem(422, 'only an order waiting for confirmation can be cancelled'))
          : jsonBody(200, orderJson(status: 'CANCELLED', cancelReason: 'Đổi ý')));

      final c = await orders.cancel('o1', reason: '  Đổi ý ');
      await orders.cancel('o2', reason: '  ');

      expect(adapter.requests[0].data, {'reason': 'Đổi ý'});
      expect(adapter.requests[1].data, isEmpty);
      expect(c.status, OrderStatus.cancelled);
      expect(c.cancelReason, 'Đổi ý');

      await expectLater(
        orders.cancel('x'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'm', contains('liên hệ cửa hàng'))),
      );
    });

    test('giao hàng: tài xế, dòng, các lần giao', () async {
      use((o) => jsonBody(200, [
            {
              'id': 'd1',
              'deliveryNumber': 'DL-1',
              'status': 'PARTIALLY_DELIVERED',
              'scheduledAt': null,
              'dispatchedAt': '2026-10-12T05:00:00Z',
              'completedAt': null,
              'assignedTo': {'fullName': 'Trần Văn B', 'phoneNumber': '0912000111'},
              'items': [
                {
                  'orderItemId': 'oi1',
                  'productName': 'NPK',
                  'packagingName': 'Thùng',
                  'plannedQuantity': 2,
                  'deliveredQuantity': 1,
                  'remainingQuantity': 1,
                }
              ],
              'attempts': [
                {
                  'attemptNumber': 1,
                  'status': 'FAILED',
                  'startedAt': '2026-10-12T05:10:00Z',
                  'completedAt': '2026-10-12T05:20:00Z',
                  'receiverName': null,
                  'proofImageUrl': null,
                  'failureReasonCode': 'CUSTOMER_ABSENT',
                }
              ],
            }
          ]));

      final list = await orders.deliveries('o1');

      expect(adapter.requests.single.path, '/api/me/orders/o1/deliveries');
      final d = list.single;
      expect(d.driverName, 'Trần Văn B');
      expect(d.lines.single.remaining, 1);
      expect(d.attempts.single.failureReasonCode, 'CUSTOMER_ABSENT');
      expect(DeliveryStatus.failureLabel('CUSTOMER_ABSENT'), 'Khách vắng nhà');
      expect(DeliveryStatus.label('PARTIALLY_DELIVERED'), 'Đã giao một phần');
    });

    test('tóm tắt thanh toán: đã trả, còn lại, link đang chờ, hoàn tiền', () async {
      use((o) => jsonBody(200, {
            'orderId': 'o1',
            'orderTotal': 1560000.0,
            'paidAmount': 0.0,
            'availablePrepayment': 0.0,
            'consumedPrepayment': 0.0,
            'remainingToPay': 1560000.0,
            'payments': [
              {
                'id': 'p1',
                'paymentNumber': 'PM-1',
                'paymentContext': 'ORDER_PAYMENT',
                'paymentMethod': 'PAYOS',
                'amount': 1560000.0,
                'status': 'PENDING',
                'payerName': 'A',
                'confirmedAt': null,
                'initiatedAt': '2026-10-12T02:31:00Z',
              }
            ],
            'refunds': [{}, {}],
          }));

      final p = await orders.payments('o1');

      expect(p.isFullyPaid, isFalse);
      expect(p.pendingPayOs?.id, 'p1');
      expect(p.refundCount, 2);
      expect(PaymentMethod.label('PAYOS'), 'payOS (VietQR)');
    });
  });

  group('payOS', () {
    test('tạo link: ORDER_PAYMENT + orderId, không gửi amount (trả hết phần còn lại)', () async {
      use((o) => jsonBody(200, {
            'paymentId': 'p1',
            'paymentNumber': 'PM-20261012-0001',
            'amount': 1560000.0,
            'checkoutUrl': 'https://pay.payos.vn/web/x',
            'qrCode': '0002010102',
            'providerOrderCode': 123,
            'expiresAt': '2026-10-12T03:00:00Z',
            'status': 'PENDING',
          }));

      final link = await pay.createForOrder('o1');

      expect(adapter.requests.single.path, '/api/me/payments/payos');
      expect(adapter.requests.single.data,
          {'paymentContext': 'ORDER_PAYMENT', 'orderId': 'o1'});
      expect(link.qrCode, '0002010102');
      expect(link.expiresAt, isNotNull);
    });

    test('payOS chưa cấu hình / gián đoạn (503) → gợi ý trả tại cửa hàng', () async {
      use((o) => jsonBody(503, problem(503, 'Payment gateway unavailable')));
      await expectLater(
        pay.createForOrder('o1'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'k', ApiErrorKind.unavailable)
            .having((e) => e.message, 'm', contains('thanh toán tại cửa hàng'))),
      );
    });

    test('đơn đã trả đủ / đã huỷ (422) → thông báo riêng', () async {
      use((o) => jsonBody(422, problem(422, "Order 'DH-1' has nothing left to pay.")));
      await expectLater(pay.createForOrder('o1'),
          throwsA(isA<ApiException>().having((e) => e.message, 'm', 'Đơn hàng đã được thanh toán đủ.')));

      use((o) => jsonBody(422, problem(422, "Order 'DH-1' is CANCELLED; it cannot take a payment.")));
      await expectLater(pay.createForOrder('o1'),
          throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('đã huỷ'))));
    });

    test('get / sync / cancel / simulate gọi đúng route', () async {
      use((o) => jsonBody(200, {
            'id': 'p1',
            'paymentNumber': 'PM-1',
            'status': 'PAID',
            'amount': 1.0,
          }));

      expect((await pay.get('p1')).isPaid, isTrue);
      await pay.sync('p1');
      await pay.cancel('p1');
      await pay.simulatePaid('p1');

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /api/me/payments/p1',
        'POST /api/payments/p1/sync',
        'POST /api/me/payments/p1/cancel',
        'POST /api/payments/p1/simulate-paid',
      ]);
    });

    test('giả lập khi server không bật chế độ giả lập (404)', () async {
      use((o) => jsonBody(404, problem(404, 'not found')));
      await expectLater(pay.simulatePaid('p1'),
          throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('giả lập'))));
    });
  });

  group('hạn mức', () {
    test('chưa được cấp (404) → null', () async {
      use((o) => jsonBody(404, problem(404, 'not found')));
      expect(await credit.mine(), isNull);
    });

    test('có hạn mức', () async {
      use((o) => jsonBody(200, {
            'profileId': 'x',
            'farmerProfileId': 'f',
            'status': 'ACTIVE',
            'creditTier': null,
            'creditLimit': 10000000.0,
            'paymentTermDays': 30,
            'outstandingReceivable': 2000000.0,
            'reservedCredit': 0.0,
            'availableCredit': 8000000.0,
          }));
      final c = await credit.mine();
      expect(c!.isActive, isTrue);
      expect(c.availableCredit, 8000000);
      expect(c.paymentTermDays, 30);
    });

    test('lỗi khác vẫn ném ApiException', () async {
      use((o) => jsonBody(500, problem(500, 'x')));
      await expectLater(credit.mine(), throwsA(isA<ApiException>()));
    });
  });

  test('nhãn trạng thái đơn và quyền huỷ/thanh toán', () {
    expect(OrderStatus.label(null), 'Tất cả');
    expect(OrderStatus.label('PENDING_CONFIRMATION'), 'Chờ xác nhận');
    expect(OrderStatus.label('READY_FOR_FULFILLMENT'), 'Sẵn sàng giao/nhận');
    expect(OrderStatus.label('UNKNOWN_X'), 'UNKNOWN_X');
    expect(OrderStatus.canCancel('PENDING_CONFIRMATION'), isTrue);
    expect(OrderStatus.canCancel('CONFIRMED'), isFalse);
    expect(OrderStatus.canPay('CONFIRMED'), isTrue);
    expect(OrderStatus.canPay('COMPLETED'), isFalse);
    expect(OrderStatus.canPay('CANCELLED'), isFalse);
  });
}
