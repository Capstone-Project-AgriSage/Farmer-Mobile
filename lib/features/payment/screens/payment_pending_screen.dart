import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class PaymentPendingScreen extends StatelessWidget {
  const PaymentPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Chờ xác nhận')),
      body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 96, height: 96, decoration: const BoxDecoration(color: Color(0xFFFFF8E1), shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_empty, size: 48, color: Color(0xFFF57F17))),
        const SizedBox(height: 24),
        Text('Đang chờ xác nhận', style: AppTextStyles.h2, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Đơn hàng đang trong trạng thái\n"Chờ xác nhận thanh toán".\nĐại lý sẽ xác nhận khi nhận được tiền.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        const LinearProgressIndicator(backgroundColor: AppColors.borderSubtle, color: AppColors.primary),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: () => context.go(AppRoutes.orderList), child: const Text('Xem đơn hàng của tôi')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Về trang chủ')),
      ]))),
    );
  }
}