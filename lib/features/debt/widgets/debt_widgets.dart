import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/debt_models.dart';

class DebtStatusBadge extends StatelessWidget {
  const DebtStatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = DebtStatus.colors(status);
    return StatusChip(text: DebtStatus.label(status), fg: fg, bg: bg);
  }
}

/// "Quá hạn N ngày" (chỉ khi khoản nợ còn phải trả).
class OverdueBadge extends StatelessWidget {
  const OverdueBadge(this.days, {super.key});

  final int days;

  @override
  Widget build(BuildContext context) => StatusChip(
        text: days > 0 ? 'Quá hạn $days ngày' : 'Quá hạn',
        fg: AppColors.debtOverdue,
        bg: AppColors.statusErrorSurface,
      );
}

/// Thẻ một khoản nợ trong danh sách.
class DebtEntryCard extends StatelessWidget {
  const DebtEntryCard({super.key, required this.entry, required this.onTap});

  final DebtEntrySummary entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = entry.isOverdue && !entry.isClosed;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: overdue ? AppColors.debtOverdue.withValues(alpha: 0.4) : AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.entryNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge),
                  ),
                  const SizedBox(width: 8),
                  DebtStatusBadge(entry.status),
                ],
              ),
              if (entry.orderNumber != null) ...[
                const SizedBox(height: 4),
                Text('Đơn hàng ${entry.orderNumber}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hạn trả',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(formatDate(entry.dueDate),
                            style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: overdue ? AppColors.debtOverdue : AppColors.textPrimary)),
                        if (overdue) ...[
                          const SizedBox(height: 4),
                          OverdueBadge(entry.overdueDays),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(entry.isClosed ? 'Số tiền' : 'Còn phải trả',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        formatVnd(entry.isClosed ? entry.originalAmount : entry.outstandingAmount),
                        style: AppTextStyles.labelLarge.copyWith(
                            color: entry.isClosed ? AppColors.textPrimary : AppColors.statusError),
                      ),
                      if (!entry.isClosed && entry.totalPaid > 0) ...[
                        const SizedBox(height: 2),
                        Text('Đã trả ${formatVnd(entry.totalPaid)}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.statusSuccess)),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
