import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class EmptyDataWidget extends StatelessWidget {
  final String message;
  final String? lottieAsset;
  final IconData? fallbackIcon;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const EmptyDataWidget({
    super.key,
    required this.message,
    this.lottieAsset,
    this.fallbackIcon = Icons.inbox_outlined,
    this.actionText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (lottieAsset != null)
              Lottie.asset(
                lottieAsset!,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
              )
            else
              _buildFallbackIcon(),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            if (actionText != null && onActionPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onActionPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: Size.zero,
                ),
                child: Text(actionText!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Icon(fallbackIcon, size: 64, color: AppColors.borderStrong),
    );
  }
}
