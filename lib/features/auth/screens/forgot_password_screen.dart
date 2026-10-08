import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

/// Quên mật khẩu. Backend chưa có API đặt lại mật khẩu (cần SMS OTP), nên màn này chỉ hướng dẫn liên hệ cửa hàng.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.support_agent_outlined, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text('Liên hệ cửa hàng để được hỗ trợ', style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Hiện chưa thể tự đặt lại mật khẩu trong ứng dụng. Bác vui lòng liên hệ trực tiếp cửa hàng AgriSage để '
              'nhân viên đặt lại mật khẩu giúp. Chức năng đặt lại bằng tin nhắn sẽ sớm ra mắt.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Về trang đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}
