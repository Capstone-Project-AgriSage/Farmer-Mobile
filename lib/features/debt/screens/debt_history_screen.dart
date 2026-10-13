import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/data/order_models.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/debt_models.dart';
import '../providers/debt_providers.dart';

class DebtHistoryScreen extends ConsumerStatefulWidget {
  const DebtHistoryScreen({super.key});

  @override
  ConsumerState<DebtHistoryScreen> createState() => _DebtHistoryScreenState();
}

class _DebtHistoryScreenState extends ConsumerState<DebtHistoryScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = ref.read(debtRepaymentsProvider);
      if (s.loadMoreError != null) return;
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(debtRepaymentsProvider.notifier).loadMore();
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
    final state = ref.watch(debtRepaymentsProvider);
    final notifier = ref.read(debtRepaymentsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Lịch sử thanh toán')),
      body: _body(state, notifier),
    );
  }

  Widget _body(RepaymentsState state, DebtRepaymentsController notifier) {
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
          children: const [
            SizedBox(
              height: 400,
              child: EmptyDataWidget(
                message: 'Chưa có lần trả nợ nào.',
                fallbackIcon: Icons.history,
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
          return _PaymentCard(payment: state.items[i]);
        },
      ),
    );
  }

  Widget _footer(RepaymentsState state, DebtRepaymentsController notifier) {
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
          key: const Key('repayments_load_more_retry'),
          onPressed: notifier.loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Không tải thêm được. Thử lại'),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('repayments_load_more'),
          onPressed: notifier.loadMore,
          child: const Text('Xem thêm'),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final DebtPayment payment;

  @override
  Widget build(BuildContext context) {
    final paid = payment.status == PaymentStatus.paid;
    final pending = payment.status == PaymentStatus.pending;
    final (icon, fg, bg) = paid
        ? (Icons.arrow_downward, AppColors.statusSuccess, AppColors.statusSuccessSurface)
        : pending
            ? (Icons.hourglass_empty, AppColors.statusWarning, AppColors.statusWarningSurface)
            : (Icons.close, AppColors.statusError, AppColors.statusErrorSurface);
    return Container(
      key: Key('repayment_${payment.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trả nợ ${payment.paymentNumber}',
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 4),
                Text(PaymentMethod.label(payment.method),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(text: PaymentStatus.label(payment.status), fg: fg, bg: bg),
                    Text(formatDateTime(payment.when),
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatVnd(payment.amount),
              style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: paid ? AppColors.statusSuccess : AppColors.textPrimary)),
        ],
      ),
    );
  }
}
