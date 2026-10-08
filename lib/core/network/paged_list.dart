import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_exception.dart';
import 'paged.dart';

/// The pages loaded so far, and what is happening to the next one.
class PagedListState<T> {
  const PagedListState({required this.page, this.loadingMore = false, this.moreError});

  final Paged<T> page;
  final bool loadingMore;
  final AppException? moreError;

  List<T> get items => page.items;
  bool get hasMore => page.hasMore;
  int get totalCount => page.totalCount;

  PagedListState<T> copyWith({Paged<T>? page, bool? loadingMore, AppException? moreError, bool clearError = false}) =>
      PagedListState(
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: clearError ? null : (moreError ?? this.moreError),
      );
}

/// A list loaded a page at a time (infinite scroll) for one query [A]: the product list per search, the order list per
/// status, and so on. A subclass says how to fetch one page; this takes care of the rest:
///
/// - the first page is the provider's value (loading and error come from Riverpod);
/// - [loadMore] appends the next page, never twice at once, and a failure keeps what is on screen and is reported in
///   [PagedListState.moreError] so the list can offer "Thử lại" under the last row.
abstract class PagedListNotifier<T, A> extends AutoDisposeFamilyAsyncNotifier<PagedListState<T>, A> {
  static const pageSize = 20;

  /// Fetches page number `page` (1-based) for the query `arg`. Use `ref.read`, not `ref.watch`: it also runs from
  /// [loadMore].
  Future<Paged<T>> fetchPage(A arg, int page);

  @override
  Future<PagedListState<T>> build(A arg) async => PagedListState(page: await fetchPage(arg, 1));

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final next = await fetchPage(arg, current.page.page + 1);
      state = AsyncData(PagedListState(page: current.page.append(next)));
    } on AppException catch (error) {
      state = AsyncData(current.copyWith(loadingMore: false, moreError: error));
    }
  }
}
