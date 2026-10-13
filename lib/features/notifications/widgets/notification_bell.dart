import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/notification_providers.dart';

/// Chuông thông báo kèm số chưa đọc. Chưa có thông báo đẩy nên tự hỏi lại định
/// kỳ và khi quay lại app; lỗi mạng thì không hiện số (không báo sai).
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({
    super.key,
    required this.route,
    @visibleForTesting this.pollInterval = const Duration(seconds: 60),
  });

  /// Màn thông báo để mở khi bấm.
  final String route;
  final Duration pollInterval;

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (mounted) ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const Key('bell'),
          tooltip: count > 0 ? 'Thông báo ($count chưa đọc)' : 'Thông báo',
          icon: Icon(
            count > 0 ? Icons.notifications : Icons.notifications_none_outlined,
            size: 28,
          ),
          color: AppColors.textPrimary,
          onPressed: () async {
            await context.push(widget.route);
            _refresh();
          },
        ),
        if (count > 0)
          Positioned(
            right: 0,
            top: 2,
            child: IgnorePointer(
              child: Container(
                key: const Key('bell_badge'),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusError,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
