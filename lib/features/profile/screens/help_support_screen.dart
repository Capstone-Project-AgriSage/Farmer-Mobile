import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Trợ giúp & Hỗ trợ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact
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
                  const Icon(Icons.support_agent, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Tổng đài hỗ trợ', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(
                    'Hoạt động từ 8:00 - 18:00 (Thứ 2 đến Thứ 7)',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.phone),
                      label: const Text('Gọi 1900 1234'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Gửi phản hồi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // FAQ
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('CÂU HỎI THƯỜNG GẶP', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            ),
            _buildFaqItem('Làm sao để thanh toán công nợ?', 'Bạn có thể thanh toán công nợ bằng cách đến trực tiếp đại lý hoặc thanh toán qua mã QR trên ứng dụng.'),
            _buildFaqItem('Tính năng Khám cây AI có chính xác không?', 'Khám cây AI có độ chính xác trên 85% với các bệnh phổ biến trên lúa. Tuy nhiên, đây chỉ là kênh tham khảo, bạn nên nhờ đại lý tư vấn thêm.'),
            _buildFaqItem('Tôi muốn đổi đại lý khác được không?', 'Hiện tại một tài khoản nông dân chỉ được liên kết với một đại lý chính để tiện quản lý công nợ. Vui lòng liên hệ tổng đài để được hỗ trợ.'),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ExpansionTile(
        title: Text(question, style: AppTextStyles.labelLarge),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Text(answer, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
