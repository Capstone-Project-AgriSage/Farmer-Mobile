import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class SuggestionPendingScreen extends StatelessWidget {
  const SuggestionPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Gợi ý sản phẩm')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Animated Hourglass ─────────────────────────────────
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFFF3E0).withOpacity(0.5), blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.hourglass_top_rounded, size: 48, color: Color(0xFFE65100)),
            ),
            const SizedBox(height: 24),

            Text('Đang chờ đại lý duyệt', style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Đại lý đang xem xét kết quả chẩn đoán và\nchọn sản phẩm phù hợp cho bạn.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ── Disease Summary Mini Card ──────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
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
                        Text('Bệnh đã chẩn đoán', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text('Đạo ôn lá (Rice Blast)', style: AppTextStyles.labelLarge),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('92%', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Timeline Steps ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  _TimelineStep(
                    icon: Icons.auto_awesome,
                    title: 'AI đã chẩn đoán',
                    subtitle: 'Đạo ôn lá — 92% confidence',
                    isCompleted: true,
                    isLast: false,
                  ),
                  _TimelineStep(
                    icon: Icons.hourglass_top,
                    title: 'Đang chờ đại lý',
                    subtitle: 'Đại lý xem xét và chọn thuốc phù hợp',
                    isCompleted: false,
                    isCurrent: true,
                    isLast: false,
                  ),
                  _TimelineStep(
                    icon: Icons.local_florist,
                    title: 'Đại lý đã gợi ý',
                    subtitle: 'Bạn sẽ nhận được danh sách thuốc',
                    isCompleted: false,
                    isLast: true,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Info Notice ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bạn sẽ nhận được thông báo khi đại lý hoàn tất duyệt sản phẩm.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Buttons ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/ai-scan/suggestion'),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Xem gợi ý (Demo)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/ai-scan/history'),
                    child: const Text('Xem lịch sử'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.borderStrong),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('Về trang chủ'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.borderStrong),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isCurrent = false,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + Line
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.statusSuccess
                      : isCurrent
                          ? const Color(0xFFE65100)
                          : AppColors.surfaceDim,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : icon,
                  color: (isCompleted || isCurrent) ? Colors.white : AppColors.textMuted,
                  size: 16,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted ? AppColors.statusSuccess : AppColors.surfaceDim,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: (isCompleted || isCurrent) ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
