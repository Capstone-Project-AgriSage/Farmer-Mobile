import 'dart:async';

import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/features/cart/data/cart_models.dart';
import 'package:farmer_mobile/features/cart/data/cart_repository.dart';
import 'package:farmer_mobile/features/cart/providers/cart_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/cart_fixtures.dart';

class MockCartRepository extends Mock implements CartRepository {}

/// A stand-in for the signed-in user that a test can change.
class TestUserId extends SessionUserId {
  TestUserId(this.initial);
  final String? initial;

  @override
  String? build() => initial;

  void set(String? id) => state = id;
}

void main() {
  late MockCartRepository repo;
  late TestUserId user;
  late ProviderContainer container;

  setUp(() {
    repo = MockCartRepository();
    user = TestUserId('u1');
    container = ProviderContainer(overrides: [
      cartRepositoryProvider.overrideWithValue(repo),
      sessionUserIdProvider.overrideWith(() => user),
    ]);
    addTearDown(container.dispose);
    when(() => repo.get()).thenAnswer((_) async => cartOf([bao25]));
  });

  CartController controller() => container.read(cartProvider.notifier);
  Cart currentCart() => container.read(cartProvider).requireValue.cart;
  Future<void> loaded() async {
    container.listen(cartProvider, (_, __) {});
    await container.read(cartProvider.future);
  }

  test('loads the cart of the signed-in user', () async {
    await loaded();
    expect(currentCart().lineCount, 1);
  });

  test('nobody signed in: an empty cart and no request', () async {
    final signedOut = ProviderContainer(overrides: [
      cartRepositoryProvider.overrideWithValue(repo),
      sessionUserIdProvider.overrideWith(() => TestUserId(null)),
    ]);
    addTearDown(signedOut.dispose);
    signedOut.listen(cartProvider, (_, __) {});

    final state = await signedOut.read(cartProvider.future);

    expect(state.cart.isEmpty, isTrue);
    verifyNever(() => repo.get());
  });

  test('another user signing in starts from that user\'s own cart, not the previous one', () async {
    await loaded();
    expect(currentCart().lineCount, 1);

    when(() => repo.get()).thenAnswer((_) async => const Cart.empty());
    user.set('u2');
    await container.read(cartProvider.future);

    expect(currentCart().isEmpty, isTrue);
  });

  test('a change replaces the cart with the server answer', () async {
    await loaded();
    when(() => repo.updateQuantity('l-bao25', any())).thenAnswer(
      (_) async => cartOf([bao25.copyForTest(quantity: 3)]),
    );

    await controller().setQuantity('l-bao25', 3);

    expect(currentCart().items.single.quantity, 3);
    expect(container.read(cartProvider).requireValue.busy, isFalse);
  });

  test('add sends the product, packaging and quantity', () async {
    await loaded();
    when(() => repo.addItem(
          storeProductId: any(named: 'storeProductId'),
          productPackagingId: any(named: 'productPackagingId'),
          quantity: any(named: 'quantity'),
        )).thenAnswer((_) async => cartOf([bao25, noPriceLine]));

    await controller().add(storeProductId: 'p-huuco', productPackagingId: 'k-bao20', quantity: 1);

    verify(() => repo.addItem(storeProductId: 'p-huuco', productPackagingId: 'k-bao20', quantity: 1)).called(1);
    expect(currentCart().lineCount, 2);
  });

  test('a failed change throws to the caller and leaves the cart as it was', () async {
    await loaded();
    when(() => repo.removeItem(any())).thenThrow(const AppException.offline());

    await expectLater(controller().remove('l-bao25'), throwsA(isA<AppException>()));

    expect(currentCart().lineCount, 1);
    expect(container.read(cartProvider).requireValue.busy, isFalse);
  });

  test('changes run one after another, so two quick taps cannot reach the server out of order', () async {
    await loaded();
    final firstGate = Completer<void>();
    final order = <int>[];
    when(() => repo.updateQuantity('l-bao25', any())).thenAnswer((invocation) async {
      final quantity = invocation.positionalArguments[1] as int;
      order.add(quantity);
      if (quantity == 3) await firstGate.future; // the first request is slow
      return cartOf([bao25.copyForTest(quantity: quantity)]);
    });

    final first = controller().setQuantity('l-bao25', 3);
    final second = controller().setQuantity('l-bao25', 4);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(order, [3], reason: 'the second request waits for the first');
    expect(container.read(cartProvider).requireValue.busy, isTrue);

    firstGate.complete();
    await Future.wait([first, second]);

    expect(order, [3, 4]);
    expect(currentCart().items.single.quantity, 4);
    expect(container.read(cartProvider).requireValue.busy, isFalse);
  });

  test('a failure does not stop the queue', () async {
    await loaded();
    var calls = 0;
    when(() => repo.updateQuantity('l-bao25', any())).thenAnswer((_) async {
      if (calls++ == 0) throw const AppException.offline();
      return cartOf([bao25.copyForTest(quantity: 9)]);
    });

    final failing = controller().setQuantity('l-bao25', 5);
    final next = controller().setQuantity('l-bao25', 9);

    await expectLater(failing, throwsA(isA<AppException>()));
    await next;
    expect(currentCart().items.single.quantity, 9);
  });

  test('clear empties the cart', () async {
    await loaded();
    when(() => repo.clear()).thenAnswer((_) async {});
    await controller().clear();
    expect(currentCart().isEmpty, isTrue);
  });

  test('the badge counts lines and is 0 while loading', () async {
    expect(container.read(cartBadgeCountProvider), 0);
    await loaded();
    expect(container.read(cartBadgeCountProvider), 1);
  });
}

extension on CartLine {
  CartLine copyForTest({required int quantity}) => CartLine(
        id: id,
        storeProductId: storeProductId,
        productPackagingId: productPackagingId,
        sku: sku,
        productName: productName,
        packagingName: packagingName,
        quantity: quantity,
        unitPrice: unitPrice,
        lineTotalAmount: (unitPrice ?? 0) * quantity,
        isAvailable: isAvailable,
      );
}
