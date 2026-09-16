import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Điều khoản sử dụng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chào mừng đến với AgriSage', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            Text(
              'Bằng việc tải, cài đặt và sử dụng ứng dụng AgriSage, bạn đồng ý với các điều khoản sau đây:',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Dịch vụ của chúng tôi',
              'AgriSage cung cấp nền tảng kết nối nông dân với đại lý vật tư nông nghiệp, hỗ trợ quản lý mua bán, công nợ và cung cấp công cụ nhận diện bệnh cây trồng bằng AI.',
            ),
            _buildSection(
              '2. Tài khoản người dùng',
              'Bạn có trách nhiệm bảo mật thông tin đăng nhập và mọi hoạt động diễn ra dưới tài khoản của mình. Vui lòng cung cấp thông tin chính xác khi đăng ký.',
            ),
            _buildSection(
              '3. Công nợ và Thanh toán',
              'Các giao dịch mua bán chịu (công nợ) phải được sự xác nhận của cả nông dân và đại lý. AgriSage chỉ đóng vai trò ghi nhận và nhắc nhở, không chịu trách nhiệm giải quyết tranh chấp tài chính.',
            ),
            _buildSection(
              '4. Tính năng Khám cây AI',
              'Kết quả chẩn đoán bệnh từ AI chỉ mang tính chất tham khảo. Người dùng nên tham khảo ý kiến chuyên môn từ đại lý trước khi quyết định mua thuốc điều trị.',
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Cập nhật lần cuối: 15/09/2026',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}
