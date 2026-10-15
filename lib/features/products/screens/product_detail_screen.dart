import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
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
    final selected = product == null ? null : _selectedOf(product);
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
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
      body: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ErrorRetryWidget(
          error: e,
          onRetry: () =>
              ref.invalidate(productDetailProvider(widget.productId)),
        ),
        data: (p) => _DetailBody(
          product: p,
          selected: selected,
          onSelect: (o) => setState(() => _selectedId = o.id),
        ),
      ),
      // Đặt ở bottomNavigationBar để thông báo (SnackBar) nổi PHÍA TRÊN thanh
      // này, không che nút số lượng / "Thêm vào giỏ".
      bottomNavigationBar: product == null
          ? null
          : _BottomBar(
              enabled: selected != null,
              unitPrice: selected?.price,
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
        // Ảnh lớn bo góc, rồi khối thông tin chính.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          // Tỉ lệ 4:3 nhưng không cao quá 300 (máy tính bảng, xoay ngang).
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ProductImage(
                  url: p.imageUrl,
                  iconSize: 80,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(p.categoryName, AppColors.primary, AppColors.primaryLight,
                        icon: categoryIcon(p.categoryName)),
                    if (p.brandName != null)
                      _Tag(p.brandName!, AppColors.textSecondary,
                          AppColors.surfaceSecondary,
                          icon: Icons.verified_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                Text(p.name, style: AppTextStyles.h2.copyWith(fontSize: 21)),
                const SizedBox(height: 4),
                Text('Mã: ${p.sku}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 14),
                if (selected != null)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 6,
                    children: [
                      Text(formatVnd(selected.price!),
                          key: const Key('detail_price'),
                          style: AppTextStyles.priceLarge.copyWith(fontSize: 26)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('/ ${selected.label}',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textMuted)),
                      ),
                    ],
                  )
                else
                  Text('Chưa có giá bán',
                      key: const Key('detail_no_price'),
                      style: AppTextStyles.h3.copyWith(color: AppColors.textMuted)),
                if (selected != null && !selected.isBaseUnit && base != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '1 ${selected.label} = ${selected.conversionToBase} ${base.symbol ?? base.unitName}',
                          key: const Key('detail_conversion'),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (options.isNotEmpty)
          _Section(
            icon: Icons.straighten_rounded,
            title: 'Chọn quy cách',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final o in options)
                  _PackOption(
                    key: Key('pack_${o.id}'),
                    packaging: o,
                    selected: o.id == selected?.id,
                    onTap: () => onSelect(o),
                  ),
              ],
            ),
          ),
        if (options.isEmpty)
          const _Section(
            icon: Icons.info_outline_rounded,
            title: 'Chưa thể đặt mua',
            child: _Card(
              child: Text(
                  'Sản phẩm này chưa có giá bán. Vui lòng liên hệ cửa hàng để được báo giá.'),
            ),
          ),
        if (p.ingredients.isNotEmpty)
          _Section(
            icon: Icons.science_outlined,
            title: 'Hoạt chất',
            child: _Card(
              child: Column(
                children: [
                  for (var i = 0; i < p.ingredients.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 16, color: AppColors.borderSubtle),
                    Row(
                      children: [
                        Expanded(
                            child: Text(p.ingredients[i].name,
                                style: AppTextStyles.bodyMedium)),
                        if (p.ingredients[i].concentration != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(p.ingredients[i].concentration!,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (_hasText(p.description))
          _Section(
            icon: Icons.description_outlined,
            title: 'Thông tin sản phẩm',
            child: _Card(
              child: Text(p.description!.trim(),
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary, height: 1.6)),
            ),
          ),
        if (_hasText(p.usageInstructions))
          _Section(
            icon: Icons.menu_book_outlined,
            title: 'Hướng dẫn sử dụng',
            child: _Card(
              child: Text(p.usageInstructions!.trim(),
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
            ),
          ),
        _RelatedProducts(categoryId: p.categoryId, excludeId: p.id),
        const SizedBox(height: 24),
      ],
    );
  }

  static bool _hasText(String? s) => s != null && s.trim().isNotEmpty;
}

/// Một quy cách để chọn: tên + giá; đang chọn thì viền xanh và dấu tích.
class _PackOption extends StatelessWidget {
  const _PackOption({
    super.key,
    required this.packaging,
    required this.selected,
    required this.onTap,
  });

  final Packaging packaging;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.borderStrong,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(packaging.label,
                        style: AppTextStyles.labelLarge.copyWith(
                            color: selected ? AppColors.primaryDark : AppColors.textPrimary)),
                    Text(formatVnd(packaging.price!),
                        style: AppTextStyles.bodySmall.copyWith(
                            color: selected ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.enabled,
    required this.unitPrice,
    required this.quantity,
    required this.adding,
    required this.onQuantity,
    required this.onAdd,
  });

  final bool enabled;
  final double? unitPrice;
  final int quantity;
  final bool adding;
  final ValueChanged<int> onQuantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final price = unitPrice;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enabled && price != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text('Tạm tính',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    Text(formatVnd(price * quantity),
                        key: const Key('detail_subtotal'),
                        style: AppTextStyles.h4.copyWith(color: AppColors.primaryDark)),
                  ],
                ),
              ),
            Row(
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
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_shopping_cart_rounded, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(enabled ? 'Thêm vào giỏ' : 'Chưa có giá',
                          maxLines: 1),
                    ),
                  ),
                ),
              ],
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
    // Cao theo cỡ chữ hệ thống để tên và giá không bị cắt.
    final height = 190 + MediaQuery.textScalerOf(context).scale(70);
    return _Section(
      icon: Icons.grid_view_rounded,
      title: 'Sản phẩm cùng danh mục',
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 17)),
              ),
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
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.fg, this.bg, {this.icon});

  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: fg, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

/// Khung xương trong lúc tải chi tiết (thay vòng quay).
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ShimmerLoadingWidget(height: double.infinity, borderRadius: 24),
        ),
        SizedBox(height: 20),
        ShimmerLoadingWidget(height: 14, width: 120, borderRadius: 7),
        SizedBox(height: 14),
        ShimmerLoadingWidget(height: 22, borderRadius: 8),
        SizedBox(height: 10),
        ShimmerLoadingWidget(height: 22, borderRadius: 8, margin: EdgeInsets.only(right: 120)),
        SizedBox(height: 18),
        ShimmerLoadingWidget(height: 28, width: 160, borderRadius: 8),
        SizedBox(height: 28),
        ShimmerLoadingWidget(height: 90, borderRadius: 18),
      ],
    );
  }
}
