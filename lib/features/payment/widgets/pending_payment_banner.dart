import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../router/app_router.dart';
import '../providers/payment_providers.dart';

/// On the home screen: a payment the farmer started and has not finished (for example the app was closed while they
/// were in a banking app). It disappears once the payment is settled, cancelled or its link has expired.
class PendingPaymentBanner extends ConsumerWidget {
  const PendingPaymentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingPaymentProvider);
    if (pending == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusWarningSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.statusWarning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bác có một thanh toán chưa hoàn tất (${formatVnd(pending.amount)})',
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.statusWarning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(
                    AppRoutes.paymentResult,
                    extra: PaymentResultArgs(pending, PaymentHint.check),
                  ),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Kiểm tra'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.payosCheckout, extra: pending),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: const Text('Thanh toán tiếp'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
