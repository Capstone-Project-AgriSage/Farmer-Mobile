import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/diagnosis_models.dart';

class DiagnosisStatusBadge extends StatelessWidget {
  const DiagnosisStatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = DiagnosisStatus.colors(status);
    return StatusChip(text: DiagnosisStatus.label(status), fg: fg, bg: bg);
  }
}

/// Ảnh của ca chẩn đoán (URL có chữ ký, có thể đã hết hạn → hiện khung thay thế).
class DiagnosisPhoto extends StatelessWidget {
  const DiagnosisPhoto({super.key, required this.url, this.height = 220});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget fallback(String text) => Container(
          height: height,
          color: AppColors.surfaceSubtle,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined,
                  size: 36, color: AppColors.borderStrong),
              const SizedBox(height: 6),
              Text(text,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.isEmpty
          ? fallback('Không có ảnh')
          : CachedNetworkImage(
              imageUrl: url,
              cacheKey: url.split('?').first,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: height,
                color: AppColors.surfaceSubtle,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => fallback('Không tải được ảnh'),
            ),
    );
  }
}
