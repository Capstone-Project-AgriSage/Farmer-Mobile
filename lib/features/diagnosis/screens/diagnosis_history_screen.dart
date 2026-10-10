import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/diagnosis_labels.dart';
import '../../../core/labels/status_label.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/diagnosis_models.dart';
import '../providers/diagnosis_providers.dart';

/// The farmer's earlier diagnosis cases, newest first.
class DiagnosisHistoryScreen extends ConsumerStatefulWidget {
  const DiagnosisHistoryScreen({super.key});

  @override
  ConsumerState<DiagnosisHistoryScreen> createState() => _DiagnosisHistoryScreenState();
}

class _DiagnosisHistoryScreenState extends ConsumerState<DiagnosisHistoryScreen> {
  /// `null` is "Tất cả".
  static final List<(String label, String? status)> _tabs = [
    ('Tất cả', null),
    for (final status in DiagnosisStatus.filterable) (labelOf(diagnosisStatusLabels, status).label, status),
  ];

  final _scroll = ScrollController();
  String? _status;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
        ref.read(diagnosisListProvider(_status).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(diagnosisListProvider(_status));
    try {
      await ref.read(diagnosisListProvider(_status).future);
    } catch (_) {
      // The list shows its own error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cases = ref.watch(diagnosisListProvider(_status));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/ai-scan'),
        ),
        title: const Text('Lịch sử chẩn đoán'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final (label, status) = _tabs[index];
                  final active = _status == status;
                  return GestureDetector(
                    onTap: () => setState(() => _status = status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF1B5E20) : Colors.white,
                        border: Border.all(color: active ? const Color(0xFF1B5E20) : AppColors.borderSubtle),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: active ? Colors.white : AppColors.textSecondary,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: cases.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(diagnosisListProvider(_status))),
              data: (state) {
                if (state.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 320,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.psychology_outlined, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  _status == null ? 'Bác chưa gửi ảnh nào để chẩn đoán' : 'Không có ca nào ở mục này',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: state.items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return _Footer(
                          loading: state.loadingMore,
                          error: state.moreError?.message,
                          onRetry: () => ref.read(diagnosisListProvider(_status).notifier).loadMore(),
                        );
                      }
                      return _CaseCard(item: state.items[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item});

  final DiagnosisCaseListItem item;

  @override
  Widget build(BuildContext context) {
    final verified = item.status == DiagnosisStatus.verified;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/ai-scan/cases/${item.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('#${item.caseNumber}', style: AppTextStyles.labelLarge)),
                const SizedBox(width: 8),
                StatusBadge(labelOf(diagnosisStatusLabels, item.status)),
              ],
            ),
            if (item.submittedAt != null) ...[
              const SizedBox(height: 4),
              Text(formatVnDateTime(item.submittedAt!), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
            if (verified) ...[
              const SizedBox(height: 10),
              Text(
                diseaseDisplayName(item.diseaseCode, fallback: item.diseaseName),
                style: AppTextStyles.h4.copyWith(color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.loading, required this.error, required this.onRetry});

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (error != null) {
      return Column(
        children: [
          Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError), textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      );
    }
    return const SizedBox(height: 40);
  }
}
