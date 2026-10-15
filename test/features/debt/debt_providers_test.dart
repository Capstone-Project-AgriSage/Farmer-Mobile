import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';
import 'package:farmer_mobile/features/debt/providers/debt_providers.dart';
import 'package:farmer_mobile/shared/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/debt_fakes.dart';

/// Backend trộn thanh toán đơn hàng và trả nợ: giả lập từng trang gốc
/// với số lần trả nợ cho trước (0 = trang toàn thanh toán đơn).
class _PagedRepayments extends FakeDebtRepository {
  _PagedRepayments(this.perPage);

  final List<int> perPage;
  final List<int> asked = [];

  @override
  Future<PagedResult<DebtPayment>> repayments({int page = 1}) async {
    asked.add(page);
    final n = page <= perPage.length ? perPage[page - 1] : 0;
    return PagedResult(
      items: [for (var i = 0; i < n; i++) repaymentOf('p$page-$i')],
      page: page,
      pageSize: 50,
      totalCount: 999,
      totalPages: perPage.length,
    );
  }
}

ProviderContainer containerWith(FakeDebtRepository repo) {
  final c = ProviderContainer(overrides: [debtRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  return c;
}

Future<T> settle<T>(ProviderContainer c, ProviderListenable<T> p, bool Function(T) done) async {
  T last = c.read(p);
  c.listen(p, (_, n) => last = n);
  for (var i = 0; i < 100 && !done(last); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return last;
}

void main() {
  group('Lịch sử trả nợ: lấy tiếp trang khi trang gốc không có lần trả nợ nào', () {
    test('trang 1 và 2 toàn thanh toán đơn → tự lấy đến trang 3 có dữ liệu', () async {
      final repo = _PagedRepayments([0, 0, 2, 1]);
      final c = containerWith(repo);

      final s = await settle(c, debtRepaymentsProvider, (s) => !s.isLoading);
      expect(repo.asked, [1, 2, 3]);
      expect(s.items.length, 2);
      expect(s.page, 3);
      expect(s.hasMore, isTrue, reason: 'còn trang 4');
      expect(s.error, isNull);
    });

    test('dừng sau 5 trang kể cả khi vẫn chưa thấy gì (tránh quét cả lịch sử)', () async {
      final repo = _PagedRepayments([0, 0, 0, 0, 0, 0, 0, 3]);
      final c = containerWith(repo);

      final s = await settle(c, debtRepaymentsProvider, (s) => !s.isLoading);
      expect(repo.asked, [1, 2, 3, 4, 5]);
      expect(s.items, isEmpty);
      expect(s.hasMore, isTrue, reason: 'người dùng vẫn có thể Xem thêm');
    });

    test('loadMore lấy tiếp từ trang kế, không lặp lại trang cũ', () async {
      final repo = _PagedRepayments([1, 0, 2]);
      final c = containerWith(repo);
      await settle(c, debtRepaymentsProvider, (s) => !s.isLoading);
      expect(repo.asked, [1]);

      await c.read(debtRepaymentsProvider.notifier).loadMore();
      final s = c.read(debtRepaymentsProvider);
      expect(repo.asked, [1, 2, 3]);
      expect(s.items.length, 3);
      expect(s.hasMore, isFalse);
    });

    test('loadMore lỗi: giữ dữ liệu cũ, báo lỗi để thử lại', () async {
      final c2 = containerWith(_Failing());
      await settle(c2, debtRepaymentsProvider, (s) => !s.isLoading);
      expect(c2.read(debtRepaymentsProvider).items.length, 1);
      await c2.read(debtRepaymentsProvider.notifier).loadMore();
      final s = c2.read(debtRepaymentsProvider);
      expect(s.items.length, 1);
      expect(s.loadMoreError, isA<ApiException>());
      expect(s.isLoadingMore, isFalse);
    });
  });

  group('Danh sách khoản nợ', () {
    test('đổi bộ lọc xoá dữ liệu cũ, tải trang 1 theo trạng thái mới', () async {
      final repo = FakeDebtRepository()
        ..entries0 = [
          entryOf('a'),
          entryOf('b', status: 'PAID', paid: 2000000, outstanding: 0),
        ];
      final c = containerWith(repo);
      await settle(c, myDebtEntriesProvider, (s) => !s.isLoading);
      expect(c.read(myDebtEntriesProvider).items.length, 2);

      final f = c.read(myDebtEntriesProvider.notifier).setStatus(DebtStatus.paid);
      expect(c.read(myDebtEntriesProvider).items, isEmpty, reason: 'không hiện dữ liệu của bộ lọc cũ');
      await f;
      expect(c.read(myDebtEntriesProvider).items.single.id, 'b');
      expect(repo.entryCalls.last, (page: 1, status: 'PAID'));
    });

    test('chọn lại bộ lọc đang chọn thì không gọi lại API', () async {
      final repo = FakeDebtRepository();
      final c = containerWith(repo);
      await settle(c, myDebtEntriesProvider, (s) => !s.isLoading);
      final before = repo.entryCalls.length;
      await c.read(myDebtEntriesProvider.notifier).setStatus(null);
      expect(repo.entryCalls.length, before);
    });

    test('đổi bộ lọc nhanh: kết quả muộn của bộ lọc cũ bị bỏ', () async {
      final repo = _SlowFirst();
      final c = containerWith(repo);
      await settle(c, myDebtEntriesProvider, (s) => !s.isLoading);

      // Bộ lọc A (chậm) rồi bộ lọc B (nhanh): chỉ B được hiện.
      repo.slow = true;
      final a = c.read(myDebtEntriesProvider.notifier).setStatus(DebtStatus.open);
      repo.slow = false;
      final b = c.read(myDebtEntriesProvider.notifier).setStatus(DebtStatus.paid);
      await Future.wait([a, b]);

      final s = c.read(myDebtEntriesProvider);
      expect(s.status, DebtStatus.paid);
      expect(s.items.map((e) => e.id), ['paid1']);
    });
  });

  group('Chấm đỏ tab Công nợ', () {
    test('có nợ quá hạn → true; không có → false', () async {
      final repo = FakeDebtRepository()..account0 = accountOf(overdue: 100000);
      final c = containerWith(repo);
      c.listen(debtAccountProvider, (_, __) {});
      await c.read(debtAccountProvider.future);
      expect(c.read(hasOverdueDebtProvider), isTrue);

      repo.account0 = accountOf(overdue: 0);
      c.invalidate(debtAccountProvider);
      await c.read(debtAccountProvider.future);
      expect(c.read(hasOverdueDebtProvider), isFalse);
    });

    test('chưa có sổ nợ / đang tải / lỗi → không báo', () async {
      final repo = FakeDebtRepository()..account0 = null;
      final c = containerWith(repo);
      c.listen(debtAccountProvider, (_, __) {});
      expect(c.read(hasOverdueDebtProvider), isFalse, reason: 'đang tải');
      await c.read(debtAccountProvider.future);
      expect(c.read(hasOverdueDebtProvider), isFalse);

      repo.accountError = const ApiException(kind: ApiErrorKind.network, message: 'x');
      c.invalidate(debtAccountProvider);
      await c.read(debtAccountProvider.future).then((_) {}, onError: (_) {});
      expect(c.read(hasOverdueDebtProvider), isFalse);
    });

    Future<void> pumpShell(WidgetTester tester, FakeDebtRepository repo) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (_, __, child) => AppShell(child: child),
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const Text('HOME')),
              GoRoute(path: '/debt', builder: (_, __) => const Text('DEBT')),
              GoRoute(path: '/products', builder: (_, __) => const Text('P')),
              GoRoute(path: '/ai-scan', builder: (_, __) => const Text('AI')),
              GoRoute(path: '/profile', builder: (_, __) => const Text('ME')),
            ],
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [debtRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    // Chấm đỏ: Container tròn 10x10 trong tab.
    Finder dot() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.constraints?.maxWidth == 10 &&
        w.constraints?.maxHeight == 10 &&
        (w.decoration as BoxDecoration?)?.shape == BoxShape.circle);

    testWidgets('AppShell hiện chấm đỏ khi có nợ quá hạn', (tester) async {
      await pumpShell(tester, FakeDebtRepository()..account0 = accountOf(overdue: 250000));
      expect(dot(), findsOneWidget);
    });

    testWidgets('AppShell KHÔNG hiện chấm đỏ khi không có nợ quá hạn', (tester) async {
      await pumpShell(tester, FakeDebtRepository()..account0 = accountOf(overdue: 0));
      expect(dot(), findsNothing);
    });

    testWidgets('AppShell không chấm đỏ khi lỗi mạng (không báo sai)', (tester) async {
      await pumpShell(
          tester,
          FakeDebtRepository()
            ..accountError = const ApiException(kind: ApiErrorKind.network, message: 'x'));
      expect(dot(), findsNothing);
      expect(find.text('Công nợ'), findsOneWidget);
    });
  });
}

class _Failing extends FakeDebtRepository {
  int n = 0;
  @override
  Future<PagedResult<DebtPayment>> repayments({int page = 1}) async {
    if (++n > 1) {
      throw const ApiException(kind: ApiErrorKind.network, message: 'mất mạng');
    }
    return PagedResult(
        items: [repaymentOf('1')], page: 1, pageSize: 50, totalCount: 100, totalPages: 2);
  }
}

class _SlowFirst extends FakeDebtRepository {
  bool slow = false;

  @override
  Future<PagedResult<DebtEntrySummary>> entries({
    int page = 1,
    int size = DebtRepository.pageSize,
    String? status,
  }) async {
    if (slow) await Future<void>.delayed(const Duration(milliseconds: 60));
    final items = status == DebtStatus.paid
        ? [entryOf('paid1', status: 'PAID', paid: 2000000, outstanding: 0)]
        : [entryOf('open1')];
    return PagedResult(items: items, page: 1, pageSize: 20, totalCount: 1, totalPages: 1);
  }
}
