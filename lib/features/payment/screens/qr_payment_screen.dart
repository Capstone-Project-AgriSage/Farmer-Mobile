import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class QRPaymentScreen extends StatelessWidget {
  const QRPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Thanh toán VietQR'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.security, size: 14, color: Color(0xFF1B5E20)),
                  const SizedBox(width: 4),
                  Text('Giao dịch an toàn', style: AppTextStyles.caption.copyWith(color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
              child: Column(
                children: [
                  _buildInfoRow('Mã đơn hàng', 'DH-2024-1082', isBadge: true),
                  const SizedBox(height: 12),
                  _buildInfoRow('Người mua hàng', 'Trần Văn Hải'),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SỐ TIỀN THANH TOÁN', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                      Text('1.319.000đ', style: AppTextStyles.h4.copyWith(color: const Color(0xFF1B5E20))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // QR Area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner, color: Color(0xFF1B5E20), size: 18),
                      const SizedBox(width: 8),
                      Text('QUÉT MÃ VIETQR QUA APP NGÂN HÀNG', style: AppTextStyles.caption.copyWith(color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Fake QR Code
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSubtle),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('VietQR', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('MB BANK', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(child: Icon(Icons.qr_code_2, size: 140, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Chụp màn hình hoặc quét trực tiếp', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  const SizedBox(height: 16),
                  
                  // Bank Details
                  _buildDetailRow('Ngân hàng:', 'MB Bank (Quân Đội)', bold: true),
                  const SizedBox(height: 12),
                  _buildDetailRow('Chủ tài khoản:', 'NGUYEN VAN MINH', bold: true),
                  const SizedBox(height: 12),
                  _buildCopyRow('Số tài khoản:', '0123 456 789', context),
                  const SizedBox(height: 12),
                  _buildCopyRow('Nội dung chuyển khoản:', 'DH1082 TRANVANHAI', context, isHighlight: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.statusSuccess, size: 20),
                        const SizedBox(width: 8),
                        Text('Đã gửi yêu cầu xác nhận', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top, size: 12, color: Colors.orange.shade800),
                          const SizedBox(width: 4),
                          Text('Chờ đại lý xác nhận', style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Đại lý sẽ kiểm tra giao dịch và cập nhật trạng thái thanh toán.', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.caption.copyWith(color: Colors.orange.shade900, height: 1.4),
                            children: [
                              const TextSpan(text: 'AGRISAGE không tự động xác nhận giao dịch ngân hàng.\n', style: TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: 'Thanh toán sẽ được cập nhật ngay sau khi đại lý đối soát tiền về.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.orderList),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20), // Dark green
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Xem đơn hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text('Quay về trang chủ', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        isBadge
            ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(4)), child: Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)))
            : Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 130, child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w500), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildCopyRow(String label, String value, BuildContext context, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 130, child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isHighlight)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(4)), child: Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)))
              else
                Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép!'), duration: Duration(seconds: 1)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.borderSubtle)),
                  child: Row(
                    children: [
                      const Icon(Icons.copy, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Sao chép', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}