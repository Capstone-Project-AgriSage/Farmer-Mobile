import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../data/return_models.dart';
import '../data/return_repository.dart';

final returnableProvider = FutureProvider.autoDispose
    .family<Returnable, String>(
        (ref, orderId) => ref.watch(returnRepositoryProvider).returnable(orderId));

final returnDetailProvider = FutureProvider.autoDispose
    .family<ReturnDetail, String>(
        (ref, id) => ref.watch(returnRepositoryProvider).get(id));

class ReturnListState {
  const ReturnListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<ReturnSummary> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  ReturnListState copyWith({
    List<ReturnSummary>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) =>
      ReturnListState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: error != null ? error() : this.error,
        loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
      );
}

/// Danh sách yêu cầu trả hàng, cuộn vô hạn. Đổi tài khoản thì tải lại.
class MyReturnsController extends Notifier<ReturnListState> {
  int _generation = 0;

  ReturnRepository get _repo => ref.read(returnRepositoryProvider);

  @override
  ReturnListState build() {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    Future.microtask(_loadFirst);
    return const ReturnListState();
  }

  Future<void> _loadFirst() async {
    final gen = ++_generation;
    state = state.copyWith(
        isLoading: true, isLoadingMore: false, error: () => null, loadMoreError: () => null);
    try {
      final page = await _repo.list();
      if (gen != _generation) return;
      state = state.copyWith(
          items: page.items, page: 1, hasMore: page.hasMore, isLoading: false);
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoading: false, error: () => e, items: const []);
    }
  }

  Future<void> refresh() => _loadFirst();

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final gen = _generation;
    state = state.copyWith(isLoadingMore: true, loadMoreError: () => null);
    try {
      final next = await _repo.list(page: state.page + 1);
      if (gen != _generation) return;
      final seen = state.items.map((r) => r.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...next.items.where((r) => !seen.contains(r.id))],
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

final myReturnsProvider =
    NotifierProvider<MyReturnsController, ReturnListState>(MyReturnsController.new);
