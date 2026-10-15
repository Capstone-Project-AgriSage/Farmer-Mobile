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
///
/// Ảnh được giải mã đúng kích thước hiển thị (`memCacheWidth`) thay vì ảnh gốc
/// (thường 1000px+), đỡ tốn bộ nhớ khi cuộn lưới dài; hiện mờ dần khi tải xong.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.url,
    this.iconSize = 40,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double iconSize;
  final BorderRadius borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F7F0), Color(0xFFE6EFE5)],
        ),
      ),
      child: Center(
        child: Icon(Icons.eco_outlined,
            size: iconSize, color: AppColors.primary.withValues(alpha: 0.28)),
      ),
    );
    final u = url;
    return ClipRRect(
      borderRadius: borderRadius,
      child: (u == null || u.isEmpty)
          ? placeholder
          : LayoutBuilder(builder: (context, c) {
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final w = c.maxWidth.isFinite ? (c.maxWidth * dpr).round() : null;
              return CachedNetworkImage(
                imageUrl: u,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: w,
                fadeInDuration: const Duration(milliseconds: 250),
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              );
            }),
    );
  }
}

/// Biểu tượng gợi ý theo tên danh mục (danh mục do cửa hàng tự đặt tên).
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('giống') || n.contains('hạt')) return Icons.spa_outlined;
  if (n.contains('phân')) return Icons.grass_outlined;
  if (n.contains('thuốc') || n.contains('bvtv') || n.contains('trừ')) {
    return Icons.science_outlined;
  }
  if (n.contains('dụng cụ') || n.contains('máy') || n.contains('thiết bị')) {
    return Icons.handyman_outlined;
  }
  return Icons.category_outlined;
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
    // Giữ chiều cao 2 dòng tên để các thẻ thẳng hàng (co giãn theo cỡ chữ hệ thống).
    final nameHeight = MediaQuery.textScalerOf(context).scale(38);
    return GestureDetector(
      key: Key('product_${product.id}'),
      onTap: () => context.push('${AppRoutes.products}/${product.id}'),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ProductImage(
                        url: product.imageUrl,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    // Nhãn danh mục đè lên góc ảnh.
                    Positioned(
                      left: 8,
                      top: 8,
                      right: 8,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            product.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: nameHeight,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FromPriceText(product.fromPrice,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3)),
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
