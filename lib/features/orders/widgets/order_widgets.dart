import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../data/order_models.dart';

final _dateTime = DateFormat('HH:mm dd/MM/yyyy');
final _date = DateFormat('dd/MM/yyyy');

String formatDateTime(DateTime d) => _dateTime.format(d.toLocal());
String formatDate(DateTime d) => _date.format(d.toLocal());

/// Nhãn trạng thái đơn có màu.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = OrderStatus.colors(status);
    return StatusChip(text: OrderStatus.label(status), fg: fg, bg: bg);
  }
}

/// Nhãn nhỏ dùng chung (trạng thái thanh toán, giao hàng...).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.text, required this.fg, required this.bg});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: AppTextStyles.caption
                .copyWith(color: fg, fontWeight: FontWeight.w700)),
      );
}

/// Khung trắng có tiêu đề và biểu tượng.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: AppTextStyles.h4.copyWith(fontSize: 15)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Hàng "nhãn — giá trị" căn hai bên; giá trị dài thì xuống dòng.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value,
      {super.key, this.bold = false, this.valueColor, this.valueKey});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.right,
              style: (bold ? AppTextStyles.bodyMedium : AppTextStyles.bodySmall)
                  .copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
