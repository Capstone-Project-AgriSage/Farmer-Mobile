import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

/// Welcome Screen — chọn Đăng nhập / Đăng ký
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Illustration
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: const Icon(Icons.eco_rounded, size: 76, color: Colors.white),
              ),
              const SizedBox(height: 32),

              Text('Chào mừng đến\nAgriSage', textAlign: TextAlign.center, style: AppTextStyles.h1),
              const SizedBox(height: 12),
              Text(
                'Hệ sinh thái nông nghiệp số — mua vật tư, chẩn đoán bệnh cây, quản lý công nợ.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.7),
              ),

              const Spacer(flex: 3),

              // Buttons
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Đăng nhập'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.register),
                child: const Text('Tạo tài khoản mới'),
              ),
              const SizedBox(height: 24),

              // Terms note
              Text(
                'Bằng cách tiếp tục, bạn đồng ý với\nĐiều khoản sử dụng và Chính sách bảo mật của AgriSage.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
