import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:farmer_mobile/core/theme/app_theme.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/orders/screens/order_success_screen.dart';
import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:farmer_mobile/features/payment/data/payment_repository.dart';
import 'package:farmer_mobile/features/payment/data/pending_payment.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:farmer_mobile/features/payment/screens/payment_result_screen.dart';
import 'package:farmer_mobile/features/payment/screens/payos_checkout_screen.dart';
import 'package:farmer_mobile/features/payment/widgets/pending_payment_banner.dart';
import 'package:farmer_mobile/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/checkout_fixtures.dart';
import '../../support/payment_fixtures.dart';
import '../cart/cart_controller_test.dart' show TestUserId;
import 'payment_providers_test.dart' show MockPaymentRepository;

void main() {
  late MockPaymentRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = MockPaymentRepository();
  });

  Future<void> pump(WidgetTester tester, Widget home, {List<GoRoute> extra = const []}) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(
          path: AppRoutes.paymentResult,
          builder: (_, state) => PaymentResultScreen(args: state.extra as PaymentResultArgs),
        ),
        GoRoute(path: AppRoutes.payosCheckout, builder: (_, state) => Scaffold(body: Text('PAYOS ${(state.extra as PendingPayment).paymentId}'))),
        GoRoute(path: AppRoutes.home, builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: AppRoutes.debt, builder: (_, __) => const Scaffold(body: Text('DEBT'))),
        GoRoute(path: '/orders/:id', builder: (_, state) => Scaffold(body: Text('ORDER ${state.pathParameters['id']}'))),
        GoRoute(path: AppRoutes.orderList, builder: (_, __) => const Scaffold(body: Text('ORDER LIST'))),
        ...extra,
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
          paymentPollingProvider.overrideWithValue(const PaymentPolling(interval: Duration.zero, maxAttempts: 1)),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget resultScreen(PendingPayment payment, PaymentHint hint, {bool simulated = false}) =>
      PaymentResultScreen(args: PaymentResultArgs(payment, hint, simulated: simulated));

  group('result screen', () {
    testWidgets('PAID shows the receipt and leads to the order', (tester) async {
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PAID'));
      await pump(tester, resultScreen(pendingPayment(), PaymentHint.returned));

      expect(find.text('Thanh toán thành công!'), findsOneWidget);
      expect(find.text('Mã thanh toán: PAY-20261008-0001'), findsOneWidget);
      expect(find.text('1.560.000 ₫'), findsOneWidget);

      await tester.tap(find.text('Xem chi tiết đơn hàng'));
      await tester.pumpAndSettle();
      expect(find.text('ORDER o-1'), findsOneWidget);
    });

    testWidgets('a debt repayment leads back to the debt book', (tester) async {
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PAID'));
      await pump(tester, resultScreen(pendingPayment(orderId: null, context: PaymentContext.debtRepayment), PaymentHint.returned));

      expect(find.textContaining('Sổ nợ'), findsWidgets);
      await tester.tap(find.text('Quay lại Sổ nợ'));
      await tester.pumpAndSettle();
      expect(find.text('DEBT'), findsOneWidget);
    });

    testWidgets('a cancelled payment can be started again, which opens a new payOS page', (tester) async {
      when(() => repo.cancel('pay-1')).thenAnswer((_) async => paymentInfo('CANCELLED'));
      when(() => repo.startOrderPayment('o-1')).thenAnswer((_) async => PayosStart.fromJson({...payosStartJson, 'paymentId': 'pay-2'}));
      await pump(tester, resultScreen(pendingPayment(), PaymentHint.cancelled));

      expect(find.text('Bác đã hủy thanh toán'), findsOneWidget);
      expect(find.textContaining('thanh toán lại trong Chi tiết đơn hàng'), findsOneWidget);

      await tester.tap(find.text('Thanh toán lại'));
      await tester.pumpAndSettle();
      expect(find.text('PAYOS pay-2'), findsOneWidget);
    });

    testWidgets('the test-gateway button settles a simulated payment', (tester) async {
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      when(() => repo.simulatePaid('pay-1')).thenAnswer((_) async => paymentInfo('PAID'));
      await pump(tester, resultScreen(pendingPayment(checkoutUrl: simulatedCheckoutUrl), PaymentHint.returned, simulated: true));

      expect(find.text('Thanh toán thử'), findsOneWidget);
      expect(find.textContaining('không có tiền thật'), findsOneWidget);

      await tester.ensureVisible(find.text('Thanh toán nhanh (môi trường thử)'));
      await tester.tap(find.text('Thanh toán nhanh (môi trường thử)'));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công!'), findsOneWidget);
    });

    testWidgets('a payment still pending offers to check again', (tester) async {
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      when(() => repo.sync('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      await pump(tester, resultScreen(pendingPayment(), PaymentHint.check));

      expect(find.text('Đang chờ xác nhận'), findsOneWidget);
      expect(find.text('Kiểm tra lại'), findsOneWidget);
    });

    testWidgets('no network shows the error with a retry that works', (tester) async {
      var fail = true;
      when(() => repo.payment('pay-1')).thenAnswer((_) async {
        if (fail) throw const AppException.offline();
        return paymentInfo('PAID');
      });
      await pump(tester, resultScreen(pendingPayment(), PaymentHint.check));
      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công!'), findsOneWidget);
    });
  });

  group('payOS page', () {
    testWidgets('a test-gateway link is the return page itself: no WebView, straight to the result', (tester) async {
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      await pump(tester, PayosCheckoutScreen(payment: pendingPayment(checkoutUrl: simulatedCheckoutUrl)));

      expect(find.byType(PayosCheckoutScreen), findsNothing);
      expect(find.text('Thanh toán thử'), findsOneWidget);
    });
  });

  group('order created screen', () {
    Order payosOrder() => Order.fromJson(orderJson);

    testWidgets('"Thanh toán ngay" creates the payOS payment and opens its page', (tester) async {
      when(() => repo.startOrderPayment('o-1')).thenAnswer((_) async => PayosStart.fromJson(payosStartJson));
      await pump(tester, OrderSuccessScreen(order: payosOrder()));

      await tester.tap(find.text('Thanh toán ngay'));
      await tester.pumpAndSettle();

      expect(find.text('PAYOS pay-1'), findsOneWidget);
    });

    testWidgets('payOS being down is explained and the farmer stays', (tester) async {
      when(() => repo.startOrderPayment(any())).thenThrow(const AppException(
        kind: AppErrorKind.server,
        message: 'Hệ thống tạm thời chưa phục vụ được. Vui lòng thử lại sau ít phút.',
        statusCode: 503,
      ));
      await pump(tester, OrderSuccessScreen(order: payosOrder()));

      await tester.tap(find.text('Thanh toán ngay'));
      await tester.pumpAndSettle();

      expect(find.textContaining('tạm thời chưa phục vụ được'), findsOneWidget);
      expect(find.text('Thanh toán ngay'), findsOneWidget);
    });

    testWidgets('a credit order has nothing to pay now', (tester) async {
      await pump(tester, OrderSuccessScreen(order: Order.fromJson({...orderJson, 'settlementType': 'CREDIT'})));

      expect(find.text('Thanh toán ngay'), findsNothing);
      expect(find.text('Xem đơn hàng'), findsOneWidget);
    });
  });

  group('home banner', () {
    testWidgets('shows an unfinished payment and opens its check', (tester) async {
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PAID'));
      await prefs.setString('agrisage.pending_payment', _json(pendingPayment()));
      await pump(tester, const Scaffold(body: PendingPaymentBanner()));

      expect(find.textContaining('chưa hoàn tất (1.560.000 ₫)'), findsOneWidget);

      await tester.tap(find.text('Kiểm tra'));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công!'), findsOneWidget);
    });

    testWidgets('is not there when nothing is pending', (tester) async {
      await pump(tester, const Scaffold(body: PendingPaymentBanner()));
      expect(find.textContaining('chưa hoàn tất'), findsNothing);
    });
  });
}

String _json(PendingPayment p) => PendingPaymentStore.encode(p);
