import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../notifications/data/notification_models.dart';
import '../../notifications/providers/notification_providers.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final s = ref.read(notificationsProvider);
      if (s.loadMoreError != null) return;
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(notificationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _readAll() async {
    final err = await ref.read(notificationsProvider.notifier).markAllRead();
    if (!mounted) return;
    _toast(err?.message ?? 'Đã đánh dấu tất cả là đã đọc');
  }

  Future<void> _archive(AppNotification n) async {
    final err = await ref.read(notificationsProvider.notifier).archive(n.id);
    if (!mounted) return;
    _toast(err?.message ?? 'Đã xoá thông báo');
  }

  Future<void> _open(AppNotification n) async {
    final route = n.route;
    final err = await ref.read(notificationsProvider.notifier).markRead(n.id);
    if (!mounted) return;
    if (err != null) _toast(err.message);
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            key: const Key('notif_read_all'),
            tooltip: 'Đánh dấu tất cả đã đọc',
            icon: const Icon(Icons.done_all),
            color: AppColors.textPrimary,
            onPressed: state.hasUnread ? _readAll : null,
          ),
        ],
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
                itemCount: NotificationStatus.filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final s = NotificationStatus.filters[i];
                  final active = s == state.status;
                  return Material(
                    key: Key('notif_filter_${s ?? 'all'}'),
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
                          child: Text(NotificationStatus.label(s),
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

  Widget _body(NotificationListState state, NotificationsController notifier) {
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerListWidget(itemCount: 5, itemHeight: 84),
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
                    ? 'Bạn không có thông báo nào'
                    : 'Không có thông báo chưa đọc',
                fallbackIcon: Icons.notifications_none,
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
          final n = state.items[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppColors.statusError,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (_) => _archive(n),
              child: _NotificationItem(
                notification: n,
                onTap: () => _open(n),
                onDelete: () => _archive(n),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _footer(NotificationListState state, NotificationsController notifier) {
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
          key: const Key('notif_load_more_retry'),
          onPressed: notifier.loadMore,
          icon: const Icon(Icons.refresh),
          label: const Text('Không tải thêm được. Thử lại'),
        ),
      );
    }
    if (state.hasMore) {
      return Center(
        child: TextButton(
          key: const Key('notif_load_more'),
          onPressed: notifier.loadMore,
          child: const Text('Xem thêm'),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem(
      {required this.notification, required this.onTap, required this.onDelete});

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final color = n.kind.color;
    return Material(
      color: n.isRead ? Colors.white : const Color(0xFFEFF9EF),
      child: InkWell(
      key: Key('notif_${n.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(n.kind.icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: n.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: Key('notif_dot_${n.id}'),
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.statusError,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: n.isRead ? AppColors.textMuted : AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatTimeAgo(n.createdAt),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('notif_delete_${n.id}'),
              tooltip: 'Xoá thông báo',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

