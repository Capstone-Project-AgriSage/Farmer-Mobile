import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/features/catalog/data/catalog_models.dart';
import 'package:farmer_mobile/features/catalog/data/catalog_repository.dart';
import 'package:farmer_mobile/features/products/screens/product_detail_screen.dart';
import 'package:farmer_mobile/features/products/screens/product_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/catalog_fixtures.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

void main() {
  late MockCatalogRepository repo;

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  setUp(() {
    repo = MockCatalogRepository();
    when(() => repo.categories()).thenAnswer(
      (_) async => const [
        CatalogCategory(id: 'c-giong', name: 'Giống cây trồng', displayOrder: 1, isActive: true, children: []),
        CatalogCategory(id: 'c-phan', name: 'Phân bón', displayOrder: 2, isActive: true, children: []),
      ],
    );
    when(() => repo.products(query: any(named: 'query'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .thenAnswer((_) async => page([priced, unpriced]));
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) => tester.pumpWidget(
        ProviderScope(
          overrides: [catalogRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: home),
        ),
      );

  group('product list', () {
    testWidgets('shows real products with their price, or "Chưa có giá"', (tester) async {
      await pumpApp(tester, const ProductListScreen());
      await tester.pumpAndSettle();

      expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
      expect(find.text('Từ 32.000 ₫'), findsOneWidget);
      expect(find.text('Đang bán'), findsOneWidget);
      expect(find.text('Chưa có giá'), findsOneWidget);
      expect(find.text('Liên hệ cửa hàng'), findsOneWidget);
      // The categories come from the server, after the "Tất cả" chip.
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Phân bón'), findsWidgets); // the chip, and the caption of the second card
    });

    testWidgets('searches only after the farmer stops typing', (tester) async {
      await pumpApp(tester, const ProductListScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'lúa');
      await tester.pump(const Duration(milliseconds: 200));
      verifyNever(() => repo.products(query: const ProductQuery(search: 'lúa'), page: 1, pageSize: 20));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      verify(() => repo.products(query: const ProductQuery(search: 'lúa'), page: 1, pageSize: 20)).called(1);
    });

    testWidgets('tapping a category filters by it', (tester) async {
      await pumpApp(tester, const ProductListScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Phân bón').first); // the chip comes before the cards
      await tester.pumpAndSettle();

      verify(() => repo.products(query: const ProductQuery(categoryId: 'c-phan'), page: 1, pageSize: 20)).called(1);
    });

    testWidgets('an empty search offers to clear the filters', (tester) async {
      when(() => repo.products(query: any(named: 'query'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => page([]));
      await pumpApp(tester, const ProductListScreen());
      await tester.pumpAndSettle();
      expect(find.text('Cửa hàng chưa có sản phẩm nào'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'khong co');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy sản phẩm phù hợp'), findsOneWidget);
      expect(find.text('Xóa bộ lọc'), findsOneWidget);
    });

    testWidgets('a failure shows the message and a retry that works', (tester) async {
      var fail = true;
      when(() => repo.products(query: any(named: 'query'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async {
        if (fail) throw const AppException.offline();
        return page([priced]);
      });
      await pumpApp(tester, const ProductListScreen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Lúa giống ST25 (bao 25 kg)'), findsOneWidget);
    });
  });

  group('product detail', () {
    void stubProduct(Map<String, dynamic> json) =>
        when(() => repo.product(any())).thenAnswer((_) async => CatalogProduct.fromJson(json));

    testWidgets('opens on the largest pack and switches the price when another pack is chosen', (tester) async {
      stubProduct(stProduct);
      await pumpApp(tester, const ProductDetailScreen(productId: 'p-st25'));
      await tester.pumpAndSettle();

      expect(find.text('780.000 ₫'), findsWidgets); // price block and chip
      expect(find.text('/ Bao 25 kg'), findsOneWidget);
      expect(find.text('Thêm vào giỏ'), findsOneWidget);

      await tester.tap(find.text('Kilogram'));
      await tester.pumpAndSettle();
      expect(find.text('/ Kilogram'), findsOneWidget);
    });

    testWidgets('shows what the server gave and nothing it did not', (tester) async {
      stubProduct(stProduct);
      await pumpApp(tester, const ProductDetailScreen(productId: 'p-st25'));
      await tester.pumpAndSettle();

      expect(find.text('Lúa giống xác nhận ST25, tỷ lệ nảy mầm trên 85%.'), findsOneWidget);
      expect(find.text('Gieo sạ 80-100 kg/ha.'), findsOneWidget);
      expect(find.text('Mã SKU'), findsOneWidget);
      expect(find.text('Thương hiệu'), findsNothing); // the product has no brand: no row, no invented one
      expect(find.text('Đánh giá từ người dùng'), findsNothing);
    });

    testWidgets('a product with no price cannot be added to the cart', (tester) async {
      stubProduct(unpricedProduct);
      await pumpApp(tester, const ProductDetailScreen(productId: 'p-huuco'));
      await tester.pumpAndSettle();

      expect(find.textContaining('chưa có giá bán online'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.text('Hoạt chất: Hữu cơ 45%'), findsOneWidget);
    });

    testWidgets('a product that is gone shows the error and a retry', (tester) async {
      when(() => repo.product(any())).thenThrow(const AppException(
        kind: AppErrorKind.notFound,
        message: 'Không tìm thấy dữ liệu yêu cầu.',
        statusCode: 404,
      ));
      await pumpApp(tester, const ProductDetailScreen(productId: 'gone'));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy dữ liệu yêu cầu.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
