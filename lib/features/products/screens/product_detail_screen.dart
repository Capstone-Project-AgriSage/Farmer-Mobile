import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_widgets.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  /// Id sản phẩm của cửa hàng (storeProductId) lấy từ danh sách.
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  /// null = quy cách rẻ nhất đặt được.
  String? _selectedId;
  int _quantity = 1;
  bool _adding = false;

  Packaging? _selectedOf(ProductDetail p) {
    final options = p.purchasable;
    if (options.isEmpty) return null;
    return options.firstWhere((o) => o.id == _selectedId,
        orElse: () => options.first);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productDetailProvider(widget.productId));
    final product = detail.valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: const [CartIconButton(), SizedBox(width: 8)],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryWidget(
          error: e,
          onRetry: () =>
              ref.invalidate(productDetailProvider(widget.productId)),
        ),
        data: (p) => _DetailBody(
          product: p,
          selected: _selectedOf(p),
          onSelect: (o) => setState(() => _selectedId = o.id),
        ),
      ),
      // Đặt ở bottomNavigationBar để thông báo (SnackBar) nổi PHÍA TRÊN thanh
      // này, không che nút số lượng / "Thêm vào giỏ".
      bottomNavigationBar: product == null
          ? null
          : _BottomBar(
              enabled: _selectedOf(product) != null,
              quantity: _quantity,
              adding: _adding,
              onQuantity: (q) => setState(() => _quantity = q),
              onAdd: () => _addToCart(product),
            ),
    );
  }

  Future<void> _addToCart(ProductDetail product) async {
    final packaging = _selectedOf(product);
    if (packaging == null || _adding) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(cartProvider.notifier).add(
            storeProductId: product.id,
            packagingId: packaging.id,
            quantity: _quantity,
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Đã thêm $_quantity ${packaging.label} vào giỏ hàng.'),
          action: SnackBarAction(
            label: 'Xem giỏ',
            textColor: AppColors.primaryLight,
            onPressed: () => router.push(AppRoutes.cart),
          ),
        ));
      if (mounted) setState(() => _quantity = 1);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.product,
    required this.selected,
    required this.onSelect,
  });

  final ProductDetail product;
  final Packaging? selected;
  final ValueChanged<Packaging> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final options = p.purchasable;
    final selected = this.selected;
    final base = p.baseUnit;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 240,
          margin: const EdgeInsets.all(16),
          child: ProductImage(
            url: p.imageUrl,
            iconSize: 80,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(p.categoryName, AppColors.primary,
                      AppColors.primaryLight),
                  if (p.brandName != null)
                    _Tag(p.brandName!, AppColors.textSecondary,
                        AppColors.surfaceSecondary),
                ],
              ),
              const SizedBox(height: 12),
              Text(p.name, style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text('Mã: ${p.sku}',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 12),
              if (selected != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatVnd(selected.price!),
                        key: const Key('detail_price'),
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.primary)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('/ ${selected.label}',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ),
                  ],
                )
              else
                Text('Chưa có giá bán',
                    key: const Key('detail_no_price'),
                    style:
                        AppTextStyles.h4.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
        if (options.isNotEmpty)
          _Section(
            icon: Icons.straighten,
            title: 'Chọn quy cách',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  ChoiceChip(
                    key: Key('pack_${o.id}'),
                    label: Text('${o.label} · ${formatVnd(o.price!)}'),
                    selected: o.id == selected?.id,
                    selectedColor: AppColors.primaryLight,
                    onSelected: (_) => onSelect(o),
                  ),
              ],
            ),
          ),
        if (selected != null && !selected.isBaseUnit && base != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '1 ${selected.label} = ${selected.conversionToBase} ${base.symbol ?? base.unitName}',
              key: const Key('detail_conversion'),
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
        if (options.isEmpty)
          const _Section(
            icon: Icons.info_outline,
            title: 'Chưa thể đặt mua',
            child: Text(
                'Sản phẩm này chưa có giá bán. Vui lòng liên hệ cửa hàng để được báo giá.'),
          ),
        if (p.ingredients.isNotEmpty)
          _Section(
            icon: Icons.science_outlined,
            title: 'Hoạt chất',
            child: _Card(
              child: Column(
                children: [
                  for (final i in p.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                              child:
                                  Text(i.name, style: AppTextStyles.bodySmall)),
                          if (i.concentration != null)
                            Text(i.concentration!,
                                style: AppTextStyles.bodySmall
                                    .copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_hasText(p.description))
          _Section(
            icon: Icons.description_outlined,
            title: 'Thông tin sản phẩm',
            child: Text(p.description!.trim(),
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.6)),
          ),
        if (_hasText(p.usageInstructions))
          _Section(
            icon: Icons.menu_book_outlined,
            title: 'Hướng dẫn sử dụng',
            child: _Card(
              child: Text(p.usageInstructions!.trim(),
                  style: AppTextStyles.bodySmall.copyWith(height: 1.6)),
            ),
          ),
        _RelatedProducts(categoryId: p.categoryId, excludeId: p.id),
        const SizedBox(height: 24),
      ],
    );
  }

  static bool _hasText(String? s) => s != null && s.trim().isNotEmpty;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.enabled,
    required this.quantity,
    required this.adding,
    required this.onQuantity,
    required this.onAdd,
  });

  final bool enabled;
  final int quantity;
  final bool adding;
  final ValueChanged<int> onQuantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            QuantityStepper(
              value: quantity,
              max: CartRepository.maxQuantity,
              enabled: enabled && !adding,
              onChanged: onQuantity,
              // Màn hẹp (≤ 360): thu gọn để nút "Thêm vào giỏ" không xuống dòng.
              compact: MediaQuery.sizeOf(context).width <= 360,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('add_to_cart'),
                onPressed: (enabled && !adding) ? onAdd : null,
                icon: adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_shopping_cart, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(enabled ? 'Thêm vào giỏ' : 'Chưa có giá',
                      maxLines: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatedProducts extends ConsumerWidget {
  const _RelatedProducts({required this.categoryId, required this.excludeId});

  final String categoryId;
  final String excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedProductsProvider(
        (categoryId: categoryId, excludeId: excludeId)));
    // Phần phụ: lỗi hay rỗng thì ẩn, không làm phiền người dùng.
    final items = related.valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return _Section(
      icon: Icons.grid_view_outlined,
      title: 'Sản phẩm cùng danh mục',
      child: SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => ProductCard(product: items[i], width: 160),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: child,
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.fg, this.bg);

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: AppTextStyles.caption
                .copyWith(color: fg, fontWeight: FontWeight.w600)),
      );
}
