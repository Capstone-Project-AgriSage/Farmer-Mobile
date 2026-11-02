import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../orders/widgets/order_widgets.dart' show StatusChip;
import '../../products/widgets/product_widgets.dart' show ProductImage;
import '../data/advisory_models.dart';

/// Một sản phẩm được gợi ý: lý do, nguồn đăng ký, liều, thời gian cách ly, số lượng cho diện tích đã nhập,
/// tình trạng hàng và nút thêm vào giỏ. Số lượng và giá do server tính; thẻ chỉ hiển thị.
class AdvisoryProductCard extends StatelessWidget {
  const AdvisoryProductCard({
    super.key,
    required this.product,
    required this.hasArea,
    required this.adding,
    required this.onAdd,
    required this.onOpen,
  });

  final AdvisoryProduct product;

  /// Nông dân đã nhập diện tích (để nói đúng khi chưa có số lượng).
  final bool hasArea;
  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final plan = p.plan;
    final (stockFg, stockBg) = switch (p.stockStatus) {
      AdvisoryStock.enough => (AppColors.statusSuccess, AppColors.statusSuccessSurface),
      AdvisoryStock.notEnough => (AppColors.statusWarning, AppColors.statusWarningSurface),
      _ => (AppColors.statusError, AppColors.statusErrorSurface),
    };

    return Container(
      key: Key('advisory_product_${p.storeProductId}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: ProductImage(
                    url: p.imageUrl,
                    iconSize: 28,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.h4),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          StatusChip(
                            key: Key('advisory_stock_${p.storeProductId}'),
                            text: AdvisoryStock.label(p.stockStatus),
                            fg: stockFg,
                            bg: stockBg,
                          ),
                          if (p.preHarvestDays != null)
                            StatusChip(
                              text: 'Cách ly ${p.preHarvestDays} ngày',
                              fg: AppColors.primaryDark,
                              bg: AppColors.primaryLight,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(p.reason, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ],
          if (p.registrationSource != null && p.registrationSource!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Đăng ký: ${p.registrationSource}',
                key: Key('advisory_source_${p.storeProductId}'),
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cách dùng và liều', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(p.doseText, style: AppTextStyles.bodySmall),
                if (p.applications > 1) ...[
                  const SizedBox(height: 2),
                  Text('Dùng ${p.applications} lần.', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (plan == null)
            Text(
              hasArea
                  ? 'Chưa tính được số lượng cho sản phẩm này. Mở sản phẩm để chọn quy cách.'
                  : 'Nhập diện tích ruộng ở trên để biết cần mua bao nhiêu.',
              key: Key('advisory_noplan_${p.storeProductId}'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            )
          else
            Column(
              key: Key('advisory_plan_${p.storeProductId}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cho ruộng của bạn cần:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                for (final l in plan.lines)
                  Text('${l.quantity} × ${l.packagingName}  (${formatVnd(l.lineAmount)})', style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text('Ước tính ${formatVnd(plan.totalAmount)}',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
              ],
            ),
          if (p.stockStatus == AdvisoryStock.notEnough) ...[
            const SizedBox(height: 6),
            Text('Cửa hàng chưa đủ số lượng này, bạn có thể đặt ít hơn hoặc hỏi cửa hàng.',
                style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning)),
          ],
          const SizedBox(height: 12),
          if (!p.inStock)
            OutlinedButton(
              key: Key('advisory_soldout_${p.storeProductId}'),
              onPressed: null,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              child: const Text('Hết hàng'),
            )
          else if (plan == null)
            OutlinedButton(
              key: Key('advisory_open_${p.storeProductId}'),
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              child: const Text('Xem sản phẩm'),
            )
          else
            ElevatedButton.icon(
              key: Key('advisory_add_${p.storeProductId}'),
              onPressed: adding ? null : onAdd,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
              icon: adding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: Text('Thêm vào giỏ · ${formatVnd(plan.totalAmount)}'),
            ),
        ],
      ),
    );
  }
}
