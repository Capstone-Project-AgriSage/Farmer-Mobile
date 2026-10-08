import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/paged.dart';
import '../../../core/network/paged_list.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

final categoriesProvider = FutureProvider<List<CatalogCategory>>(
  (ref) => ref.watch(catalogRepositoryProvider).categories(),
);

final productDetailProvider = FutureProvider.autoDispose.family<CatalogProduct, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).product(id),
);

/// Other products of the same category, for the "Sản phẩm liên quan" strip.
final relatedProductsProvider = FutureProvider.autoDispose
    .family<List<CatalogProductListItem>, ({String categoryId, String excludeId})>((ref, args) async {
  final page = await ref.watch(catalogRepositoryProvider).products(
        query: ProductQuery(categoryId: args.categoryId),
        pageSize: 9,
      );
  return page.items.where((p) => p.id != args.excludeId).take(8).toList(growable: false);
});

typedef ProductListState = PagedListState<CatalogProductListItem>;

/// The product list for one search/category query, loaded a page at a time (infinite scroll).
class ProductListController extends PagedListNotifier<CatalogProductListItem, ProductQuery> {
  @override
  Future<Paged<CatalogProductListItem>> fetchPage(ProductQuery arg, int page) =>
      ref.read(catalogRepositoryProvider).products(query: arg, page: page, pageSize: PagedListNotifier.pageSize);
}

final productListProvider = AsyncNotifierProvider.autoDispose
    .family<ProductListController, ProductListState, ProductQuery>(ProductListController.new);
