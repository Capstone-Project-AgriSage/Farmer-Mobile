import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../router/app_router.dart';
import '../data/order_models.dart';

/// Shown right after the order was created. A payOS order is not paid yet: that is the next step. A credit order only
/// waits for the store.
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.order});

  /// Null when the screen is reopened without the order (for example after the app was restarted).
  final Order? order;

  @override
  Widget build(BuildContext context) {
    final order = this.order;
    final needsPayment = order != null && !order.isCredit;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceSubtle,
        appBar: AppBar(title: const Text('Đặt hàng'), automaticallyImplyLeading: false),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 56, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text('Đã tạo đơn hàng', style: AppTextStyles.h2, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                if (order != null) ...[
                  Text('Mã đơn ${order.orderNumber}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(formatVnd(order.totalAmount), style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                ],
                const SizedBox(height: 16),
                Text(
                  order == null
                      ? 'Bác có thể xem đơn trong mục Đơn hàng.'
                      : needsPayment
                          ? 'Đơn đang chờ thanh toán. Bác thanh toán qua payOS để cửa hàng xác nhận đơn.'
                          : 'Đơn đang chờ cửa hàng xác nhận. Khoản nợ sẽ ghi vào Sổ nợ của Bác sau khi giao hàng thành công.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.orderList),
                  child: const Text('Xem đơn hàng'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.products),
                  child: const Text('Tiếp tục mua sắm'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
