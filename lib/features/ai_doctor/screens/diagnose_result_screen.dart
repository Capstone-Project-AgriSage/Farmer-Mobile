import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/mock/mock_diagnoses.dart';
import '../../../router/app_router.dart';

class DiagnoseResultScreen extends StatelessWidget {
  const DiagnoseResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy kết quả mock đầu tiên (Đạo ôn lá, 92%)
    final result = mockDiagnoses[0];
    final confidencePercent = (result.confidence * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Kết quả phân tích')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Detection Badge ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Đã phát hiện bệnh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Độ tin cậy: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('$confidencePercent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Confidence bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mức độ tin cậy AI', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                            Text('$confidencePercent / 100', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: result.confidence,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceSubtle,
                            valueColor: AlwaysStoppedAnimation(
                              result.confidence >= 0.85
                                  ? AppColors.statusSuccess
                                  : result.confidence >= 0.70
                                      ? const Color(0xFFF57F17)
                                      : AppColors.statusError,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Disease Info Card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7B1FA2).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.blur_on, color: Color(0xFF7B1FA2), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(result.diseaseName, style: AppTextStyles.h3),
                                  Text(result.diseaseNameEn, style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: AppColors.borderSubtle),
                        const SizedBox(height: 14),
                        Text(result.description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Symptoms ───────────────────────────────────────
                  _buildSection(
                    icon: Icons.visibility_outlined,
                    title: 'Triệu chứng nhận diện',
                    color: const Color(0xFFE65100),
                    children: result.symptoms
                        .map((s) => _buildBulletItem(s, const Color(0xFFE65100)))
                        .toList(),
                  ),
                  const SizedBox(height: 14),

                  // ── Cause ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bug_report_outlined, color: Color(0xFFC62828), size: 18),
                            const SizedBox(width: 8),
                            Text('Nguyên nhân', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFFC62828))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(result.cause, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Treatments ─────────────────────────────────────
                  _buildSection(
                    icon: Icons.medical_services_outlined,
                    title: 'Biện pháp xử lý',
                    color: AppColors.primary,
                    children: result.treatments.asMap().entries.map((e) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: e.key < result.treatments.length - 1 ? 10 : 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(child: Text('${e.key + 1}', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e.value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // ── AI Safety Notice ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE082))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFFF57F17), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kết quả chỉ mang tính tham khảo. Sản phẩm điều trị phải được đại lý chuyên môn duyệt trước khi áp dụng.',
                            style: AppTextStyles.caption.copyWith(color: const Color(0xFF5D4037), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Bottom Actions ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Chụp lại'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.borderStrong),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/ai-scan/suggestion-pending'),
                    icon: const Icon(Icons.local_florist, size: 18),
                    label: const Text('Xem thuốc gợi ý'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.labelLarge.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5))),
        ],
      ),
    );
  }
}
