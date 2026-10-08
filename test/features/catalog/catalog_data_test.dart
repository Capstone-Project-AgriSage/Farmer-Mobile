import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/features/catalog/data/catalog_models.dart';
import 'package:farmer_mobile/features/catalog/data/catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  group('models', () {
    test('a list row reads a price given as a whole number or a decimal', () {
      final item = CatalogProductListItem.fromJson({
        'id': 'x',
        'name': 'n',
        'categoryId': 'c',
        'fromPrice': 32000,
        'imageUrl': null,
        'brandName': null,
      });
      expect(item.fromPrice, 32000.0);
      expect(item.hasPrice, isTrue);
      expect(item.imageUrl, isNull);
    });

    test('a product without a price is not sellable', () {
      final product = CatalogProduct.fromJson(unpricedProduct);
      expect(product.isSellable, isFalse);
      expect(product.sellablePackagings, isEmpty);
      expect(product.ingredientsText, 'Hữu cơ 45%');
    });

    test('sellable packagings are only the priced ones, the largest pack first', () {
      final product = CatalogProduct.fromJson(stProduct);
      expect(product.sellablePackagings.map((p) => p.id), ['k-bao', 'k-kg']);
    });

    test('a packaging is named by its packaging name, else its unit, else its symbol', () {
      CatalogPackaging make({String? packaging, String? unit, String? symbol}) => CatalogPackaging(
            id: 'p',
            conversionToBase: 1,
            isBaseUnit: false,
            packagingName: packaging,
            unitName: unit,
            symbol: symbol,
          );
      expect(make(packaging: 'Bao 25 kg', unit: 'Bao').label, 'Bao 25 kg');
      expect(make(unit: 'Kilogram', symbol: 'kg').label, 'Kilogram');
      expect(make(symbol: 'kg').label, 'kg');
      expect(make().label, 'Đơn vị lẻ');
    });
  });

  group('CatalogRepository', () {
    late Dio dio;
    late DioAdapter adapter;
    late CatalogRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      adapter = DioAdapter(dio: dio);
      repo = CatalogRepository(dio);
    });

    test('products sends the search, category and paging the API expects', () async {
      adapter.onGet(
        '/api/catalog/products',
        (server) => server.reply(200, {
          'items': [
            {'id': 'p1', 'name': 'Lúa', 'categoryId': 'c1', 'fromPrice': 1000},
          ],
          'page': 2,
          'pageSize': 20,
          'totalCount': 21,
          'totalPages': 2,
        }),
        queryParameters: {'CategoryId': 'c1', 'Search': 'lúa', 'Page': 2, 'PageSize': 20},
      );

      final page = await repo.products(query: const ProductQuery(search: ' lúa ', categoryId: 'c1'), page: 2);

      expect(page.items.single.name, 'Lúa');
      expect(page.page, 2);
      expect(page.hasMore, isFalse);
    });

    test('products leaves out an empty search and category', () async {
      adapter.onGet(
        '/api/catalog/products',
        (server) => server.reply(200, {'items': [], 'page': 1, 'pageSize': 20, 'totalCount': 0}),
        queryParameters: {'Page': 1, 'PageSize': 20},
      );
      final page = await repo.products();
      expect(page.items, isEmpty);
    });

    test('categories drops inactive ones and sorts by display order', () async {
      adapter.onGet(
        '/api/catalog/categories',
        (server) => server.reply(200, [
          {'id': 'b', 'name': 'B', 'displayOrder': 2, 'isActive': true, 'children': []},
          {'id': 'x', 'name': 'Hidden', 'displayOrder': 0, 'isActive': false, 'children': []},
          {'id': 'a', 'name': 'A', 'displayOrder': 1, 'isActive': true, 'children': []},
        ]),
      );
      final list = await repo.categories();
      expect(list.map((c) => c.id), ['a', 'b']);
    });

    test('product reads one product by id', () async {
      adapter.onGet('/api/catalog/products/p-st25', (server) => server.reply(200, stProduct));
      final product = await repo.product('p-st25');
      expect(product.packagings, hasLength(2));
      expect(product.usageInstructions, 'Gieo sạ 80-100 kg/ha.');
    });

    test('a missing product is reported in Vietnamese', () async {
      adapter.onGet(
        '/api/catalog/products/nope',
        (server) => server.reply(404, {'detail': "Product 'nope' was not found."}),
      );
      await expectLater(
        repo.product('nope'),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.notFound)),
      );
    });
  });
}
