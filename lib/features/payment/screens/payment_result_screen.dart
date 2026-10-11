import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final String? orderId;
  const PaymentResultScreen({super.key, required this.success, this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: success
                        ? AppColors.statusSuccessSurface
                        : AppColors.statusErrorSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(success ? Icons.check_circle : Icons.cancel,
                      size: 56,
                      color: success ? AppColors.statusSuccess : AppColors.statusError),
                ),
                const SizedBox(height: 24),
                Text(success ? 'Thanh toán thành công!' : 'Thanh toán chưa thành công',
                    style: AppTextStyles.h2, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  success
                      ? 'Cửa hàng đã nhận được tiền. Đơn hàng sẽ được xác nhận và chuẩn bị giao.'
                      : 'Bạn có thể thử thanh toán lại trong chi tiết đơn hàng.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                if (orderId != null)
                  ElevatedButton(
                    key: const Key('result_view_order'),
                    onPressed: () => context.go('/orders/$orderId'),
                    child: const Text('Xem đơn hàng'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('result_home'),
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
