import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

// TODO: Implement SuggestionPendingScreen
class SuggestionPendingScreen extends StatelessWidget {
  const SuggestionPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text('SuggestionPendingScreen', style: AppTextStyles.h3)),
      body: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.construction_outlined, size: 64, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text('Đang phát triển...', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
        ]),
      ),
    );
  }
}
