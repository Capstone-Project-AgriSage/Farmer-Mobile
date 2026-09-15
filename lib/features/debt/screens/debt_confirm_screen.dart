import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class DebtConfirmScreen extends StatefulWidget {
  final String debtId;
  const DebtConfirmScreen({super.key, required this.debtId});
  @override State<DebtConfirmScreen> createState() => _DebtConfirmScreenState();
}

class _DebtConfirmScreenState extends State<DebtConfirmScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Xác nhận công nợ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('Trạng thái hiện tại:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.statusWarningSurface, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_empty, size: 14, color: AppColors.statusWarning),
                        const SizedBox(width: 4),
                        Text('Chờ xác nhận', style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Debt Overview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(12), 
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('THÔNG TIN CÔNG NỢ VỤ NÀY', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('Tổng số tiền ghi nhận công nợ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('1.319.000', style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text('đ', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ngày phát sinh', style: AppTextStyles.caption),
                          const SizedBox(height: 2),
                          Text('05/09/2026', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hình thức ghi nợ', style: AppTextStyles.caption),
                          const SizedBox(height: 2),
                          Text('Vật tư nông nghiệp', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Order Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Thông tin đơn hàng', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(4)),
                        child: Text(widget.debtId, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Khách hàng / Chủ ruộng:', 'Trần Văn Hải'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Số loại vật tư:', '3 sản phẩm'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Tổng giá trị đơn:', '1.319.000đ'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Exported Items Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Danh mục vật tư xuất kho', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      Text('Không chỉnh sửa', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProductRow('Phân NPK Đầu Trâu 20-20-15', 'Số lượng: 1 bao (50kg)', '485.000đ'),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildProductRow('Thuốc Trừ Bệnh Beam 75WP', 'Số lượng: 2 gói (100g)', '184.000đ'),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildProductRow('Lúa Giống ST25 Thượng Hạng', 'Số lượng: 1 bao (20kg)', '650.000đ'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Warning Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.statusWarningSurface, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.statusWarning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vui lòng kiểm tra kỹ thông tin trước khi xác nhận.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusWarning, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Sau khi xác nhận, khoản công nợ không được chỉnh sửa trực tiếp. Nếu có sai lệch, hệ thống sẽ ghi nhận giao dịch điều chỉnh mới và gửi lại lịch sử.', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isSubmitting ? null : () async {
                setState(() => _isSubmitting = true);
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) { 
                  context.pop(); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã xác nhận khoản nợ thành công', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.primary)); 
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Xác nhận công nợ', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: Text('Xem lại đơn hàng', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildProductRow(String title, String subtitle, String price) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
        Text(price, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}