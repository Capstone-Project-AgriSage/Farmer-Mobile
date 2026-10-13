import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AiScanHomeScreen extends StatelessWidget {
  const AiScanHomeScreen({super.key});

  static const _diseases = [
    _DiseaseInfo('Đạo ôn lá', 'Leaf Blast', Icons.blur_on, Color(0xFF7B1FA2)),
    _DiseaseInfo('Bạc lá', 'Bacterial Leaf Blight', Icons.water_damage, Color(0xFF1565C0)),
    _DiseaseInfo('Khô vằn', 'Sheath Blight', Icons.texture, Color(0xFF795548)),
    _DiseaseInfo('Đốm nâu', 'Brown Spot', Icons.circle, Color(0xFFE65100)),
    _DiseaseInfo('Lá khoẻ mạnh', 'Healthy', Icons.eco, Color(0xFF2E7D32)),
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
              Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, size: 40, color: Colors.white)),
              const SizedBox(height: 16),
              Text('Chụp ảnh lá lúa', style: AppTextStyles.h3.copyWith(color: Colors.white)),
              const SizedBox(height: 6),
              Text('Chuyên gia xem ảnh và tư vấn cho bạn', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text('Chụp ảnh ngay', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFF7B1FA2)))),
            ]))),
        const SizedBox(height: 20),
        // AI safety notice
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10), border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE082)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cách hoạt động', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFFE65100))),
              const SizedBox(height: 4),
              Text('Ảnh của bạn được AI sàng lọc rồi chuyên gia của cửa hàng xem và kết luận. Bạn chỉ nhận kết quả sau khi chuyên gia xác nhận, kèm gợi ý điều trị và sản phẩm.', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5D4037))),
            ])),
          ])),
        const SizedBox(height: 20),
        Text('5 tình trạng có thể nhận diện', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 24 + MediaQuery.textScalerOf(context).scale(60), crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: _diseases.length,
          itemBuilder: (_, i) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: const Border.fromBorderSide(BorderSide(color: AppColors.borderSubtle))),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: _diseases[i].color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(_diseases[i].icon, color: _diseases[i].color, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_diseases[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelLarge.copyWith(fontSize: 12)),
                Text(_diseases[i].enName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
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