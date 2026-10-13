import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/return_models.dart';
import '../providers/return_providers.dart';
import '../widgets/return_widgets.dart';

class ReturnListScreen extends ConsumerStatefulWidget {
  const ReturnListScreen({super.key});

  @override
  ConsumerState<ReturnListScreen> createState() => _ReturnListScreenState();
}

class _ReturnListScreenState extends ConsumerState<ReturnListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = ref.read(myReturnsProvider);
      if (s.loadMoreError != null) return;
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(myReturnsProvider.notifier).loadMore();
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
    final state = ref.watch(myReturnsProvider);
    final notifier = ref.read(myReturnsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Yêu cầu trả hàng')),
      body: _body(state, notifier),
    );
  }

  Widget _body(ReturnListState state, MyReturnsController notifier) {
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerListWidget(itemCount: 4, itemHeight: 100),
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
          children: const [
            SizedBox(
              height: 400,
              child: EmptyDataWidget(
                message:
                    'Bạn chưa có yêu cầu trả hàng nào.\nĐể trả hàng, mở đơn hàng đã nhận và chọn "Yêu cầu trả hàng".',
                fallbackIcon: Icons.assignment_return_outlined,
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
          return _ReturnCard(item: state.items[i]);
        },
      ),
    );
  }

  Widget _footer(ReturnListState state, MyReturnsController notifier) {
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
          key: const Key('returns_load_more_retry'),
          onPressed: notifier.loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Không tải thêm được. Thử lại'),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('returns_load_more'),
          onPressed: notifier.loadMore,
          child: const Text('Xem thêm'),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({required this.item});

  final ReturnSummary item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('return_${item.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/returns/${item.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                const Icon(Icons.assignment_return_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.returnNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge),
                ),
                const SizedBox(width: 8),
                ReturnStatusBadge(item.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('Đơn hàng ${item.orderNumber}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(formatDateTime(item.requestedAt),
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                Text(formatVnd(item.totalReturnAmount),
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
