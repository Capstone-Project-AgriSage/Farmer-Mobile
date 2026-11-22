import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Thẻ chọn cây ở bước 1 màn chụp ảnh: hình minh hoạ cây, tên cây và số bệnh AI nhận được. Thẻ đang chọn có nền xanh
/// nhạt, viền xanh và dấu tích, để người dùng thấy ngay mình đang chụp cây nào.
class CropChoiceCard extends StatelessWidget {
  const CropChoiceCard({
    super.key,
    required this.code,
    required this.name,
    required this.selected,
    this.aiDiseaseCount = 0,
    this.onTap,
  });

  final String code;
  final String name;
  final bool selected;

  /// Số bệnh của cây mà mô hình AI đang dùng nhận được; 0 thì không hiện dòng này.
  final int aiDiseaseCount;

  /// null khi đang gửi ảnh: thẻ không bấm được.
  final VoidCallback? onTap;

  /// Ảnh minh hoạ của cây trong assets; cây chưa có ảnh thì hiện biểu tượng lá.
  static String imageOf(String code) => 'assets/images/crops/${code.toLowerCase()}.png';

  /// Nạp sẵn ảnh các cây khi mở màn chụp ảnh, để thẻ không hiện trống rồi mới có hình.
  static void precacheAll(BuildContext context, Iterable<String> codes) {
    for (final code in codes) {
      precacheImage(AssetImage(imageOf(code)), context, onError: (_, __) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderSubtle,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? AppColors.primary.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.05),
              blurRadius: selected ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            // fit expand: cột nội dung rộng bằng cả thẻ nên hình và chữ nằm đúng giữa (Stack mặc định dồn về góc trái).
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        imageOf(code),
                        width: 60,
                        height: 60,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.eco_outlined, size: 48, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: selected ? AppColors.primaryDark : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (aiDiseaseCount > 0) ...[
                        const SizedBox(height: 2),
                        // Thẻ hẹp (màn 320 px) thì thu nhỏ chữ thay vì cắt mất số bệnh.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'AI nhận $aiDiseaseCount bệnh',
                            maxLines: 1,
                            style: AppTextStyles.caption.copyWith(
                              color: selected ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.check, size: 15, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
