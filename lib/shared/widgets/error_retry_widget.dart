import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/network/api_exception.dart';

/// Trạng thái lỗi tải dữ liệu kèm nút "Thử lại". Dùng chung cho mọi danh sách.
class ErrorRetryWidget extends StatelessWidget {
  const ErrorRetryWidget({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = ApiException.from(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              e.isConnectivity ? Icons.wifi_off_outlined : Icons.error_outline,
              size: 56,
              color: AppColors.borderStrong,
            ),
            const SizedBox(height: 16),
            Text(
              e.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
