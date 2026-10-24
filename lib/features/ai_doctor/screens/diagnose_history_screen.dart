import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/diagnosis_models.dart';
import '../providers/diagnosis_providers.dart';
import '../widgets/diagnosis_widgets.dart';

class DiagnoseHistoryScreen extends ConsumerStatefulWidget {
  const DiagnoseHistoryScreen({super.key});

  @override
  ConsumerState<DiagnoseHistoryScreen> createState() => _DiagnoseHistoryScreenState();
}

class _DiagnoseHistoryScreenState extends ConsumerState<DiagnoseHistoryScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = ref.read(myDiagnosesProvider);
      if (s.loadMoreError != null) return;
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(myDiagnosesProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myDiagnosesProvider);
    final notifier = ref.read(myDiagnosesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Lịch sử khám cây'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: SizedBox(
              // Cao theo cỡ chữ hệ thống để chữ to không bị cắt.
              height: MediaQuery.textScalerOf(context).scale(20) + 20,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: DiagnosisStatus.filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = DiagnosisStatus.filters[i];
                  final active = s == state.status;
                  return Material(
                    key: Key('diag_filter_${s ?? 'all'}'),
                    color: active ? AppColors.primary : AppColors.surface,
                    shape: StadiumBorder(
                      side: BorderSide(
                          color: active ? AppColors.primary : AppColors.borderSubtle),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => notifier.setStatus(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          widthFactor: 1,
                          child: Text(DiagnosisStatus.label(s),
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 13,
                                color: active ? Colors.white : AppColors.textSecondary,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              )),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(child: _body(state, notifier)),
        ],
      ),
    );
  }

  Widget _body(DiagnosisListState state, MyDiagnosesController notifier) {
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerListWidget(itemCount: 4, itemHeight: 90),
      );
    }
    if (state.error != null) {
      return ErrorRetryWidget(error: state.error!, onRetry: notifier.refresh);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 400,
              child: EmptyDataWidget(
                message: state.status == null
                    ? 'Chưa có lịch sử khám cây.\nChụp ảnh lá lúa để bắt đầu.'
                    : 'Không có ca "${DiagnosisStatus.label(state.status)}".',
                fallbackIcon: Icons.search_off,
                actionText: state.status == null ? 'Chụp ảnh lá lúa' : null,
                onActionPressed:
                    state.status == null ? () => context.push(AppRoutes.imageCapture) : null,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i == state.items.length) return _footer(state, notifier);
          return _HistoryCard(item: state.items[i]);
        },
      ),
    );
  }

  Widget _footer(DiagnosisListState state, MyDiagnosesController notifier) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (state.loadMoreError != null) {
      return Center(
        child: TextButton.icon(
          key: const Key('diag_load_more_retry'),
          onPressed: notifier.loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Không tải thêm được. Thử lại'),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('diag_load_more'),
          onPressed: notifier.loadMore,
          child: const Text('Xem thêm'),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final DiagnosisSummary item;

  @override
  Widget build(BuildContext context) {
    // Có bệnh để hiện: kết quả AI (hoặc ca cũ đã được cửa hàng xác nhận).
    final hasDisease = item.diseaseDisplay != null;
    final uncertain = item.isUncertain;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: Key('diag_${item.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/ai-scan/case/${item.id}'),
          child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: !hasDisease
                    ? AppColors.surfaceSubtle
                    : uncertain
                        ? AppColors.statusWarningSurface
                        : AppColors.statusSuccessSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                !hasDisease
                    ? Icons.local_florist_outlined
                    : uncertain
                        ? Icons.help_outline_rounded
                        : Icons.eco,
                color: !hasDisease
                    ? AppColors.textMuted
                    : uncertain
                        ? AppColors.statusWarning
                        : AppColors.statusSuccess,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasDisease
                        ? uncertain
                            ? 'Có thể là ${item.diseaseDisplay!} (AI chưa chắc)'
                            : item.diseaseDisplay!
                        : item.caseNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasDisease
                        ? '${item.caseNumber} · ${formatDateTime(item.submittedAt)}'
                        : formatDateTime(item.submittedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  DiagnosisStatusBadge(item.status),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
