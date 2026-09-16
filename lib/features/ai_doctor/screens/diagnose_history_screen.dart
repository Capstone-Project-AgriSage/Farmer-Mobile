import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/mock/mock_diagnoses.dart';
import '../../../data/models/diagnose.dart';

class DiagnoseHistoryScreen extends StatefulWidget {
  const DiagnoseHistoryScreen({super.key});
  @override
  State<DiagnoseHistoryScreen> createState() => _DiagnoseHistoryScreenState();
}

class _DiagnoseHistoryScreenState extends State<DiagnoseHistoryScreen> {
  int _selectedFilter = 0;
  static const _filters = ['Tất cả', 'Đã chẩn đoán', 'Không xác định'];

  List<DiagnoseRecord> get _filteredList {
    if (_selectedFilter == 0) return mockDiagnoses;
    if (_selectedFilter == 1) {
      return mockDiagnoses.where((d) => d.status != DiagnoseStatus.uncertain).toList();
    }
    return mockDiagnoses.where((d) => d.status == DiagnoseStatus.uncertain).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredList;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Lịch sử khám cây')),
      body: Column(
        children: [
          // ── Filter Tabs ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: List.generate(_filters.length, (i) {
                final selected = _selectedFilter == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primaryDark : AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primaryDark : AppColors.borderSubtle),
                      ),
                      child: Text(
                        _filters[i],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: selected ? Colors.white : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── Result Count ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('${list.length} kết quả', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off, size: 36, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Text('Chưa có lịch sử khám cây', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        Text('Chụp ảnh lá lúa để bắt đầu', style: AppTextStyles.caption),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _HistoryCard(record: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final DiagnoseRecord record;
  const _HistoryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final isUncertain = record.status == DiagnoseStatus.uncertain;
    final confidencePercent = (record.confidence * 100).toInt();

    return GestureDetector(
      onTap: () {
        if (isUncertain) {
          context.push('/ai-scan/uncertain');
        } else {
          context.push('/ai-scan/result');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUncertain
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFF7B1FA2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isUncertain ? Icons.help_outline : Icons.eco,
                color: isUncertain ? const Color(0xFFE65100) : const Color(0xFF7B1FA2),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.diseaseName,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontSize: 13,
                            color: isUncertain ? const Color(0xFFE65100) : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  if (!isUncertain) ...[
                    const SizedBox(height: 2),
                    Text(record.diseaseNameEn, style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Confidence
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _confidenceColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$confidencePercent%',
                          style: TextStyle(color: _confidenceColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date
                      Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(_formatDate(record.createdAt), style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Color get _confidenceColor {
    if (record.confidence >= 0.85) return AppColors.statusSuccess;
    if (record.confidence >= 0.70) return const Color(0xFFF57F17);
    return AppColors.statusError;
  }

  Widget _buildStatusBadge() {
    Color bg, fg;
    String text;
    switch (record.status) {
      case DiagnoseStatus.reviewed:
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF1B5E20);
        text = 'Đã gợi ý thuốc';
        break;
      case DiagnoseStatus.pendingReview:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        text = 'Chờ duyệt';
        break;
      case DiagnoseStatus.diagnosed:
        bg = const Color(0xFFE8F5E9);
        fg = AppColors.primary;
        text = 'Đã chẩn đoán';
        break;
      case DiagnoseStatus.uncertain:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        text = 'Không xác định';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
