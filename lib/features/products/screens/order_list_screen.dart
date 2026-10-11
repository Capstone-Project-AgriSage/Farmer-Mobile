import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/data/order_models.dart';
import '../../orders/providers/order_providers.dart';
import '../../orders/widgets/order_widgets.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = ref.read(myOrdersProvider);
      if (s.loadMoreError != null) return;
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(myOrdersProvider.notifier).loadMore();
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
    final state = ref.watch(myOrdersProvider);
    final notifier = ref.read(myOrdersProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        title: const Text('Đơn hàng của tôi'),
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
                itemCount: OrderStatus.filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = OrderStatus.filters[i];
                  final active = s == state.status;
                  return ChoiceChip(
                    key: Key('order_filter_${s ?? 'all'}'),
                    label: Text(OrderStatus.label(s)),
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

  Widget _body(OrderListState state, MyOrdersController notifier) {
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerListWidget(itemCount: 4, itemHeight: 120),
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
                    ? 'Bạn chưa có đơn hàng nào.'
                    : 'Không có đơn hàng "${OrderStatus.label(state.status)}".',
                fallbackIcon: Icons.receipt_long_outlined,
                actionText: state.status == null ? 'Mua sắm ngay' : null,
                onActionPressed: state.status == null
                    ? () => context.go(AppRoutes.products)
                    : null,
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
          return _OrderCard(order: state.items[i]);
        },
      ),
    );
  }

  Widget _footer(OrderListState state, MyOrdersController notifier) {
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
          key: const Key('orders_load_more_retry'),
          onPressed: notifier.loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Không tải thêm được. Thử lại'),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('orders_load_more'),
          onPressed: notifier.loadMore,
          child: const Text('Xem thêm'),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('order_${order.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/orders/${order.id}'),
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
              children: [
                Expanded(
                  child: Text(order.orderNumber,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                OrderStatusBadge(order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(formatDateTime(order.createdAt),
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const Divider(height: 24, color: AppColors.borderSubtle),
            Row(
              children: [
                Icon(
                    order.fulfillmentType == FulfillmentType.pickup
                        ? Icons.storefront_outlined
                        : Icons.local_shipping_outlined,
                    size: 16,
                    color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${FulfillmentType.label(order.fulfillmentType)} · '
                    '${SettlementType.label(order.settlementType)} · '
                    '${order.itemCount} sản phẩm',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Tổng tiền',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const Spacer(),
                Text(formatVnd(order.totalAmount),
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
