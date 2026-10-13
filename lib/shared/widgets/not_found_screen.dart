import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../router/app_router.dart';

/// Hiện khi mở một đường dẫn không tồn tại (liên kết cũ/sai).
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_off_outlined, size: 64, color: AppColors.borderStrong),
                const SizedBox(height: 16),
                Text('Không tìm thấy trang',
                    key: const Key('not_found_title'), style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  'Đường dẫn bạn mở không tồn tại hoặc đã bị gỡ.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('not_found_home'),
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
