import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../data/order_models.dart';
import '../data/order_repository.dart';

final orderDetailProvider = FutureProvider.autoDispose
    .family<OrderDetail, String>((ref, id) => ref.watch(orderRepositoryProvider).get(id));

final orderPaymentsProvider = FutureProvider.autoDispose
    .family<OrderPayments, String>(
        (ref, id) => ref.watch(orderRepositoryProvider).payments(id));

final orderDeliveriesProvider = FutureProvider.autoDispose
    .family<List<Delivery>, String>(
        (ref, id) => ref.watch(orderRepositoryProvider).deliveries(id));

/// Hạn mức mua ghi nợ; null = chưa được cấp. Đổi tài khoản thì tải lại.
final myCreditProvider = FutureProvider.autoDispose<CreditSummary?>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(creditRepositoryProvider).mine();
});

class OrderListState {
  const OrderListState({
    this.status,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  /// null = tất cả trạng thái.
  final String? status;
  final List<OrderSummary> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  OrderListState copyWith({
    String? Function()? status,
    List<OrderSummary>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) =>
      OrderListState(
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

/// Danh sách đơn của tôi: lọc trạng thái + cuộn vô hạn. Đổi tài khoản thì
/// danh sách tự tải lại.
class MyOrdersController extends Notifier<OrderListState> {
  int _generation = 0;

  OrderRepository get _repo => ref.read(orderRepositoryProvider);

  @override
  OrderListState build() {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    Future.microtask(_loadFirst);
    return const OrderListState();
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

  Future<void> refresh() => _loadFirst();

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final gen = _generation;
    state = state.copyWith(isLoadingMore: true, loadMoreError: () => null);
    try {
      final next = await _repo.list(page: state.page + 1, status: state.status);
      if (gen != _generation) return;
      final seen = state.items.map((o) => o.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...next.items.where((o) => !seen.contains(o.id))],
        page: next.page,
        hasMore: next.hasMore,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: () => e);
    }
  }
}

final myOrdersProvider =
    NotifierProvider<MyOrdersController, OrderListState>(MyOrdersController.new);
