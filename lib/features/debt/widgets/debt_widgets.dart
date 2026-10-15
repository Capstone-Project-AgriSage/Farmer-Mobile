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

/// Thanh tiến độ bo tròn dùng chung cho công nợ (đã trả / đã dùng hạn mức).
class DebtProgressBar extends StatelessWidget {
  const DebtProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.primary,
    this.track = AppColors.primaryLight,
    this.height = 8,
  });

  /// 0..1 (ngoài khoảng được cắt lại).
  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation(color),
        ),
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
    final (fg, bg) = overdue
        ? (AppColors.debtOverdue, AppColors.statusErrorSurface)
        : entry.isClosed
            ? (AppColors.debtPaid, AppColors.surfaceSecondary)
            : (AppColors.primary, AppColors.primaryLight);
    final partial = !entry.isClosed && entry.totalPaid > 0 && entry.originalAmount > 0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: overdue
            ? Border.all(color: AppColors.debtOverdue.withValues(alpha: 0.35))
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                          entry.isClosed ? Icons.task_alt_rounded : Icons.receipt_long_outlined,
                          color: fg,
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.entryNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelLarge),
                          if (entry.orderNumber != null) ...[
                            const SizedBox(height: 2),
                            Text('Đơn hàng ${entry.orderNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DebtStatusBadge(entry.status),
                    if (overdue) OverdueBadge(entry.overdueDays),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: AppColors.borderSubtle),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hạn trả',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(formatDate(entry.dueDate),
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: overdue ? AppColors.debtOverdue : AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(entry.isClosed ? 'Số tiền' : 'Còn phải trả',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatVnd(
                                  entry.isClosed ? entry.originalAmount : entry.outstandingAmount),
                              style: AppTextStyles.h4.copyWith(
                                  color: entry.isClosed
                                      ? AppColors.textPrimary
                                      : AppColors.statusError),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (partial) ...[
                  const SizedBox(height: 12),
                  DebtProgressBar(
                    key: const Key('debt_entry_progress'),
                    value: entry.totalPaid / entry.originalAmount,
                    height: 6,
                  ),
                  const SizedBox(height: 6),
                  Text('Đã trả ${formatVnd(entry.totalPaid)}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.statusSuccess)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
