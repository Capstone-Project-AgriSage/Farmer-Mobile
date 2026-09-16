import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class DebtHistoryScreen extends StatelessWidget {
  const DebtHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock history data
    final historyItems = [
      {
        'date': DateTime.now().subtract(const Duration(days: 2)),
        'amount': 5000000,
        'title': 'Thanh toán một phần công nợ D-001',
        'status': 'Thành công',
        'method': 'Chuyển khoản QR'
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 30)),
        'amount': 12000000,
        'title': 'Thanh toán toàn bộ công nợ D-004',
        'status': 'Thành công',
        'method': 'Tiền mặt tại đại lý'
      },
      {
        'date': DateTime.now().subtract(const Duration(days: 45)),
        'amount': 3000000,
        'title': 'Thanh toán một phần nợ cũ',
        'status': 'Thất bại',
        'method': 'Chuyển khoản (Lỗi mạng)'
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Lịch sử thanh toán')),
      body: historyItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 64, color: AppColors.surfaceDim),
                  const SizedBox(height: 16),
                  Text('Chưa có lịch sử thanh toán nào', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: historyItems.length,
              itemBuilder: (context, index) {
                final item = historyItems[index];
                final isSuccess = item['status'] == 'Thành công';
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSuccess ? Icons.arrow_downward : Icons.close,
                          color: isSuccess ? AppColors.statusSuccess : AppColors.statusError,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] as String, style: AppTextStyles.labelLarge),
                            const SizedBox(height: 4),
                            Text(item['method'] as String, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDate(item['date'] as DateTime), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                Text(
                                  '${_formatPrice(item['amount'] as int)}đ',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isSuccess ? AppColors.statusSuccess : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatPrice(int price) {
    return price.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');
  }
}
