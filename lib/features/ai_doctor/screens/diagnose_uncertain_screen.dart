import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

/// AI Safety Screen — khi confidence < threshold, KHÔNG đưa ra kết luận
class DiagnoseUncertainScreen extends StatelessWidget {
  const DiagnoseUncertainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Kết quả phân tích')),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        const SizedBox(height: 20),
        Container(width: 100, height: 100, decoration: const BoxDecoration(color: Color(0xFFFFF3E0), shape: BoxShape.circle),
          child: const Icon(Icons.help_outline, size: 56, color: Color(0xFFE65100))),
        const SizedBox(height: 24),
        Text('Chưa đủ chắc chắn', style: AppTextStyles.h2, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12), border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE082)))),
          child: Column(children: [
            const Icon(Icons.shield, color: Color(0xFFE65100), size: 28),
            const SizedBox(height: 8),
            Text('AI Safety Notice', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFFE65100))),
            const SizedBox(height: 8),
            Text('Độ tin cậy của AI dưới ngưỡng cho phép. Hệ thống không đưa ra kết luận để tránh gây hiểu nhầm và dẫn đến mua nhầm thuốc.', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5D4037)), textAlign: TextAlign.center),
          ])),
        const SizedBox(height: 24),
        Text('Gợi ý của chúng tôi', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        _SuggestionTile(icon: Icons.camera_alt_outlined, title: 'Chụp lại ảnh rõ hơn', desc: 'Đảm bảo ảnh sắc nét, đủ sáng, chụp gần lá bị bệnh.'),
        const SizedBox(height: 8),
        _SuggestionTile(icon: Icons.phone_outlined, title: 'Liên hệ đại lý', desc: 'Mô tả triệu chứng để được tư vấn trực tiếp từ chuyên gia.'),
        const Spacer(),
        ElevatedButton.icon(onPressed: () => context.pop(), icon: const Icon(Icons.camera_alt, size: 18), label: const Text('Chụp lại ảnh')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Về trang chủ')),
      ])),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _SuggestionTile({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(10), border: const Border.fromBorderSide(BorderSide(color: AppColors.borderSubtle))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
          Text(desc, style: AppTextStyles.caption),
        ])),
      ]));
  }
}