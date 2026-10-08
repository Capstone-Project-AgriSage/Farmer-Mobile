import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/debt_labels.dart';
import '../../../core/labels/status_label.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/debt_models.dart';

/// One debt in the list: where it came from, how much is left and when it is due.
class DebtEntryCard extends StatelessWidget {
  const DebtEntryCard({super.key, required this.entry, required this.onTap});

  final DebtEntryListItem entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = entry.isOverdue && entry.outstandingAmount > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: overdue ? AppColors.statusError.withValues(alpha: 0.4) : AppColors.borderSubtle),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('#${entry.title}', style: AppTextStyles.labelLarge)),
                const SizedBox(width: 8),
                StatusBadge(labelOf(debtEntryStatusLabels, entry.status)),
              ],
            ),
            const SizedBox(height: 2),
            Text(debtSourceLabel(entry.sourceType), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Amount(label: 'Gốc', value: formatVnd(entry.originalAmount))),
                Expanded(child: _Amount(label: 'Đã trả', value: formatVnd(entry.totalPaid), color: AppColors.primary)),
                Expanded(
                  child: _Amount(
                    label: 'Còn nợ',
                    value: formatVnd(entry.outstandingAmount),
                    color: entry.outstandingAmount > 0 ? AppColors.textPrimary : AppColors.textMuted,
                    bold: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 16, color: overdue ? AppColors.statusError : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Hạn trả ${formatVnDate(entry.dueDate)}',
                  style: AppTextStyles.caption.copyWith(color: overdue ? AppColors.statusError : AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                if (overdue) ...[
                  const SizedBox(width: 8),
                  StatusBadge(StatusLabel('Quá hạn ${entry.overdueDays} ngày', LabelTone.danger)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.color, this.bold = false});

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? AppColors.textPrimary),
          ),
        ],
      );
}
