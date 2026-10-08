import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../data/catalog_models.dart';
import 'product_image.dart';

/// One product in the grid and in the "related products" strip.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap, this.radius = 16});

  final CatalogProductListItem product;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPrice = product.hasPrice;
    final caption = product.brandName ?? product.categoryName ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                child: Container(
                  width: double.infinity,
                  color: AppColors.surfaceSubtle,
                  child: ProductImage(url: product.imageUrl),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasPrice ? AppColors.primaryLight : AppColors.statusWarningSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasPrice ? 'Đang bán' : 'Chưa có giá',
                      style: TextStyle(
                        fontSize: 9,
                        color: hasPrice ? AppColors.primary : AppColors.statusWarning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasPrice ? 'Từ ${formatVnd(product.fromPrice!)}' : 'Liên hệ cửa hàng',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: hasPrice ? AppColors.primary : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
