import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/paged.dart';
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

/// The pages loaded so far, and what is happening to the next one.
class ProductListState {
  const ProductListState({required this.page, this.loadingMore = false, this.moreError});

  final Paged<CatalogProductListItem> page;
  final bool loadingMore;
  final AppException? moreError;

  List<CatalogProductListItem> get items => page.items;
  bool get hasMore => page.hasMore;

  ProductListState copyWith({Paged<CatalogProductListItem>? page, bool? loadingMore, AppException? moreError, bool clearError = false}) =>
      ProductListState(
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: clearError ? null : (moreError ?? this.moreError),
      );
}

/// The product list for one search/category query, loaded a page at a time (infinite scroll).
class ProductListController extends AutoDisposeFamilyAsyncNotifier<ProductListState, ProductQuery> {
  static const pageSize = 20;

  @override
  Future<ProductListState> build(ProductQuery arg) async {
    final page = await ref.watch(catalogRepositoryProvider).products(query: arg, pageSize: pageSize);
    return ProductListState(page: page);
  }

  /// Fetches the next page and appends it. A failure keeps what is on screen and is reported in `moreError`.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final next = await ref
          .read(catalogRepositoryProvider)
          .products(query: arg, page: current.page.page + 1, pageSize: pageSize);
      state = AsyncData(ProductListState(page: current.page.append(next)));
    } on AppException catch (error) {
      state = AsyncData(current.copyWith(loadingMore: false, moreError: error));
    }
  }
}

final productListProvider = AsyncNotifierProvider.autoDispose
    .family<ProductListController, ProductListState, ProductQuery>(ProductListController.new);
