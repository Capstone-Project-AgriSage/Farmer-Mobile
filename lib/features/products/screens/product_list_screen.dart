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
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sản phẩm', style: AppTextStyles.h2.copyWith(height: 1.2)),
            Text('Vật tư nông nghiệp của cửa hàng',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const CartIconButton(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
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
                    hintText: 'Tìm phân bón, thuốc, hạt giống...',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Xoá tìm kiếm',
                            icon: const Icon(Icons.close_rounded, size: 18),
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
        itemBuilder: (_, __) => const _CardSkeleton(),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text('${state.totalCount} sản phẩm',
                  key: const Key('product_count'),
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
    childAspectRatio: 0.64,
    crossAxisSpacing: 14,
    mainAxisSpacing: 14,
  );
}

/// Khung xương của một thẻ sản phẩm trong lúc tải (ảnh vuông + 2 dòng chữ).
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ShimmerLoadingWidget(height: double.infinity, borderRadius: 14)),
          SizedBox(height: 12),
          ShimmerLoadingWidget(height: 12, borderRadius: 6, margin: EdgeInsets.only(right: 24)),
          SizedBox(height: 8),
          ShimmerLoadingWidget(height: 12, borderRadius: 6, margin: EdgeInsets.only(right: 60)),
          SizedBox(height: 12),
          ShimmerLoadingWidget(height: 16, borderRadius: 6, margin: EdgeInsets.only(right: 80)),
          SizedBox(height: 8),
        ],
      ),
    );
  }
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
    // Cao theo cỡ chữ hệ thống để chữ to không bị cắt.
    final height = MediaQuery.textScalerOf(context).scale(20) + 20;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length + (categories.hasError ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == entries.length) {
            // Không tải được danh mục: vẫn tìm được sản phẩm, cho thử lại.
            return _CategoryPill(
              key: const Key('category_retry'),
              icon: Icons.refresh_rounded,
              label: 'Tải lại danh mục',
              active: false,
              onTap: () => ref.invalidate(categoriesProvider),
            );
          }
          final (id, name) = entries[i];
          return _CategoryPill(
            key: Key('category_${id ?? 'all'}'),
            icon: id == null ? Icons.apps_rounded : categoryIcon(name),
            label: name,
            active: id == selectedId,
            onTap: () => onSelected(id),
          );
        },
      ),
    );
  }
}

/// Chip danh mục: icon + tên; đang chọn thì nền xanh chữ trắng.
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: active ? AppColors.primary : AppColors.borderSubtle),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: active ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
                Text(label,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: fg,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
