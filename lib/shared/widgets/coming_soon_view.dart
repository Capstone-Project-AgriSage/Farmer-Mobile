import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Nội dung cho tính năng chưa có API ở backend: nói thẳng là "Sắp ra mắt"
/// thay vì hiện dữ liệu mẫu như thật.
class ComingSoonView extends StatelessWidget {
  const ComingSoonView({
    super.key,
    required this.message,
    this.title = 'Sắp ra mắt',
    this.icon = Icons.hourglass_top_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                key: const Key('coming_soon_title'),
                textAlign: TextAlign.center,
                style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              message,
              key: const Key('coming_soon_message'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Màn hình đầy đủ (có thanh tiêu đề) cho một tính năng sắp ra mắt.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.message, this.icon});

  final String title;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text(title)),
      body: ComingSoonView(
        message: message,
        icon: icon ?? Icons.hourglass_top_rounded,
      ),
    );
  }
}
