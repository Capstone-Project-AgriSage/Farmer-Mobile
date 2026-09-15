import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class AiScanHomeScreen extends StatelessWidget {
  const AiScanHomeScreen({super.key});

  static const _diseases = [
    _DiseaseInfo('Đạo ôn lá', 'Blast', Icons.blur_on, Color(0xFF7B1FA2)),
    _DiseaseInfo('Bạc lá', 'Bacterial Leaf Blight', Icons.water_damage, Color(0xFF1565C0)),
    _DiseaseInfo('Khô vằn', 'Sheath Blight', Icons.texture, Color(0xFF795548)),
    _DiseaseInfo('Đốm nâu', 'Brown Spot', Icons.circle, Color(0xFFE65100)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text('Bác sĩ cây trồng AI', style: AppTextStyles.h3),
        actions: [IconButton(icon: const Icon(Icons.history_outlined), onPressed: () => context.push('/ai-scan/history'))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero scan button
        GestureDetector(onTap: () => context.push('/ai-scan/capture'),
          child: Container(padding: const EdgeInsets.all(24), width: double.infinity,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, size: 40, color: Colors.white)),
              const SizedBox(height: 16),
              Text('Chụp ảnh lá lúa', style: AppTextStyles.h3.copyWith(color: Colors.white)),
              const SizedBox(height: 6),
              Text('AI nhận diện bệnh trong vài giây', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text('Bắt đầu quét', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFF7B1FA2)))),
            ]))),
        const SizedBox(height: 20),
        // AI safety notice
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10), border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE082)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lưu ý về AI Safety', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFFE65100))),
              const SizedBox(height: 4),
              Text('Khi AI không đủ tự tin, hệ thống sẽ thông báo thay vì đưa ra kết luận sai. Mọi gợi ý sản phẩm phải được đại lý duyệt trước.', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5D4037))),
            ])),
          ])),
        const SizedBox(height: 20),
        Text('4 bệnh AI có thể nhận diện', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.6, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: _diseases.length,
          itemBuilder: (_, i) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: const Border.fromBorderSide(BorderSide(color: AppColors.borderSubtle))),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: _diseases[i].color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(_diseases[i].icon, color: _diseases[i].color, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_diseases[i].name, style: AppTextStyles.labelLarge.copyWith(fontSize: 12)),
                Text(_diseases[i].enName, style: AppTextStyles.caption),
              ])),
            ]))),
        const SizedBox(height: 80),
      ])),
    );
  }
}

class _DiseaseInfo {
  final String name;
  final String enName;
  final IconData icon;
  final Color color;
  const _DiseaseInfo(this.name, this.enName, this.icon, this.color);
}