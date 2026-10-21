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

  static List<BoxShadow> get _shadow => [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 4)),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text('Bác sĩ cây trồng AI', style: AppTextStyles.h3),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Lịch sử khám cây',
            icon: const Icon(Icons.history_outlined),
            onPressed: () => context.push('/ai-scan/history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(context),
            const SizedBox(height: 16),
            _notice(),
            const SizedBox(height: 24),
            Text('5 tình trạng có thể nhận diện', style: AppTextStyles.h4),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 28 + MediaQuery.textScalerOf(context).scale(60),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _diseases.length,
              itemBuilder: (_, i) => _diseaseTile(_diseases[i]),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('scan_start'),
            onTap: () => context.push('/ai-scan/capture'),
            child: Stack(
              children: [
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text('Chụp ảnh lá lúa',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h3.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('AI cho biết bệnh và cách xử lý ngay',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_camera_outlined,
                                size: 18, color: AppColors.primaryDark),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('Chụp ảnh ngay',
                                  style: AppTextStyles.labelLarge
                                      .copyWith(color: AppColors.primaryDark)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cách hoạt động',
                    style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFFE65100))),
                const SizedBox(height: 4),
                Text(
                    'AI phân tích ảnh và cho kết quả ngay, kèm cách xử lý và sản phẩm gợi ý khi AI chắc chắn. Khi AI chưa chắc, bạn được khuyên chụp lại hoặc hỏi cửa hàng. Kết quả chỉ để tham khảo.',
                    style:
                        AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5D4037))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diseaseTile(_DiseaseInfo d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: d.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(d.icon, color: d.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                Text(d.enName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
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
