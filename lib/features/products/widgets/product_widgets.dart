import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../data/catalog_models.dart';
import '../providers/catalog_providers.dart';

/// Ảnh sản phẩm có ô giữ chỗ khi chưa có ảnh / lỗi tải / đang tải.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.url,
    this.iconSize = 40,
    this.borderRadius = BorderRadius.zero,
  });

  final String? url;
  final double iconSize;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.surfaceSubtle,
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_outlined,
          size: iconSize, color: AppColors.borderStrong),
    );
    final u = url;
    return ClipRRect(
      borderRadius: borderRadius,
      child: (u == null || u.isEmpty)
          ? placeholder
          : CachedNetworkImage(
              imageUrl: u,
              fit: BoxFit.cover,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
    );
  }
}

/// Giá "từ ..." của sản phẩm, hoặc "Chưa có giá".
class FromPriceText extends StatelessWidget {
  const FromPriceText(this.price, {super.key, this.style});

  final double? price;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ??
        AppTextStyles.bodyMedium
            .copyWith(color: AppColors.primary, fontWeight: FontWeight.bold);
    if (price == null) {
      return Text('Chưa có giá',
          style: base.copyWith(
              color: AppColors.textMuted, fontWeight: FontWeight.w500));
    }
    return Text.rich(TextSpan(children: [
      TextSpan(
          text: 'Từ ',
          style: base.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              fontSize: (base.fontSize ?? 14) - 2)),
      TextSpan(text: formatVnd(price!), style: base),
    ]));
  }
}

/// Thẻ sản phẩm trong lưới.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width});

  final CatalogProduct product;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('product_${product.id}'),
      onTap: () => context.push('${AppRoutes.products}/${product.id}'),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ProductImage(
                  url: product.imageUrl,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    // Giữ chiều cao 2 dòng để các thẻ thẳng hàng.
                    height: 40,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FromPriceText(product.fromPrice),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút giỏ hàng trên AppBar, có số dòng trong giỏ.
class CartIconButton extends ConsumerWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return IconButton(
      key: const Key('cart_button'),
      tooltip: 'Giỏ hàng',
      onPressed: () => context.push(AppRoutes.cart),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: AppColors.statusError,
        child: const Icon(Icons.shopping_cart_outlined,
            color: AppColors.textPrimary),
      ),
    );
  }
}

/// Bộ chọn số lượng − n +.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 9999,
    this.enabled = true,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : 18.0;
    final pad = compact ? 6.0 : 8.0;
    Widget btn(IconData icon, String tip, bool on, int next, Key key) =>
        IconButton(
          key: key,
          tooltip: tip,
          icon: Icon(icon, size: iconSize),
          onPressed: (enabled && on) ? () => onChanged(next) : null,
          padding: EdgeInsets.all(pad),
          constraints: const BoxConstraints(),
        );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove, 'Giảm', value > min, value - 1, const Key('qty_minus')),
          SizedBox(
            width: compact ? 32 : 40,
            child: Text('$value',
                key: const Key('qty_value'),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          btn(Icons.add, 'Tăng', value < max, value + 1, const Key('qty_plus')),
        ],
      ),
    );
  }
}
