import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/realtime_events.dart';
import '../data/diagnosis_models.dart';
import '../data/diagnosis_repository.dart';

final diagnosisDetailProvider = FutureProvider.autoDispose
    .family<DiagnosisCase, String>(
        (ref, id) => ref.watch(diagnosisRepositoryProvider).get(id));

class DiagnosisListState {
  const DiagnosisListState({
    this.status,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  /// null = tất cả; hoặc một giá trị của [DiagnosisStatus.filters].
  final String? status;
  final List<DiagnosisSummary> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  DiagnosisListState copyWith({
    String? Function()? status,
    List<DiagnosisSummary>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? Function()? error,
    Object? Function()? loadMoreError,
  }) =>
      DiagnosisListState(
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

/// Lịch sử chẩn đoán: lọc trạng thái + cuộn vô hạn. Đổi tài khoản thì tải lại.
class MyDiagnosesController extends Notifier<DiagnosisListState> {
  int _generation = 0;

  DiagnosisRepository get _repo => ref.read(diagnosisRepositoryProvider);

  @override
  DiagnosisListState build() {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    ref.listen(realtimeEventsProvider, (_, event) {
      if (event.valueOrNull == 'diagnosis' || event.valueOrNull == 'resync') Future.microtask(_loadFirst);
    });
    Future.microtask(_loadFirst);
    return const DiagnosisListState();
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

final myDiagnosesProvider =
    NotifierProvider<MyDiagnosesController, DiagnosisListState>(
        MyDiagnosesController.new);
