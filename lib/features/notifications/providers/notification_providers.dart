import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/realtime_events.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

/// Số thông báo chưa đọc (chấm đỏ ở chuông). Đổi tài khoản thì tải lại.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

class NotificationListState {
  const NotificationListState({
    this.status,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  /// null = tất cả; hoặc [NotificationStatus.unread].
  final String? status;
  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get hasUnread => items.any((n) => !n.isRead);

  NotificationListState copyWith({
    String? Function()? status,
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) =>
      NotificationListState(
        status: status != null ? status() : this.status,
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error != null ? error() : this.error,
        loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
      );
}

/// Danh sách thông báo: lọc, cuộn vô hạn, đánh dấu đã đọc và xoá (cập nhật
/// ngay trên màn hình, lỗi thì hoàn lại).
class NotificationsController extends Notifier<NotificationListState> {
  int _generation = 0;

  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  NotificationListState build() {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    ref.listen(realtimeEventsProvider, (_, event) {
      final topic = event.valueOrNull;
      if (topic == 'notifications' || topic == 'resync') Future.microtask(_loadFirst);
    });
    Future.microtask(_loadFirst);
    return const NotificationListState();
  }

  Future<void> _loadFirst() async {
    final gen = ++_generation;
    state = state.copyWith(
        isLoading: true, isLoadingMore: false, error: () => null, loadMoreError: () => null);
    try {
      final page = await _repo.list(status: state.status);
      if (gen != _generation) return;
      state = state.copyWith(
          items: page.items, page: 1, hasMore: page.hasMore, isLoading: false);
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoading: false, error: () => e, items: const []);
    }
  }

  Future<void> setStatus(String? status) {
    if (status == state.status) return Future.value();
    state = state.copyWith(status: () => status, items: const []);
    return _loadFirst();
  }

  Future<void> refresh() async {
    await _loadFirst();
    ref.invalidate(unreadCountProvider);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final gen = _generation;
    state = state.copyWith(isLoadingMore: true, loadMoreError: () => null);
    try {
      final next = await _repo.list(page: state.page + 1, status: state.status);
      if (gen != _generation) return;
      final seen = state.items.map((e) => e.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...next.items.where((e) => !seen.contains(e.id))],
        page: next.page,
        hasMore: next.hasMore,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: () => e);
    }
  }

  List<AppNotification> _replace(String id, AppNotification Function(AppNotification) f) =>
      [for (final n in state.items) n.id == id ? f(n) : n];

  /// Đánh dấu một thông báo đã đọc. Thất bại thì hoàn lại; trả về lỗi (nếu có).
  Future<ApiException?> markRead(String id) async {
    final before = state.items;
    final target = before.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return null;
    state = state.copyWith(items: _replace(id, (n) => n.asRead()));
    try {
      await _repo.markRead(id);
      ref.invalidate(unreadCountProvider);
      return null;
    } catch (e) {
      state = state.copyWith(items: before);
      return ApiException.from(e);
    }
  }

  Future<ApiException?> markAllRead() async {
    final before = state.items;
    state = state.copyWith(items: [for (final n in before) n.asRead()]);
    try {
      await _repo.markAllRead();
      ref.invalidate(unreadCountProvider);
      return null;
    } catch (e) {
      state = state.copyWith(items: before);
      return ApiException.from(e);
    }
  }

  /// Xoá (lưu trữ) một thông báo. Thất bại thì đưa lại đúng chỗ cũ.
  Future<ApiException?> archive(String id) async {
    final before = state.items;
    state = state.copyWith(items: [for (final n in before) if (n.id != id) n]);
    try {
      await _repo.archive(id);
      ref.invalidate(unreadCountProvider);
      return null;
    } catch (e) {
      state = state.copyWith(items: before);
      return ApiException.from(e);
    }
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsController, NotificationListState>(
        NotificationsController.new);
