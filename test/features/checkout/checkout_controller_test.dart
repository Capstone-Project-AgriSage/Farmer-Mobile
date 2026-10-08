import 'dart:async';

import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/features/cart/data/cart_repository.dart';
import 'package:farmer_mobile/features/cart/providers/cart_providers.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/orders/providers/checkout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/cart_fixtures.dart';
import '../../support/checkout_fixtures.dart';
import '../cart/cart_controller_test.dart' show MockCartRepository, TestUserId;

class MockOrderRepository extends Mock implements OrderRepository {}

void main() {
  late MockOrderRepository orders;
  late MockCartRepository carts;
  late ProviderContainer container;

  const input = CheckoutInput(settlementType: SettlementType.fullPayment, addressId: 'a-home');

  setUpAll(() => registerFallbackValue(input));

  setUp(() {
    orders = MockOrderRepository();
    carts = MockCartRepository();
    container = ProviderContainer(overrides: [
      orderRepositoryProvider.overrideWithValue(orders),
      cartRepositoryProvider.overrideWithValue(carts),
      sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
    ]);
    addTearDown(container.dispose);
    when(() => carts.get()).thenAnswer((_) async => cartOf([bao25]));
    container.listen(cartProvider, (_, __) {});
  });

  Order theOrder() => Order.fromJson(orderJson);

  test('a placed order is returned and the cart shows as emptied without asking the server again', () async {
    await container.read(cartProvider.future);
    when(() => orders.checkout(any())).thenAnswer((_) async => theOrder());

    final order = await container.read(checkoutProvider.notifier).place(input);

    expect(order?.orderNumber, 'ON-20261008-0001');
    expect(container.read(cartProvider).requireValue.cart.isEmpty, isTrue);
    verify(() => carts.get()).called(1); // only the first load
  });

  test('a refusal returns null, keeps the reason, and leaves the cart alone', () async {
    await container.read(cartProvider.future);
    when(() => orders.checkout(any())).thenThrow(const AppException(
      kind: AppErrorKind.businessRule,
      message: 'Hạn mức ghi nợ còn lại chưa đủ cho đơn này.',
      statusCode: 422,
    ));

    final order = await container.read(checkoutProvider.notifier).place(input);

    expect(order, isNull);
    expect(messageOf(container.read(checkoutProvider).error!), 'Hạn mức ghi nợ còn lại chưa đủ cho đơn này.');
    expect(container.read(cartProvider).requireValue.cart.lineCount, 1);
  });

  test('a timeout is not retried, and the cart is checked again because the order may exist', () async {
    await container.read(cartProvider.future);
    when(() => orders.checkout(any())).thenThrow(const AppException.timeout());
    when(() => carts.get()).thenAnswer((_) async => cartOf([])); // the server did create the order and emptied the cart

    await container.read(checkoutProvider.notifier).place(input);
    await container.read(cartProvider.future);

    verify(() => orders.checkout(any())).called(1); // exactly one attempt
    expect((container.read(checkoutProvider).error as AppException).outcomeUnknown, isTrue);
    expect(container.read(cartProvider).requireValue.cart.isEmpty, isTrue);
  });

  test('tapping twice sends one order', () async {
    await container.read(cartProvider.future);
    final gate = Completer<Order>();
    when(() => orders.checkout(any())).thenAnswer((_) => gate.future);

    final notifier = container.read(checkoutProvider.notifier);
    final first = notifier.place(input);
    final second = await notifier.place(input);
    gate.complete(theOrder());
    await first;

    expect(second, isNull);
    verify(() => orders.checkout(any())).called(1);
  });
}
