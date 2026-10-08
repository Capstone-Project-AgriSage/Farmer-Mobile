import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../network/app_exception.dart';

/// A centred error message with a "Thử lại" button. Offline and timeout errors get a Wi-Fi icon.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({super.key, required this.error, this.onRetry, this.light = false});

  final Object error;
  final VoidCallback? onRetry;

  /// White text, for use on the green splash background.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final offline = error is AppException &&
        ((error as AppException).kind == AppErrorKind.offline || (error as AppException).kind == AppErrorKind.timeout);
    final foreground = light ? Colors.white : AppColors.textSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline,
              size: 48,
              color: light ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              messageOf(error),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: foreground),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
                style: light
                    ? OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
