import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/paged.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/features/orders/data/delivery_models.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/orders/providers/order_providers.dart';
import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/checkout_fixtures.dart' show orderJson;
import '../../support/order_fixtures.dart';
import '../cart/cart_controller_test.dart' show TestUserId;
import '../checkout/checkout_controller_test.dart' show MockOrderRepository;

void main() {
  late MockOrderRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockOrderRepository();
    container = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(repo),
      sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
    ]);
    addTearDown(container.dispose);
  });

  Order theOrder({String status = 'PENDING_CONFIRMATION'}) => Order.fromJson(orderWith(status: status));

  group('order list', () {
    test('asks the server for the chosen status and pages through it', () async {
      when(() => repo.list(status: 'COMPLETED', page: 1, pageSize: any(named: 'pageSize'))).thenAnswer(
        (_) async => Paged(items: [OrderListItem.fromJson(orderListRow(id: 'a'))], page: 1, pageSize: 1, totalCount: 2),
      );
      when(() => repo.list(status: 'COMPLETED', page: 2, pageSize: any(named: 'pageSize'))).thenAnswer(
        (_) async => Paged(items: [OrderListItem.fromJson(orderListRow(id: 'b'))], page: 2, pageSize: 1, totalCount: 2),
      );
      container.listen(orderListProvider('COMPLETED'), (_, __) {});

      await container.read(orderListProvider('COMPLETED').future);
      await container.read(orderListProvider('COMPLETED').notifier).loadMore();

      expect(container.read(orderListProvider('COMPLETED')).requireValue.items.map((o) => o.id), ['a', 'b']);
    });

    test('"all" sends no status and each status has its own list', () async {
      when(() => repo.list(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => const Paged.empty());
      container.listen(orderListProvider(null), (_, __) {});
      container.listen(orderListProvider('CANCELLED'), (_, __) {});

      await container.read(orderListProvider(null).future);
      await container.read(orderListProvider('CANCELLED').future);

      verify(() => repo.list(status: null, page: 1, pageSize: 20)).called(1);
      verify(() => repo.list(status: 'CANCELLED', page: 1, pageSize: 20)).called(1);
    });
  });

  group('order detail', () {
    void stub({Object? deliveries, Object? payments}) {
      when(() => repo.get('o-1')).thenAnswer((_) async => theOrder());
      when(() => repo.deliveries('o-1')).thenAnswer((_) async {
        if (deliveries is Exception) throw deliveries;
        return (deliveries as List<MyDelivery>?) ?? [];
      });
      when(() => repo.payments('o-1')).thenAnswer((_) async {
        if (payments is Exception) throw payments;
        return (payments as OrderPaymentSummary?) ?? OrderPaymentSummary.fromJson(paymentSummaryJson());
      });
      container.listen(orderDetailProvider('o-1'), (_, __) {});
    }

    test('loads the order with its deliveries and payments', () async {
      stub(deliveries: [MyDelivery.fromJson(retryDeliveryJson)]);
      final d = await container.read(orderDetailProvider('o-1').future);
      expect(d.order.orderNumber, 'ON-20261008-0001');
      expect(d.deliveries, hasLength(1));
      expect(d.payments?.remainingToPay, 1560000);
      expect(d.deliveriesFailed, isFalse);
      expect(d.canPay, isTrue);
    });

    test('the screen still opens when deliveries cannot be read, and says so', () async {
      stub(deliveries: const AppException.offline());
      final d = await container.read(orderDetailProvider('o-1').future);
      expect(d.deliveries, isEmpty);
      expect(d.deliveriesFailed, isTrue);
    });

    test('when payments cannot be read the farmer is not offered a payment', () async {
      stub(payments: const AppException.offline());
      final d = await container.read(orderDetailProvider('o-1').future);
      expect(d.payments, isNull);
      expect(d.canPay, isFalse);
    });

    test('when the order itself cannot be read it is an error', () async {
      when(() => repo.get('o-1')).thenThrow(const AppException(kind: AppErrorKind.notFound, message: 'x', statusCode: 404));
      when(() => repo.deliveries('o-1')).thenAnswer((_) async => []);
      when(() => repo.payments('o-1')).thenAnswer((_) async => OrderPaymentSummary.fromJson(paymentSummaryJson()));
      container.listen(orderDetailProvider('o-1'), (_, __) {});

      await expectLater(container.read(orderDetailProvider('o-1').future), throwsA(isA<AppException>()));
    });
  });

  group('OrderActions', () {
    test('cancelling sends the reason and makes the list and the detail ask again', () async {
      when(() => repo.list(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => const Paged.empty());
      when(() => repo.cancel('o-1', reason: any(named: 'reason'))).thenAnswer((_) async => theOrder(status: 'CANCELLED'));
      container.listen(orderListProvider(null), (_, __) {});
      await container.read(orderListProvider(null).future);

      final cancelled = await container.read(orderActionsProvider).cancel('o-1', reason: 'Đặt nhầm');
      await container.read(orderListProvider(null).future);

      expect(cancelled.status, 'CANCELLED');
      verify(() => repo.cancel('o-1', reason: 'Đặt nhầm')).called(1);
      verify(() => repo.list(status: null, page: 1, pageSize: 20)).called(2); // loaded again after the cancel
    });

    test('a refused cancel (the store confirmed it first) is reported and refreshes nothing', () async {
      when(() => repo.cancel('o-1', reason: any(named: 'reason'))).thenThrow(const AppException(
        kind: AppErrorKind.businessRule,
        message: 'Chỉ hủy được đơn đang chờ cửa hàng xác nhận. Bác vui lòng liên hệ cửa hàng.',
        statusCode: 422,
      ));

      await expectLater(
        container.read(orderActionsProvider).cancel('o-1'),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('liên hệ cửa hàng'))),
      );
    });
  });

  test('the fixture the checkout returns is also a valid order for the detail', () {
    expect(Order.fromJson(orderJson).items, hasLength(1));
  });
}
