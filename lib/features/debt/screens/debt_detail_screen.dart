import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/debt.dart';
import '../../../data/mock/mock_debts.dart';

class DebtDetailScreen extends StatelessWidget {
  final String debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  Widget build(BuildContext context) {
    // Find debt by ID, fallback to first if not found
    final debt = mockDebts.firstWhere((d) => d.id == debtId, orElse: () => mockDebts.first);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết công nợ'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status Banner ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: debt.status.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: debt.status.color.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          debt.status == DebtStatus.paid ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: debt.status.color,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trạng thái', style: AppTextStyles.caption.copyWith(color: debt.status.color)),
                              Text(debt.status.label, style: AppTextStyles.labelLarge.copyWith(color: debt.status.color, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Amount Card ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        Text('SỐ TIỀN CẦN THANH TOÁN', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatPrice(debt.amount)}đ',
                          style: AppTextStyles.h2.copyWith(color: debt.status == DebtStatus.paid ? AppColors.textPrimary : AppColors.statusError),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: AppColors.borderSubtle),
                        const SizedBox(height: 20),
                        _buildInfoRow('Mã công nợ', debt.id),
                        const SizedBox(height: 12),
                        _buildInfoRow('Ngày lập', _formatDate(debt.createdAt)),
                        const SizedBox(height: 12),
                        _buildInfoRow('Hạn thanh toán', _formatDate(debt.dueDate), highlight: debt.status != DebtStatus.paid),
                        const SizedBox(height: 12),
                        _buildInfoRow('Đại lý', debt.agentName),
                        if (debt.note != null && debt.note!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow('Ghi chú', debt.note!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Confirmation Status ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xác nhận hai chiều', style: AppTextStyles.labelLarge),
                        const SizedBox(height: 12),
                        _buildConfirmItem('Đại lý xác nhận', debt.agentConfirmed),
                        const SizedBox(height: 8),
                        _buildConfirmItem('Bạn (Nông dân) xác nhận', debt.farmerConfirmed),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Bottom Action ─────────────────────────────────────────
          if (debt.status != DebtStatus.paid)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/debt/${debt.id}/confirm'),
                  icon: const Icon(Icons.payment, size: 20),
                  label: const Text('Thanh toán khoản nợ này'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: highlight ? AppColors.statusError : AppColors.textPrimary,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmItem(String label, bool isConfirmed) {
    return Row(
      children: [
        Icon(
          isConfirmed ? Icons.check_circle : Icons.pending,
          color: isConfirmed ? AppColors.statusSuccess : AppColors.textMuted,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isConfirmed ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: isConfirmed ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');
  }
}
