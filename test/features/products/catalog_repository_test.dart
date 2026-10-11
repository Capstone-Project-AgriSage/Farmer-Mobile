import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/core/utils/money.dart';
import 'package:farmer_mobile/features/products/data/catalog_models.dart';
import 'package:farmer_mobile/features/products/data/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/catalog_fakes.dart';

void main() {
  late FakeAdapter adapter;
  late CatalogRepository catalog;
  late CartRepository cart;

  void use(FakeHandler h) {
    adapter = FakeAdapter(h);
    final dio = createApiDio(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      onSessionExpired: () async {},
      adapter: adapter,
    );
    catalog = CatalogRepository(dio);
    cart = CartRepository(dio);
  }

  Map<String, dynamic> cartJson(List<Map<String, dynamic>> items,
          {String? id = 'cart1', double subtotal = 0}) =>
      {'id': id, 'items': items, 'subtotalAmount': subtotal, 'priceListId': 'pl'};

  Map<String, dynamic> lineJson(String id,
          {bool available = true, String? reason, double? price = 115000, int qty = 2}) =>
      {
        'id': id,
        'storeProductId': 'p1',
        'productPackagingId': 'bao',
        'sku': 'NPK',
        'productName': 'NPK 16-16-8',
        'packagingName': 'Thùng 10 gói',
        'imageUrl': null,
        'quantity': qty,
        'unitPrice': available ? price : null,
        'lineTotalAmount': available && price != null ? price * qty : null,
        'isAvailable': available,
        'unavailableReason': reason,
      };

  group('formatVnd', () {
    test('nhóm hàng nghìn bằng dấu chấm, làm tròn, có đ', () {
      expect(formatVnd(0), '0đ');
      expect(formatVnd(5500), '5.500đ');
      expect(formatVnd(485000), '485.000đ');
      expect(formatVnd(1319000), '1.319.000đ');
      expect(formatVnd(115000.4), '115.000đ');
      expect(formatVnd(99.6), '100đ');
    });
  });

  group('catalog', () {
    test('danh mục dạng cây', () async {
      use((o) => jsonBody(200, [
            {
              'id': 'c1',
              'code': 'PB',
              'name': 'Phân bón',
              'displayOrder': 1,
              'isActive': true,
              'children': [
                {'id': 'c1a', 'code': 'NPK', 'name': 'NPK', 'displayOrder': 0, 'isActive': true, 'children': []}
              ],
            }
          ]));

      final list = await catalog.categories();

      expect(adapter.requests.single.path, '/api/catalog/categories');
      expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
      expect(list.single.name, 'Phân bón');
      expect(list.single.children.single.name, 'NPK');
    });

    test('danh sách: gửi page/pageSize/categoryId/search (trim), bỏ tham số rỗng', () async {
      use((o) => jsonBody(200, {
            'items': [
              {
                'id': 'p1',
                'sku': 'DEMO',
                'name': 'Lúa ST25',
                'imageUrl': 'https://x/y.webp',
                'categoryId': 'c1',
                'categoryName': 'Giống',
                'brandName': null,
                'fromPrice': 32000.00,
              },
              {
                'id': 'p2',
                'sku': 'HC',
                'name': 'Hữu cơ',
                'imageUrl': null,
                'categoryId': 'c1',
                'categoryName': 'Phân bón',
                'brandName': 'Bình Điền',
                'fromPrice': null,
              },
            ],
            'page': 2,
            'pageSize': 20,
            'totalCount': 22,
            'totalPages': 2,
          }));

      final page = await catalog.products(page: 2, categoryId: 'c1', search: '  lúa ');
      await catalog.products();

      expect(adapter.requests[0].queryParameters,
          {'page': 2, 'pageSize': 20, 'categoryId': 'c1', 'search': 'lúa'});
      expect(adapter.requests[1].queryParameters, {'page': 1, 'pageSize': 20});
      expect(page.items.first.fromPrice, 32000);
      expect(page.items.first.imageUrl, 'https://x/y.webp');
      expect(page.items[1].fromPrice, isNull);
      expect(page.items[1].brandName, 'Bình Điền');
      expect(page.hasMore, isFalse);
    });

    test('từ khoá quá 100 ký tự bị cắt (backend từ chối > 100)', () async {
      use((o) => jsonBody(200, {'items': [], 'page': 1, 'pageSize': 20, 'totalCount': 0, 'totalPages': 0}));
      await catalog.products(search: 'a' * 150);
      expect((adapter.requests.single.queryParameters['search'] as String).length, 100);
    });

    test('chi tiết: quy cách, đơn vị cơ sở, quy cách đặt được (rẻ trước), hoạt chất', () async {
      use((o) => jsonBody(200, detailJson(
            packagings: [
              {'id': 'thung', 'unitName': 'Thùng', 'symbol': null, 'packagingName': 'Thùng 10 chai', 'conversionToBase': 10, 'isBaseUnit': false, 'price': 1500000.0},
              {'id': 'chai', 'unitName': 'Chai', 'symbol': 'chai', 'packagingName': null, 'conversionToBase': 1, 'isBaseUnit': true, 'price': 165000.0},
              {'id': 'loc', 'unitName': 'Lốc', 'symbol': null, 'packagingName': 'Lốc 6', 'conversionToBase': 6, 'isBaseUnit': false, 'price': null},
            ],
            ingredients: [
              {'name': 'Difenoconazole', 'concentration': '150 g/L'},
            ],
          )));

      final d = await catalog.product('p1');

      expect(adapter.requests.single.path, '/api/catalog/products/p1');
      expect(d.purchasable.map((p) => p.id), ['chai', 'thung']);
      expect(d.baseUnit?.id, 'chai');
      expect(d.packagings.firstWhere((p) => p.id == 'chai').label, 'Chai');
      expect(d.packagings.firstWhere((p) => p.id == 'thung').label, 'Thùng 10 chai');
      expect(d.packagings.firstWhere((p) => p.id == 'loc').isPurchasable, isFalse);
      expect(d.ingredients.single.concentration, '150 g/L');
    });

    test('sản phẩm không còn bán (404) → thông báo tiếng Việt', () async {
      use((o) => jsonBody(404, problem(404, 'Product not found')));
      await expectLater(
        catalog.product('x'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'k', ApiErrorKind.notFound)
            .having((e) => e.message, 'm', contains('không còn được bán'))),
      );
    });
  });

  group('giỏ hàng', () {
    test('giỏ chưa có (id null) → rỗng', () async {
      use((o) => jsonBody(200, cartJson([], id: null)));
      final c = await cart.get();
      expect(adapter.requests.single.path, '/api/me/cart');
      expect(c.isEmpty, isTrue);
      expect(c.id, isNull);
      expect(c.canCheckout, isFalse);
    });

    test('dòng không bán được: cờ, lý do, không tính tiền, chặn đặt hàng', () async {
      use((o) => jsonBody(200, cartJson([
            lineJson('a'),
            lineJson('b', available: false, reason: 'NO_PRICE'),
          ], subtotal: 230000)));

      final c = await cart.get();

      expect(c.subtotal, 230000);
      expect(c.lines[0].lineTotal, 230000);
      expect(c.lines[1].unitPrice, isNull);
      expect(c.lines[1].unavailableReason, 'NO_PRICE');
      expect(c.hasUnavailable, isTrue);
      expect(c.canCheckout, isFalse);
      expect(CartUnavailableReason.label('NO_PRICE'), 'Chưa có giá');
      expect(CartUnavailableReason.label('NOT_SELLABLE'), 'Sản phẩm ngừng bán');
    });

    test('thêm: POST items với đúng tên trường', () async {
      use((o) => jsonBody(200, cartJson([lineJson('a')])));
      await cart.add(storeProductId: 'p1', packagingId: 'bao', quantity: 3);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/me/cart/items');
      expect(adapter.requests.single.data,
          {'storeProductId': 'p1', 'productPackagingId': 'bao', 'quantity': 3});
    });

    test('thêm quy cách không bán (422) → thông báo tiếng Việt', () async {
      use((o) => jsonBody(422, problem(422, 'Only ACTIVE sale packagings can be ordered.')));
      await expectLater(
        cart.add(storeProductId: 'p1', packagingId: 'kg', quantity: 1),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'm', contains('không thể đặt mua'))),
      );
    });

    test('đổi số lượng: PUT items/{id} {quantity}; 404 → thông báo đã tải lại', () async {
      use((o) => o.method == 'PUT' && o.path.endsWith('/gone')
          ? jsonBody(404, problem(404, 'Cart item not found'))
          : jsonBody(200, cartJson([lineJson('a', qty: 5)])));

      final c = await cart.setQuantity('a', 5);
      expect(adapter.requests.last.data, {'quantity': 5});
      expect(adapter.requests.last.path, '/api/me/cart/items/a');
      expect(c.lines.single.quantity, 5);

      await expectLater(
        cart.setQuantity('gone', 2),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'm', contains('không còn trong giỏ'))),
      );
    });

    test('xoá dòng: DELETE items/{id} trả giỏ mới; xoá cả giỏ: DELETE /api/me/cart', () async {
      use((o) => o.path == '/api/me/cart'
          ? emptyBody(204)
          : jsonBody(200, cartJson([], id: 'cart1')));

      final c = await cart.remove('a');
      await cart.clear();

      expect(adapter.requests[0].method, 'DELETE');
      expect(adapter.requests[0].path, '/api/me/cart/items/a');
      expect(c.isEmpty, isTrue);
      expect(adapter.requests[1].method, 'DELETE');
      expect(adapter.requests[1].path, '/api/me/cart');
    });
  });
}
