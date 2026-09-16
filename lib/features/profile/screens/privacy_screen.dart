import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Chính sách bảo mật')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: AppColors.statusSuccess, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AgriSage cam kết bảo vệ thông tin cá nhân và dữ liệu nông nghiệp của bạn.',
                      style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF1B5E20), fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Dữ liệu chúng tôi thu thập',
              '• Thông tin cá nhân: Họ tên, số điện thoại, địa chỉ khi bạn đăng ký.\n'
              '• Dữ liệu giao dịch: Đơn hàng, lịch sử công nợ giữa bạn và đại lý.\n'
              '• Dữ liệu hình ảnh: Ảnh lá cây, đồng ruộng khi bạn sử dụng tính năng AI.',
            ),
            _buildSection(
              '2. Cách sử dụng dữ liệu',
              'AgriSage sử dụng thông tin để quản lý tài khoản, hỗ trợ giao dịch mua bán, và nhắc nhở công nợ. Riêng hình ảnh cây trồng được dùng để phân tích bệnh và có thể được ẩn danh để huấn luyện AI tốt hơn.',
            ),
            _buildSection(
              '3. Chia sẻ thông tin',
              'Thông tin cá nhân và công nợ của bạn chỉ được chia sẻ duy nhất với Đại lý mà bạn kết nối. Chúng tôi tuyệt đối không bán dữ liệu cho bên thứ ba.',
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
