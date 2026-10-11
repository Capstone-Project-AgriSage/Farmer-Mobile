import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../data/catalog_repository.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_widgets.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  /// Chờ người dùng ngừng gõ rồi mới tìm (backend giới hạn 120 lần/phút).
  static const searchDebounce = Duration(milliseconds: 400);

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  late final TextEditingController _searchCtrl;
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Giữ từ khoá khi quay lại tab.
    _searchCtrl = TextEditingController(text: ref.read(productListProvider).search);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Đã lỗi thì chỉ thử lại khi người dùng bấm, không tự gọi lại mỗi lần cuộn
    // (mất mạng sẽ dồn request liên tục).
    if (ref.read(productListProvider).loadMoreError != null) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      ref.read(productListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {}); // cập nhật nút xoá
    _debounce?.cancel();
    _debounce = Timer(ProductListScreen.searchDebounce,
        () => ref.read(productListProvider.notifier).setSearch(value));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {});
    ref.read(productListProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListProvider);
    final notifier = ref.read(productListProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text('Sản phẩm', style: AppTextStyles.h3),
        actions: const [CartIconButton(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  key: const Key('product_search'),
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  onSubmitted: (v) {
                    _debounce?.cancel();
                    notifier.setSearch(v);
                  },
                  textInputAction: TextInputAction.search,
                  maxLength: CatalogRepository.maxSearchLength,
                  decoration: InputDecoration(
                    hintText: 'Tìm sản phẩm...',
                    counterText: '',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xoá tìm kiếm',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _CategoryBar(
                  selectedId: state.categoryId,
                  onSelected: notifier.setCategory,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(ProductListState state, ProductListController notifier) {
    if (state.isLoading && state.items.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: _gridDelegate,
        itemCount: 6,
        itemBuilder: (_, __) => const ShimmerLoadingWidget(height: double.infinity),
      );
    }
    if (state.error != null) {
      return ErrorRetryWidget(error: state.error!, onRetry: notifier.refresh);
    }
    if (state.items.isEmpty) {
      final filtered = state.search.isNotEmpty || state.categoryId != null;
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 380,
              child: EmptyDataWidget(
                message: filtered
                    ? 'Không tìm thấy sản phẩm phù hợp.\nThử từ khoá hoặc danh mục khác.'
                    : 'Cửa hàng chưa có sản phẩm nào.',
                fallbackIcon: Icons.search_off_outlined,
                actionText: state.search.isNotEmpty ? 'Xoá tìm kiếm' : null,
                onActionPressed: state.search.isNotEmpty ? _clearSearch : null,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text('${state.totalCount} sản phẩm',
                  key: const Key('product_count'),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (_, i) => ProductCard(product: state.items[i]),
                childCount: state.items.length,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFooter(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildFooter(ProductListState state, ProductListController notifier) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: TextButton.icon(
            key: const Key('load_more_retry'),
            onPressed: notifier.loadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('Không tải thêm được. Thử lại'),
          ),
        ),
      );
    }
    if (state.hasMore) {
      // Màn hình cao, chưa cuộn được: cho phép bấm tải thêm.
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: TextButton(
            key: const Key('load_more'),
            onPressed: notifier.loadMore,
            child: const Text('Xem thêm'),
          ),
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 220,
    childAspectRatio: 0.62,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
  );
}

class _CategoryBar extends ConsumerWidget {
  const _CategoryBar({required this.selectedId, required this.onSelected});

  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final list = categories.valueOrNull ?? const [];
    final entries = <(String?, String)>[
      (null, 'Tất cả'),
      for (final c in list) (c.id, c.name),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length + (categories.hasError ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == entries.length) {
            // Không tải được danh mục: vẫn tìm được sản phẩm, cho thử lại.
            return ActionChip(
              key: const Key('category_retry'),
              avatar: const Icon(Icons.refresh, size: 16),
              label: const Text('Tải lại danh mục'),
              onPressed: () => ref.invalidate(categoriesProvider),
            );
          }
          final (id, name) = entries[i];
          final active = id == selectedId;
          return ChoiceChip(
            key: Key('category_${id ?? 'all'}'),
            label: Text(name),
            selected: active,
            showCheckmark: false,
            selectedColor: AppColors.primaryDark,
            labelStyle: AppTextStyles.bodySmall.copyWith(
              color: active ? Colors.white : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
            onSelected: (_) => onSelected(id),
          );
        },
      ),
    );
  }
}
