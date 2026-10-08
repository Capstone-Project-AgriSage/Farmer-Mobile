import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/order_labels.dart';
import '../../../core/labels/status_label.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../orders/data/order_models.dart';
import '../../orders/providers/order_providers.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  /// `null` is "Tất cả"; the rest are the order statuses the server can filter by.
  static final List<(String label, String? status)> _tabs = [
    ('Tất cả', null),
    for (final status in OrderStatus.filterable) (labelOf(orderStatusLabels, status).label, status),
  ];

  final _scroll = ScrollController();
  String? _status;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
        ref.read(orderListProvider(_status).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(orderListProvider(_status));
    try {
      await ref.read(orderListProvider(_status).future);
    } catch (_) {
      // The list shows its own error; the pull-to-refresh spinner just ends.
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderListProvider(_status));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Đơn hàng của tôi'),
      ),
      body: Column(
        children: [
          // Filter Tabs (Pill style)
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
                  final isActive = _status == status;
                  return GestureDetector(
                    onTap: () => setState(() => _status = status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1B5E20) : Colors.white,
                        border: Border.all(color: isActive ? const Color(0xFF1B5E20) : AppColors.borderSubtle),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isActive ? Colors.white : AppColors.textSecondary,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Order List
          Expanded(
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(orderListProvider(_status))),
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
                                const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  _status == null ? 'Bác chưa có đơn hàng nào' : 'Không có đơn hàng ở trạng thái này',
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
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return _Footer(
                          loading: state.loadingMore,
                          error: state.moreError?.message,
                          onRetry: () => ref.read(orderListProvider(_status).notifier).loadMore(),
                        );
                      }
                      return _OrderCard(order: state.items[index]);
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderListItem order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('#${order.orderNumber}', style: AppTextStyles.labelLarge)),
                const SizedBox(width: 8),
                StatusBadge(labelOf(orderStatusLabels, order.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatVnDateTime(order.createdAt), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${order.itemCount} sản phẩm · ${settlementLabel(order.settlementType)}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                Text(formatVnd(order.totalAmount), style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
              ],
            ),
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
      return const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (error != null) {
      return Column(
        children: [
          Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError), textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      );
    }
    return const SizedBox(height: 60);
  }
}
