import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  const PaymentResultScreen({super.key, required this.success});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 96, height: 96, decoration: BoxDecoration(color: success ? AppColors.statusSuccessSurface : AppColors.statusErrorSurface, shape: BoxShape.circle),
          child: Icon(success ? Icons.check_circle : Icons.cancel, size: 56, color: success ? AppColors.statusSuccess : AppColors.statusError)),
        const SizedBox(height: 24),
        Text(success ? 'Thanh toán thành công!' : 'Thanh toán thất bại', style: AppTextStyles.h2, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(success ? 'Đơn hàng của bạn đã được xác nhận.' : 'Có lỗi xảy ra. Vui lòng thử lại.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 36),
        ElevatedButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Về trang chủ')),
      ]))),
    );
  }
}