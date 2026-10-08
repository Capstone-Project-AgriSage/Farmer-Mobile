import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/network/paged.dart';
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/credit/data/credit_repository.dart';
import 'package:farmer_mobile/features/debt/data/debt_models.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';
import 'package:farmer_mobile/features/debt/screens/debt_detail_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_history_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_overview_screen.dart';
import 'package:farmer_mobile/features/debt/screens/debt_repay_screen.dart';
import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:farmer_mobile/features/payment/data/payment_repository.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/checkout_fixtures.dart' show credit;
import '../../support/debt_fixtures.dart';
import '../../support/payment_fixtures.dart' show payosStartJson;
import '../cart/cart_controller_test.dart' show TestUserId;
import '../checkout/checkout_screen_test.dart' show MockCreditRepository;
import '../payment/payment_providers_test.dart' show MockPaymentRepository;

class MockDebtRepository extends Mock implements DebtRepository {}

void main() {
  late MockDebtRepository debts;
  late MockCreditRepository credits;
  late MockPaymentRepository payments;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    debts = MockDebtRepository();
    credits = MockCreditRepository();
    payments = MockPaymentRepository();
    when(() => credits.myCredit()).thenAnswer((_) async => credit());
    when(() => debts.account()).thenAnswer((_) async => DebtAccount.fromJson(debtAccountJson()));
    when(() => payments.myPayments(page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer(
      (_) async => Paged.fromJson({
        'items': [repaymentJson(id: 'r-1', amount: 500000), orderPaymentJson],
        'page': 1,
        'pageSize': 100,
        'totalCount': 2,
      }, PaymentListItem.fromJson),
    );
    when(() => debts.entries(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize'))).thenAnswer(
      (_) async => Paged.fromJson({
        'items': [debtEntryRow(), debtEntryRow(id: 'e-2', number: 'DE-2', order: 'OD-2', status: 'PAID', outstanding: 0, paid: 2000000)],
        'page': 1,
        'pageSize': 20,
        'totalCount': 2,
      }, DebtEntryListItem.fromJson),
    );
  });

  Future<GoRouter> pump(WidgetTester tester, Widget home) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(path: AppRoutes.debtRepay, builder: (_, __) => const DebtRepayScreen()),
        GoRoute(path: AppRoutes.debtHistory, builder: (_, __) => const DebtHistoryScreen()),
        GoRoute(path: '${AppRoutes.debt}/entries/:id', builder: (_, state) => DebtDetailScreen(debtId: state.pathParameters['id']!)),
        GoRoute(path: AppRoutes.payosCheckout, builder: (_, __) => const Scaffold(body: Text('PAYOS PAGE'))),
        GoRoute(path: AppRoutes.products, builder: (_, __) => const Scaffold(body: Text('PRODUCTS'))),
        GoRoute(path: AppRoutes.debt, builder: (_, __) => const Scaffold(body: Text('DEBT HOME'))),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debtRepositoryProvider.overrideWithValue(debts),
          creditRepositoryProvider.overrideWithValue(credits),
          paymentRepositoryProvider.overrideWithValue(payments),
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('debt overview', () {
    testWidgets('shows the credit line, the stats and the debts', (tester) async {
      await pump(tester, const DebtOverviewScreen());

      expect(find.text('5.000.000 ₫'), findsOneWidget, reason: 'the credit limit');
      expect(find.text('Hạn mức mua chịu'), findsOneWidget);
      expect(find.text('1.988.000 ₫'), findsOneWidget, reason: 'what is left of the limit');
      expect(find.text('Khoản nợ đang mở'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Trả nợ qua payOS'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Trả nợ qua payOS'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('#OD-20261007-0064'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('#OD-20261007-0064'), findsOneWidget);
      expect(find.text('Chưa trả'), findsWidgets);
    });

    testWidgets('a farmer with no debt book is told the store has not opened one', (tester) async {
      when(() => credits.myCredit()).thenAnswer((_) async => null);
      when(() => debts.account()).thenAnswer((_) async => null);
      await pump(tester, const DebtOverviewScreen());

      expect(find.text('Bác chưa có Sổ nợ'), findsOneWidget);
      expect(find.text('Trả nợ qua payOS'), findsNothing);
      await tester.tap(find.text('Mua sắm ngay'));
      await tester.pumpAndSettle();
      expect(find.text('PRODUCTS'), findsOneWidget);
    });

    testWidgets('an overdue amount raises a banner with a way to repay', (tester) async {
      when(() => debts.account()).thenAnswer((_) async => DebtAccount.fromJson(debtAccountJson(overdue: 750000)));
      await pump(tester, const DebtOverviewScreen());

      expect(find.text('Bác có khoản nợ đã quá hạn'), findsOneWidget);
      expect(find.textContaining('750.000 ₫'), findsWidgets);
      expect(find.text('Trả nợ ngay'), findsOneWidget);
    });

    testWidgets('a filter chip asks the server for that status', (tester) async {
      await pump(tester, const DebtOverviewScreen());

      await tester.scrollUntilVisible(find.text('Khiếu nại'), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Khiếu nại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khiếu nại'));
      await tester.pumpAndSettle();

      verify(() => debts.entries(status: 'DISPUTED', page: 1, pageSize: 20)).called(1);
    });

    testWidgets('nothing in a status says so', (tester) async {
      when(() => debts.entries(status: any(named: 'status'), page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => const Paged.empty());
      await pump(tester, const DebtOverviewScreen());

      await tester.scrollUntilVisible(find.text('Không có khoản nợ nào trong mục này.'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Không có khoản nợ nào trong mục này.'), findsOneWidget);
    });

    testWidgets('a failure shows the message and a retry', (tester) async {
      var fail = true;
      when(() => debts.account()).thenAnswer((_) async {
        if (fail) throw const AppException.offline();
        return DebtAccount.fromJson(debtAccountJson());
      });
      await pump(tester, const DebtOverviewScreen());
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Hạn mức mua chịu'), findsOneWidget);
    });

    testWidgets('tapping a debt opens it', (tester) async {
      when(() => debts.entry('e-1')).thenAnswer((_) async => DebtEntryDetail.fromJson(debtEntryDetailJson()));
      await pump(tester, const DebtOverviewScreen());

      await tester.scrollUntilVisible(find.text('#OD-20261007-0064'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('#OD-20261007-0064'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết khoản nợ'), findsOneWidget);
    });
  });

  group('debt detail', () {
    void stubEntry({String status = 'OPEN', List<Map<String, dynamic>> actions = const []}) =>
        when(() => debts.entry('e-1')).thenAnswer((_) async => DebtEntryDetail.fromJson(debtEntryDetailJson(status: status, actions: actions)));

    Future<void> open(WidgetTester tester) => pump(tester, const DebtDetailScreen(debtId: 'e-1'));

    testWidgets('shows the amounts, the due date and the ledger', (tester) async {
      stubEntry();
      await open(tester);

      expect(find.text('Khoản nợ OD-20261007-0064'), findsOneWidget);
      expect(find.text('Còn nợ'), findsOneWidget);
      expect(find.text('1.500.000 ₫'), findsWidgets);
      expect(find.text('Hạn trả'), findsOneWidget);
      expect(find.text('20/11/2026'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ghi nợ từ đơn hàng'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Ghi nợ từ đơn hàng'), findsOneWidget);
      expect(find.text('Trả nợ'), findsOneWidget);
      expect(find.text('− 500.000 ₫'), findsOneWidget);
      expect(find.text('Trả qua payOS'), findsOneWidget);
    });

    testWidgets('an open debt can be disputed, but only with a reason', (tester) async {
      stubEntry();
      when(() => debts.dispute('e-1', any())).thenAnswer((_) async => DebtEntryDetail.fromJson(debtEntryDetailJson(status: 'DISPUTED')));
      await open(tester);

      await tester.tap(find.text('Khiếu nại khoản nợ này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi khiếu nại'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do khiếu nại'), findsOneWidget);
      verifyNever(() => debts.dispute(any(), any()));

      await tester.enterText(find.byType(TextFormField), 'Số lượng giao chưa đủ');
      await tester.tap(find.text('Gửi khiếu nại'));
      await tester.pumpAndSettle();

      verify(() => debts.dispute('e-1', 'Số lượng giao chưa đủ')).called(1);
      expect(find.textContaining('Đã gửi khiếu nại'), findsOneWidget);
    });

    testWidgets('a settled or already disputed debt cannot be disputed', (tester) async {
      stubEntry(status: 'PAID');
      await open(tester);
      expect(find.text('Khiếu nại khoản nợ này'), findsNothing);
    });

    testWidgets('what the store did about a dispute is shown', (tester) async {
      stubEntry(status: 'DISPUTED', actions: [disputeActionJson]);
      await open(tester);

      await tester.scrollUntilVisible(find.text('Xử lý khiếu nại'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Bác đã khiếu nại'), findsOneWidget);
      expect(find.text('Số lượng giao chưa đủ'), findsOneWidget);
      expect(find.text('Khiếu nại khoản nợ này'), findsNothing, reason: 'already disputed');
    });
  });

  group('repayment history', () {
    testWidgets('lists the farmer\'s debt repayments only, with the total repaid', (tester) async {
      await pump(tester, const DebtHistoryScreen());

      expect(find.text('PM-r-1'), findsOneWidget);
      expect(find.text('PM-ORDER'), findsNothing, reason: 'an order payment is not a repayment');
      expect(find.text('Chuyển khoản qua payOS'), findsOneWidget);
      expect(find.text('500.000 ₫'), findsNWidgets(2), reason: 'the total and the one repayment');
    });

    testWidgets('no repayments says so', (tester) async {
      when(() => payments.myPayments(page: any(named: 'page'), pageSize: any(named: 'pageSize')))
          .thenAnswer((_) async => const Paged.empty());
      await pump(tester, const DebtHistoryScreen());
      expect(find.text('Bác chưa có lần trả nợ nào.'), findsOneWidget);
    });
  });

  group('repay screen', () {
    setUp(() {
      when(() => debts.allocationPreview(any())).thenAnswer((invocation) async => AllocationPreview.fromJson(previewJson(invocation.positionalArguments.first as int)));
    });

    Future<void> open(WidgetTester tester) => pump(tester, const DebtRepayScreen());

    testWidgets('starts with the whole debt and shows what it would settle', (tester) async {
      await open(tester);

      expect(find.text('3.000.000 ₫'), findsOneWidget, reason: 'the balance');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '3000000');
      expect(find.textContaining('hạn trả cũ nhất trước'), findsOneWidget);
      expect(find.text('DE-20261007-0001 · hạn 20/11/2026'), findsOneWidget);
      verify(() => debts.allocationPreview(3000000)).called(1);
    });

    testWidgets('an amount above the debt, or nothing, blocks the button', (tester) async {
      await open(tester);

      await tester.enterText(find.byType(TextField), '3000001');
      await tester.pump();
      expect(find.textContaining('không được vượt quá'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Thanh toán qua payOS')).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Thanh toán qua payOS')).onPressed, isNull);
    });

    testWidgets('the preview waits until the farmer stops typing', (tester) async {
      await open(tester);
      clearInteractions(debts);

      await tester.enterText(find.byType(TextField), '1000000');
      await tester.pump(const Duration(milliseconds: 200));
      verifyNever(() => debts.allocationPreview(1000000));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      verify(() => debts.allocationPreview(1000000)).called(1);
    });

    testWidgets('"Trả hết" puts the whole debt back', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();

      await tester.tap(find.text('Trả hết'));
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '3000000');
    });

    testWidgets('paying sends the whole-đồng amount to payOS and opens its page', (tester) async {
      when(() => payments.startDebtRepayment(any())).thenAnswer((_) async => PayosStart.fromJson(payosStartJson));
      await open(tester);

      await tester.enterText(find.byType(TextField), '500000');
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Thanh toán qua payOS'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Thanh toán qua payOS'));
      await tester.pumpAndSettle();

      verify(() => payments.startDebtRepayment(500000)).called(1);
      expect(find.text('PAYOS PAGE'), findsOneWidget);
    });

    testWidgets('payOS refusing is shown and the farmer stays', (tester) async {
      when(() => payments.startDebtRepayment(any())).thenThrow(const AppException(
        kind: AppErrorKind.server,
        message: 'Hệ thống tạm thời chưa phục vụ được. Vui lòng thử lại sau ít phút.',
        statusCode: 503,
      ));
      await open(tester);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Thanh toán qua payOS'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Thanh toán qua payOS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tạm thời chưa phục vụ được'), findsOneWidget);
      expect(find.text('PAYOS PAGE'), findsNothing);
    });

    testWidgets('a farmer who owes nothing has nothing to repay', (tester) async {
      when(() => debts.account()).thenAnswer((_) async => DebtAccount.fromJson(debtAccountJson(balance: 0, open: 0, oldestDue: null)));
      await open(tester);
      expect(find.text('Bác không còn khoản nợ nào cần trả'), findsOneWidget);
    });
  });
}
