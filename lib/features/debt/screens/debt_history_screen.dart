import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/debt_labels.dart';
import '../../../core/labels/status_label.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../payment/data/payment_models.dart';
import '../providers/debt_providers.dart';

/// Lịch sử trả nợ: các lần Bác trả nợ (qua payOS hoặc tại quầy), mới nhất trước.
class DebtHistoryScreen extends ConsumerWidget {
  const DebtHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(debtSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Lịch sử trả nợ')),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(debtSummaryProvider)),
        data: (data) {
          final payments = data.repayments;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(debtSummaryProvider);
              try {
                await ref.read(debtSummaryProvider.future);
              } catch (_) {
                // The screen shows its own error.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Đã trả gần đây', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                      Text(formatVnd(data.totalRepaid), style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (payments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text('Bác chưa có lần trả nợ nào.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                else
                  for (final payment in payments) ...[
                    _RepaymentCard(payment: payment),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RepaymentCard extends StatelessWidget {
  const _RepaymentCard({required this.payment});

  final PaymentListItem payment;

  @override
  Widget build(BuildContext context) {
    final status = labelOf(repaymentStatusLabels, payment.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.paymentNumber, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(repaymentMethodLabel(payment.paymentMethod), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                Text(formatVnDateTime(payment.when), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatVnd(payment.amount),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: payment.status == PaymentStatus.paid ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              StatusBadge(status),
            ],
          ),
        ],
      ),
    );
  }
}
