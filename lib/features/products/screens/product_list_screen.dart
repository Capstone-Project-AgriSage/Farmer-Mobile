import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../router/app_router.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/providers/catalog_providers.dart';
import '../../catalog/widgets/product_card.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});
  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  static const _searchDelay = Duration(milliseconds: 400);

  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  ProductQuery _query = const ProductQuery();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) {
      ref.read(productListProvider(_query).notifier).loadMore();
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      if (!mounted) return;
      setState(() => _query = _query.copyWith(search: text.trim()));
    });
  }

  void _selectCategory(String categoryId) {
    if (categoryId == _query.categoryId) return;
    setState(() => _query = _query.copyWith(categoryId: categoryId));
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _query = const ProductQuery());
  }

  Future<void> _refresh() async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(productListProvider(_query));
    try {
      await ref.read(productListProvider(_query).future);
    } catch (_) {
      // The error is shown by the list itself (retry view); the pull-to-refresh spinner just ends.
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(productListProvider(_query));
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text('Sản phẩm', style: AppTextStyles.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
            onPressed: () => context.push(AppRoutes.cart),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header Search & Filters
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm...',
                      hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Categories
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final label = i == 0 ? 'Tất cả' : categories[i - 1].name;
                      final value = i == 0 ? '' : categories[i - 1].id;
                      final isActive = _query.categoryId == value;
                      return GestureDetector(
                        onTap: () => _selectCategory(value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF1B5E20) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isActive ? const Color(0xFF1B5E20) : AppColors.borderSubtle),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isActive ? Colors.white : AppColors.textSecondary,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Product Grid
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorRetryView(
                error: error,
                onRetry: () => ref.invalidate(productListProvider(_query)),
              ),
              data: (state) {
                if (state.items.isEmpty) return _EmptyResult(filtered: _query.search.isNotEmpty || _query.categoryId.isNotEmpty, onClear: _clearFilters);
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverGrid.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: state.items.length,
                          itemBuilder: (_, i) {
                            final product = state.items[i];
                            return ProductCard(
                              product: product,
                              onTap: () => context.push('/products/${product.id}'),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          child: _ListFooter(
                            loading: state.loadingMore,
                            error: state.moreError?.message,
                            onRetry: () => ref.read(productListProvider(_query).notifier).loadMore(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.filtered, required this.onClear});

  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              filtered ? 'Không tìm thấy sản phẩm phù hợp' : 'Cửa hàng chưa có sản phẩm nào',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (filtered) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onClear, child: const Text('Xóa bộ lọc')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Under the grid: a spinner while the next page loads, or a retry line when it failed.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.loading, required this.error, required this.onRetry});

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (error != null) {
      return Column(
        children: [
          Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError), textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
