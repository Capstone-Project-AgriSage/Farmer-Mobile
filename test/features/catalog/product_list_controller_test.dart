import 'dart:async';

import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/features/catalog/data/catalog_repository.dart';
import 'package:farmer_mobile/features/catalog/providers/catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/catalog_fixtures.dart';

class MockCatalogRepository extends Mock implements CatalogRepository {}

void main() {
  late MockCatalogRepository repo;
  late ProviderContainer container;
  const query = ProductQuery();

  setUpAll(() => registerFallbackValue(const ProductQuery()));

  setUp(() {
    repo = MockCatalogRepository();
    container = ProviderContainer(overrides: [catalogRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
  });

  void stubPages(List<dynamic> answers) {
    var call = 0;
    when(() => repo.products(query: any(named: 'query'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .thenAnswer((_) async {
      final answer = answers[call++];
      if (answer is Exception) throw answer;
      return answer;
    });
  }

  ProviderSubscription<AsyncValue<ProductListState>> listen() =>
      container.listen(productListProvider(query), (_, __) {}, fireImmediately: true);

  test('loads the first page', () async {
    stubPages([page([priced], total: 2, size: 1)]);
    listen();

    final state = await container.read(productListProvider(query).future);

    expect(state.items, [priced]);
    expect(state.hasMore, isTrue);
  });

  test('loadMore appends the next page and stops when there are no more', () async {
    stubPages([page([priced], total: 2, size: 1), page([unpriced], number: 2, total: 2, size: 1)]);
    listen();
    await container.read(productListProvider(query).future);

    await container.read(productListProvider(query).notifier).loadMore();
    final state = container.read(productListProvider(query)).requireValue;
    expect(state.items, [priced, unpriced]);
    expect(state.hasMore, isFalse);

    await container.read(productListProvider(query).notifier).loadMore(); // nothing left: no third request
    verify(() => repo.products(query: any(named: 'query'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .called(2);
  });

  test('two loadMore calls at once fetch one page', () async {
    final second = Completer<void>();
    var call = 0;
    when(() => repo.products(query: any(named: 'query'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .thenAnswer((_) async {
      if (call++ == 0) return page([priced], total: 2, size: 1);
      await second.future;
      return page([unpriced], number: 2, total: 2, size: 1);
    });
    listen();
    await container.read(productListProvider(query).future);

    final notifier = container.read(productListProvider(query).notifier);
    final a = notifier.loadMore();
    final b = notifier.loadMore();
    second.complete();
    await Future.wait([a, b]);

    expect(container.read(productListProvider(query)).requireValue.items, hasLength(2));
    verify(() => repo.products(query: any(named: 'query'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
        .called(2);
  });

  test('a failed loadMore keeps the list and reports the error; trying again can succeed', () async {
    stubPages([page([priced], total: 2, size: 1), const AppException.offline(), page([unpriced], number: 2, total: 2, size: 1)]);
    listen();
    await container.read(productListProvider(query).future);

    await container.read(productListProvider(query).notifier).loadMore();
    var state = container.read(productListProvider(query)).requireValue;
    expect(state.items, [priced]);
    expect(state.moreError?.kind, AppErrorKind.offline);
    expect(state.loadingMore, isFalse);

    await container.read(productListProvider(query).notifier).loadMore();
    state = container.read(productListProvider(query)).requireValue;
    expect(state.items, [priced, unpriced]);
    expect(state.moreError, isNull);
  });

  test('a first-page failure is an error state', () async {
    stubPages([const AppException.offline()]);
    listen();
    await expectLater(container.read(productListProvider(query).future), throwsA(isA<AppException>()));
  });
}
