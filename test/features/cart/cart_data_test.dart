import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/features/cart/data/cart_models.dart';
import 'package:farmer_mobile/features/cart/data/cart_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../support/cart_fixtures.dart';

void main() {
  group('Cart model', () {
    test('reads the server answer, including a line that cannot be bought', () {
      final cart = Cart.fromJson(cartJson);
      expect(cart.lineCount, 2);
      expect(cart.subtotalAmount, 1560000);
      expect(cart.items.first.unitPrice, 780000);
      expect(cart.items.last.unitPrice, isNull);
      expect(cart.items.last.unavailableReason, 'NO_PRICE');
    });

    test('checkout is allowed only when the cart has lines and all can be bought', () {
      expect(const Cart.empty().canCheckout, isFalse);
      expect(cartOf([bao25]).canCheckout, isTrue);
      expect(cartOf([bao25, noPriceLine]).canCheckout, isFalse);
      expect(cartOf([bao25, noPriceLine]).hasUnavailableItem, isTrue);
    });

    test('each unavailable reason has its own Vietnamese text', () {
      expect(unavailableReasonLabel('NOT_SELLABLE'), contains('ngừng bán'));
      expect(unavailableReasonLabel('NO_PRICE'), contains('chưa có giá'));
      expect(unavailableReasonLabel('SOMETHING_NEW'), contains('không mua được'));
    });

    test('an empty cart answer (no id yet) is an empty cart', () {
      final cart = Cart.fromJson({'id': null, 'items': [], 'subtotalAmount': 0, 'priceListId': null});
      expect(cart.isEmpty, isTrue);
      expect(cart.id, isNull);
    });
  });

  group('CartRepository', () {
    late Dio dio;
    late DioAdapter adapter;
    late CartRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      adapter = DioAdapter(dio: dio);
      repo = CartRepository(dio);
    });

    test('get reads the cart', () async {
      adapter.onGet('/api/me/cart', (server) => server.reply(200, cartJson));
      expect((await repo.get()).lineCount, 2);
    });

    test('addItem posts the product, packaging and quantity', () async {
      adapter.onPost(
        '/api/me/cart/items',
        (server) => server.reply(200, cartJson),
        data: {'storeProductId': 'p-st25', 'productPackagingId': 'k-bao', 'quantity': 3},
      );
      final cart = await repo.addItem(storeProductId: 'p-st25', productPackagingId: 'k-bao', quantity: 3);
      expect(cart.lineCount, 2);
    });

    test('updateQuantity puts the new quantity on the line', () async {
      adapter.onPut('/api/me/cart/items/l-bao25', (server) => server.reply(200, cartJson), data: {'quantity': 5});
      await repo.updateQuantity('l-bao25', 5);
    });

    test('removeItem deletes the line and returns the cart without it', () async {
      adapter.onDelete('/api/me/cart/items/l-bao25', (server) => server.reply(200, {'id': 'cart-1', 'items': [], 'subtotalAmount': 0}));
      expect((await repo.removeItem('l-bao25')).isEmpty, isTrue);
    });

    test('clear deletes the whole cart (204)', () async {
      adapter.onDelete('/api/me/cart', (server) => server.reply(204, null));
      await repo.clear();
    });

    test('a business error comes back translated', () async {
      adapter.onPost(
        '/api/me/cart/items',
        (server) => server.reply(422, {'detail': 'A cart line can hold at most 100000000 units.'}),
        data: Matchers.any,
      );
      await expectLater(
        repo.addItem(storeProductId: 'p', productPackagingId: 'k', quantity: 1),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.businessRule)),
      );
    });
  });
}
