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
      appBar: AppBar(title: const Text('Lịch sử khám cây')),
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
                itemCount: DiagnosisStatus.filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = DiagnosisStatus.filters[i];
                  final active = s == state.status;
                  return ChoiceChip(
                    key: Key('diag_filter_${s ?? 'all'}'),
                    label: Text(DiagnosisStatus.label(s)),
                    selected: active,
                    showCheckmark: false,
                    selectedColor: AppColors.primaryDark,
                    labelStyle: AppTextStyles.bodySmall.copyWith(
                      color: active ? Colors.white : AppColors.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                    onSelected: (_) => notifier.setStatus(s),
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
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    final verified = item.status == DiagnosisStatus.verified;
    return InkWell(
      key: Key('diag_${item.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/ai-scan/case/${item.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: verified ? AppColors.statusSuccessSurface : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                verified ? Icons.eco : Icons.local_florist_outlined,
                color: verified ? AppColors.statusSuccess : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verified && item.diseaseDisplay != null
                        ? item.diseaseDisplay!
                        : item.caseNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    verified && item.diseaseDisplay != null
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
