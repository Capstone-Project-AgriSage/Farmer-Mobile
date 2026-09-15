import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class DebtDetailScreen extends StatelessWidget {
  final String debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text('Chi tiết khoản nợ', style: AppTextStyles.h3)),
      body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.construction_outlined, size: 64, color: AppColors.textMuted),
        SizedBox(height: 16),
        Text('Đang phát triển...', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
      ])),
    );
  }
}
