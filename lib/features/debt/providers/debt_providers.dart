import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../data/debt_models.dart';
import '../data/debt_repository.dart';

/// Tài khoản công nợ; null = chưa có. Đổi tài khoản thì tải lại.
final debtAccountProvider = FutureProvider.autoDispose<DebtAccount?>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(debtRepositoryProvider).account();
});

/// Có khoản nợ quá hạn không (chấm đỏ ở tab Công nợ). Lỗi/đang tải = không báo.
final hasOverdueDebtProvider = Provider.autoDispose<bool>(
    (ref) => ref.watch(debtAccountProvider).valueOrNull?.hasOverdue ?? false);

/// Vài khoản nợ chưa trả sắp đến hạn nhất (màn tổng quan).
final upcomingDebtsProvider =
    FutureProvider.autoDispose<List<DebtEntrySummary>>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(debtRepositoryProvider).upcoming();
});

final debtEntryProvider = FutureProvider.autoDispose
    .family<DebtEntryDetail, String>(
        (ref, id) => ref.watch(debtRepositoryProvider).entry(id));

/// Xem trước phân bổ cho một số tiền nguyên đồng.
final allocationPreviewProvider = FutureProvider.autoDispose
    .family<AllocationPreview, int>(
        (ref, amount) => ref.watch(debtRepositoryProvider).preview(amount.toDouble()));

/// Làm mới mọi số liệu công nợ sau khi trả nợ / khiếu nại.
void invalidateDebt(WidgetRef ref) {
  ref
    ..invalidate(debtAccountProvider)
    ..invalidate(upcomingDebtsProvider)
    ..invalidate(myDebtEntriesProvider)
    ..invalidate(debtRepaymentsProvider);
}

class DebtListState {
  const DebtListState({
    this.status,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  /// null = tất cả; hoặc một giá trị của [DebtStatus.filters].
  final String? status;
  final List<DebtEntrySummary> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  DebtListState copyWith({
    String? Function()? status,
    List<DebtEntrySummary>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) =>
      DebtListState(
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

/// Danh sách khoản nợ: lọc trạng thái + cuộn vô hạn.
class MyDebtEntriesController extends Notifier<DebtListState> {
  int _generation = 0;

  DebtRepository get _repo => ref.read(debtRepositoryProvider);

  @override
  DebtListState build() {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    Future.microtask(_loadFirst);
    return const DebtListState();
  }

  Future<void> _loadFirst() async {
    final gen = ++_generation;
    state = state.copyWith(
        isLoading: true, isLoadingMore: false, error: () => null, loadMoreError: () => null);
    try {
      final page = await _repo.entries(status: state.status);
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
      final next = await _repo.entries(page: state.page + 1, status: state.status);
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
}

final myDebtEntriesProvider =
    NotifierProvider<MyDebtEntriesController, DebtListState>(
        MyDebtEntriesController.new);

class RepaymentsState {
  const RepaymentsState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<DebtPayment> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  RepaymentsState copyWith({
    List<DebtPayment>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) =>
      RepaymentsState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error != null ? error() : this.error,
        loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
      );
}

/// Lịch sử trả nợ. Backend trộn thanh toán đơn hàng và trả nợ trong một danh
/// sách nên trang gốc có thể không chứa lần trả nợ nào: tự lấy tiếp trang sau
/// (tối đa [_maxPagesPerLoad] trang mỗi lần) cho đến khi có dữ liệu.
class DebtRepaymentsController extends Notifier<RepaymentsState> {
  static const _maxPagesPerLoad = 5;
  int _generation = 0;

  DebtRepository get _repo => ref.read(debtRepositoryProvider);

  @override
  RepaymentsState build() {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    Future.microtask(_loadFirst);
    return const RepaymentsState();
  }

  Future<void> _loadFirst() async {
    final gen = ++_generation;
    state = state.copyWith(
        isLoading: true, isLoadingMore: false, error: () => null, loadMoreError: () => null);
    try {
      final r = await _fetch(from: 1, existing: const []);
      if (gen != _generation) return;
      state = state.copyWith(
          items: r.items, page: r.page, hasMore: r.hasMore, isLoading: false);
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoading: false, error: () => e, items: const []);
    }
  }

  Future<({List<DebtPayment> items, int page, bool hasMore})> _fetch(
      {required int from, required List<DebtPayment> existing}) async {
    final items = [...existing];
    var page = from - 1;
    var hasMore = true;
    for (var i = 0; i < _maxPagesPerLoad && hasMore; i++) {
      final r = await _repo.repayments(page: page + 1);
      page = r.page;
      hasMore = r.hasMore;
      final seen = items.map((p) => p.id).toSet();
      items.addAll(r.items.where((p) => !seen.contains(p.id)));
      if (r.items.isNotEmpty) break;
    }
    return (items: items, page: page, hasMore: hasMore);
  }

  Future<void> refresh() => _loadFirst();

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final gen = _generation;
    state = state.copyWith(isLoadingMore: true, loadMoreError: () => null);
    try {
      final r = await _fetch(from: state.page + 1, existing: state.items);
      if (gen != _generation) return;
      state = state.copyWith(
          items: r.items, page: r.page, hasMore: r.hasMore, isLoadingMore: false);
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: () => e);
    }
  }
}

final debtRepaymentsProvider =
    NotifierProvider<DebtRepaymentsController, RepaymentsState>(
        DebtRepaymentsController.new);
