import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';

/// Danh mục gốc (lọc theo danh mục cha đã gồm danh mục con).
final categoriesProvider = FutureProvider<List<CategoryNode>>(
    (ref) => ref.watch(catalogRepositoryProvider).categories());

final productDetailProvider =
    FutureProvider.autoDispose.family<ProductDetail, String>(
        (ref, id) => ref.watch(catalogRepositoryProvider).product(id));

/// Sản phẩm cùng danh mục (bỏ chính nó), tối đa 6.
final relatedProductsProvider = FutureProvider.autoDispose
    .family<List<CatalogProduct>, ({String categoryId, String excludeId})>(
        (ref, key) async {
  final page = await ref
      .watch(catalogRepositoryProvider)
      .products(categoryId: key.categoryId, pageSize: 7);
  return page.items.where((p) => p.id != key.excludeId).take(6).toList();
});

class ProductListState {
  const ProductListState({
    this.search = '',
    this.categoryId,
    this.items = const [],
    this.page = 0,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final String search;
  final String? categoryId;
  final List<CatalogProduct> items;
  final int page;
  final int totalCount;
  final bool hasMore;

  /// Đang tải trang đầu (đổi bộ lọc / lần đầu).
  final bool isLoading;
  final bool isLoadingMore;

  /// Lỗi trang đầu → hiện màn lỗi. Lỗi trang sau → hiện dòng "thử lại" cuối danh sách.
  final Object? error;
  final Object? loadMoreError;

  ProductListState copyWith({
    String? search,
    String? Function()? categoryId,
    List<CatalogProduct>? items,
    int? page,
    int? totalCount,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) =>
      ProductListState(
        search: search ?? this.search,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        items: items ?? this.items,
        page: page ?? this.page,
        totalCount: totalCount ?? this.totalCount,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error != null ? error() : this.error,
        loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
      );
}

/// Danh sách sản phẩm: tìm kiếm, lọc danh mục, cuộn vô hạn. Phản hồi cũ (của
/// bộ lọc trước) bị bỏ qua để danh sách không bị lẫn khi gõ nhanh.
class ProductListController extends Notifier<ProductListState> {
  int _generation = 0;

  CatalogRepository get _repo => ref.read(catalogRepositoryProvider);

  @override
  ProductListState build() {
    Future.microtask(_loadFirst);
    return const ProductListState(isLoading: true);
  }

  Future<void> _loadFirst() async {
    final gen = ++_generation;
    state = state.copyWith(
        isLoading: true, isLoadingMore: false, error: () => null, loadMoreError: () => null);
    try {
      final page = await _repo.products(
          page: 1, categoryId: state.categoryId, search: state.search);
      if (gen != _generation) return;
      state = state.copyWith(
        items: page.items,
        page: 1,
        totalCount: page.totalCount,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoading: false, error: () => e, items: const []);
    }
  }

  /// Đổi từ khoá (UI tự debounce). Không đổi thì không gọi lại.
  Future<void> setSearch(String value) {
    final term = value.trim();
    if (term == state.search) return Future.value();
    state = state.copyWith(search: term);
    return _loadFirst();
  }

  Future<void> setCategory(String? categoryId) {
    if (categoryId == state.categoryId) return Future.value();
    state = state.copyWith(categoryId: () => categoryId);
    return _loadFirst();
  }

  Future<void> refresh() => _loadFirst();

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final gen = _generation;
    state = state.copyWith(isLoadingMore: true, loadMoreError: () => null);
    try {
      final next = await _repo.products(
          page: state.page + 1, categoryId: state.categoryId, search: state.search);
      if (gen != _generation) return;
      // Bỏ trùng phòng khi dữ liệu thay đổi giữa hai trang.
      final seen = state.items.map((p) => p.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...next.items.where((p) => !seen.contains(p.id))],
        page: next.page,
        totalCount: next.totalCount,
        hasMore: next.hasMore,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: () => e);
    }
  }
}

final productListProvider =
    NotifierProvider<ProductListController, ProductListState>(
        ProductListController.new);

/// Giỏ hàng của người đang đăng nhập. Server là nguồn sự thật: mọi thao tác
/// thay state bằng giỏ server trả về (giá, tổng tiền đều do server tính).
class CartNotifier extends AsyncNotifier<Cart> {
  CartRepository get _repo => ref.read(cartRepositoryProvider);

  @override
  Future<Cart> build() async {
    final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    if (userId == null) return Cart.empty;
    return _repo.get();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<Cart>().copyWithPrevious(state);
    state = await AsyncValue.guard(_repo.get);
  }

  Future<void> _apply(Future<Cart> Function() call) async {
    try {
      state = AsyncData(await call());
    } on ApiException catch (e) {
      // Dòng đã bị xoá/đặt hàng ở thiết bị khác: đồng bộ lại rồi báo lỗi.
      if (e.kind == ApiErrorKind.notFound) {
        state = await AsyncValue.guard(_repo.get);
      }
      rethrow;
    }
  }

  Future<void> add({
    required String storeProductId,
    required String packagingId,
    required int quantity,
  }) =>
      _apply(() => _repo.add(
          storeProductId: storeProductId,
          packagingId: packagingId,
          quantity: quantity));

  Future<void> setQuantity(String itemId, int quantity) =>
      _apply(() => _repo.setQuantity(itemId, quantity));

  Future<void> remove(String itemId) => _apply(() => _repo.remove(itemId));

  Future<void> clear() async {
    await _repo.clear();
    state = const AsyncData(Cart.empty);
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart>(CartNotifier.new);

/// Số dòng trong giỏ (cho badge).
final cartCountProvider = Provider<int>(
    (ref) => ref.watch(cartProvider).valueOrNull?.lines.length ?? 0);
