import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/labels/order_labels.dart';
import 'package:farmer_mobile/core/labels/status_label.dart';
import 'package:farmer_mobile/features/orders/data/delivery_models.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/orders/providers/order_providers.dart';
import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../support/checkout_fixtures.dart' show orderJson;
import '../../support/order_fixtures.dart';

OrderDetail detail({String status = 'PENDING_CONFIRMATION', String settlement = 'FULL_PAYMENT', double? remaining = 1560000}) => OrderDetail(
      order: Order.fromJson(orderWith(status: status, settlement: settlement)),
      deliveries: const [],
      payments: remaining == null ? null : OrderPaymentSummary.fromJson(paymentSummaryJson(remaining: remaining)),
    );

void main() {
  group('models', () {
    test('an order list row reads its summary', () {
      final row = OrderListItem.fromJson(orderListRow(status: 'COMPLETED', settlement: 'CREDIT'));
      expect(row.orderNumber, 'OD-20261008-0002');
      expect(row.isCredit, isTrue);
      expect(row.itemCount, 1);
      expect(row.createdAt, DateTime.utc(2026, 10, 8, 9, 10));
    });

    test('a payment summary hides cancelled attempts but keeps paid ones and the refunds', () {
      final s = OrderPaymentSummary.fromJson(paymentSummaryJson(
        paid: 780000,
        remaining: 780000,
        payments: [paidPaymentJson, cancelledPaymentJson],
        refunds: [
          {'id': 'r1', 'refundNumber': 'RF-1', 'amount': 100000.0, 'status': 'COMPLETED'},
        ],
      ));
      expect(s.payments, hasLength(2));
      expect(s.visiblePayments.map((p) => p.paymentNumber), ['PM-20261008-0002']);
      expect(s.refunds.single.isCompleted, isTrue);
      expect(s.visiblePayments.single.when, DateTime.utc(2026, 10, 8, 9, 30), reason: 'when it was paid, not when it started');
    });

    test('a delivery says why its last failed attempt failed and who carries it', () {
      final d = MyDelivery.fromJson(retryDeliveryJson);
      expect(d.isRetryPending, isTrue);
      expect(d.lastFailureReason, 'CUSTOMER_ABSENT');
      expect(d.assignedTo?.phoneNumber, '0987654321');
      expect(d.items.single.deliveredQuantity, 1);
      expect(d.displayDate, DateTime.utc(2026, 10, 9, 1), reason: 'not dispatched yet, so the planned date');
      expect(d.attempts.first.receiverName, 'Chị Hai');
    });

    test('a delivery with no staff or attempts still reads', () {
      final d = MyDelivery.fromJson({'id': 'd', 'deliveryNumber': 'DL', 'status': 'ASSIGNED', 'assignedTo': null, 'items': [], 'attempts': []});
      expect(d.assignedTo, isNull);
      expect(d.lastFailureReason, isNull);
    });
  });

  group('what can be done with an order', () {
    test('only an order waiting for the store can be cancelled', () {
      expect(detail(status: 'PENDING_CONFIRMATION').canCancel, isTrue);
      for (final status in ['CONFIRMED', 'PREPARING', 'COMPLETED', 'CANCELLED']) {
        expect(detail(status: status).canCancel, isFalse, reason: status);
      }
    });

    test('payOS is offered while money is owed on a live order that is not on credit', () {
      expect(detail().canPay, isTrue);
      expect(detail(remaining: 0).canPay, isFalse, reason: 'nothing left to pay');
      expect(detail(settlement: 'CREDIT').canPay, isFalse, reason: 'a credit order goes to the debt book');
      expect(detail(status: 'CANCELLED').canPay, isFalse);
      expect(detail(status: 'PARTIALLY_CANCELLED').canPay, isFalse);
      expect(detail(remaining: null).canPay, isFalse, reason: 'unknown payment state: do not offer to pay');
    });
  });

  group('labels', () {
    test('an order and a delivery have their Vietnamese words', () {
      expect(labelOf(orderStatusLabels, 'PENDING_CONFIRMATION').label, 'Chờ xác nhận');
      expect(labelOf(orderStatusLabels, 'COMPLETED').tone, LabelTone.success);
      expect(labelOf(deliveryStatusLabels, 'RETRY_PENDING').label, 'Chờ giao lại');
      expect(labelOf(paymentStatusLabels, 'PAID').label, 'Đã thanh toán');
      expect(failureReasonLabel('CUSTOMER_ABSENT'), 'Khách vắng nhà');
      expect(settlementLabel('CREDIT'), 'Mua ghi nợ');
    });

    test('a status the app has never heard of shows as itself, not as a crash', () {
      final label = labelOf(orderStatusLabels, 'SOMETHING_NEW');
      expect(label.label, 'SOMETHING_NEW');
      expect(label.tone, LabelTone.neutral);
      expect(labelOf(orderStatusLabels, null).label, '—');
      expect(failureReasonLabel('NEW_REASON'), 'NEW_REASON');
    });
  });

  group('OrderRepository', () {
    late DioAdapter adapter;
    late OrderRepository repo;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      adapter = DioAdapter(dio: dio);
      repo = OrderRepository(dio);
    });

    test('the list asks for a status, a page and a size', () async {
      adapter.onGet(
        '/api/me/orders',
        (server) => server.reply(200, pageOf([orderListRow()], page: 2, total: 21)),
        queryParameters: {'status': 'PENDING_CONFIRMATION', 'page': 2, 'pageSize': 20},
      );
      final page = await repo.list(status: 'PENDING_CONFIRMATION', page: 2);
      expect(page.items.single.orderNumber, 'OD-20261008-0002');
      expect(page.page, 2);
    });

    test('the list for "all" sends no status', () async {
      adapter.onGet('/api/me/orders', (server) => server.reply(200, pageOf([])), queryParameters: {'page': 1, 'pageSize': 20});
      expect((await repo.list()).items, isEmpty);
    });

    test('one order, its payments and its deliveries', () async {
      adapter.onGet('/api/me/orders/o-1', (server) => server.reply(200, orderJson));
      adapter.onGet('/api/me/orders/o-1/payments', (server) => server.reply(200, paymentSummaryJson()));
      adapter.onGet('/api/me/orders/o-1/deliveries', (server) => server.reply(200, [retryDeliveryJson]));

      expect((await repo.get('o-1')).items, hasLength(1));
      expect((await repo.payments('o-1')).remainingToPay, 1560000);
      expect((await repo.deliveries('o-1')).single.deliveryNumber, 'DL-20261008-0001');
    });

    test('cancelling sends the reason, or null when there is none', () async {
      adapter.onPost('/api/me/orders/o-1/cancel', (server) => server.reply(200, orderWith(status: 'CANCELLED')),
          data: {'reason': 'Đặt nhầm'});
      adapter.onPost('/api/me/orders/o-2/cancel', (server) => server.reply(200, orderWith(status: 'CANCELLED')),
          data: {'reason': null});

      expect((await repo.cancel('o-1', reason: '  Đặt nhầm ')).status, 'CANCELLED');
      expect((await repo.cancel('o-2', reason: '   ')).status, 'CANCELLED');
    });
  });
}
