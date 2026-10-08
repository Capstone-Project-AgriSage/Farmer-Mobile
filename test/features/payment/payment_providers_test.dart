import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/dio_provider.dart';
import 'package:farmer_mobile/core/storage/app_prefs.dart';
import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:farmer_mobile/features/payment/data/payment_repository.dart';
import 'package:farmer_mobile/features/payment/data/pending_payment.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/payment_fixtures.dart';
import '../cart/cart_controller_test.dart' show TestUserId;

class MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late MockPaymentRepository repo;
  late SharedPreferences prefs;
  late ProviderContainer container;

  Future<void> boot({String? userId = 'u1'}) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = MockPaymentRepository();
    container = ProviderContainer(overrides: [
      paymentRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionUserIdProvider.overrideWith(() => TestUserId(userId)),
      paymentPollingProvider.overrideWithValue(const PaymentPolling(interval: Duration.zero, maxAttempts: 3)),
    ]);
    addTearDown(container.dispose);
  }

  /// Opens the result provider, remembers the unfinished payment, and lets the first check finish.
  Future<List<PaymentResultState>> openResult(PaymentResultArgs args, {bool remember = true}) async {
    if (remember) await container.read(pendingPaymentProvider.notifier).save(args.payment);
    final states = <PaymentResultState>[];
    container.listen(paymentResultProvider(args), (_, next) => states.add(next), fireImmediately: true);
    await _settle();
    return states;
  }

  group('PaymentResultController', () {
    test('a payment the server says is PAID succeeds and is forgotten', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PAID'));

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.first, isA<ResultChecking>());
      expect(states.last, isA<ResultPaid>());
      expect(container.read(pendingPaymentProvider), isNull);
      expect(prefs.getString('agrisage.pending_payment'), isNull);
      verifyNever(() => repo.sync(any()));
    });

    test('the return link claiming PAID is not believed: a PENDING payment is never shown as paid', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      when(() => repo.sync('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.whereType<ResultPaid>(), isEmpty);
      expect(states.last, isA<ResultStillPending>());
    });

    test('PENDING at first, then PAID after the server re-checks with payOS', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      var syncs = 0;
      when(() => repo.sync('pay-1')).thenAnswer((_) async => paymentInfo(++syncs < 2 ? 'PENDING' : 'PAID'));

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.last, isA<ResultPaid>());
      expect(syncs, 2);
      expect(states.whereType<ResultChecking>().map((s) => s.attempt), containsAllInOrder([0, 1, 2]));
    });

    test('still PENDING after the last re-check: the farmer is asked to look again later', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      when(() => repo.sync('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.check));

      expect(states.last, isA<ResultStillPending>());
      verify(() => repo.sync('pay-1')).called(3); // maxAttempts in this test
      expect(container.read(pendingPaymentProvider), isNotNull, reason: 'it may still be paid: keep the banner');
    });

    test('a FAILED payment is a failure and is forgotten', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('FAILED'));

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.last, isA<ResultFailed>());
      expect(container.read(pendingPaymentProvider), isNull);
    });

    test('cancelling tells the server to cancel, and a failed cancel does not matter', () async {
      await boot();
      when(() => repo.cancel('pay-1')).thenThrow(const AppException(kind: AppErrorKind.businessRule, message: 'x', statusCode: 422));

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.cancelled));

      verify(() => repo.cancel('pay-1')).called(1);
      verifyNever(() => repo.payment(any()));
      expect(states.last, isA<ResultCancelled>());
      expect(container.read(pendingPaymentProvider), isNull);
    });

    test('a test-gateway link waits for the test button instead of polling', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));

      final args = PaymentResultArgs(pendingPayment(checkoutUrl: simulatedCheckoutUrl), PaymentHint.returned, simulated: true);
      final states = await openResult(args);

      expect(states.last, isA<ResultSimulatedPending>());
      verifyNever(() => repo.sync(any()));
    });

    test('the test button pays the link and the result becomes PAID', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      when(() => repo.simulatePaid('pay-1')).thenAnswer((_) async => paymentInfo('PAID'));

      final args = PaymentResultArgs(pendingPayment(checkoutUrl: simulatedCheckoutUrl), PaymentHint.returned, simulated: true);
      final states = await openResult(args);
      await container.read(paymentResultProvider(args).notifier).simulatePay();

      expect(states.last, isA<ResultPaid>());
      expect(container.read(pendingPaymentProvider), isNull);
    });

    test('the test button on a server that is not in test mode explains it', () async {
      await boot();
      when(() => repo.payment('pay-1')).thenAnswer((_) async => paymentInfo('PENDING'));
      when(() => repo.simulatePaid('pay-1')).thenThrow(const AppException(kind: AppErrorKind.notFound, message: 'x', statusCode: 404));

      final args = PaymentResultArgs(pendingPayment(checkoutUrl: simulatedCheckoutUrl), PaymentHint.returned, simulated: true);
      final states = await openResult(args);
      await container.read(paymentResultProvider(args).notifier).simulatePay();

      final last = states.last as ResultSimulatedPending;
      expect(last.error, contains('PayOS:Mode=Simulated'));
      expect(last.paying, isFalse);
    });

    test('no network: an error to retry, and the payment is not cancelled meanwhile', () async {
      await boot();
      var fail = true;
      when(() => repo.payment('pay-1')).thenAnswer((_) async {
        if (fail) throw const AppException.offline();
        return paymentInfo('PAID');
      });

      final args = PaymentResultArgs(pendingPayment(), PaymentHint.check);
      final states = await openResult(args);
      expect(states.last, isA<ResultError>());
      verifyNever(() => repo.cancel(any()));
      expect(container.read(pendingPaymentProvider), isNotNull);

      fail = false;
      await container.read(paymentResultProvider(args).notifier).retry();
      await _settle();
      expect(states.last, isA<ResultPaid>());
    });
  });

  group('PendingPaymentController', () {
    test('keeps the unfinished payment of the signed-in farmer across a restart', () async {
      await boot();
      await container.read(pendingPaymentProvider.notifier).save(pendingPayment());

      final restarted = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
      ]);
      addTearDown(restarted.dispose);

      expect(restarted.read(pendingPaymentProvider)?.paymentId, 'pay-1');
    });

    test("another account's unfinished payment is not shown", () async {
      await boot();
      await container.read(pendingPaymentProvider.notifier).save(pendingPayment(userId: 'someone-else'));

      final other = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
      ]);
      addTearDown(other.dispose);

      expect(other.read(pendingPaymentProvider), isNull);
    });

    test('an expired link is dropped', () async {
      await boot();
      await container.read(pendingPaymentProvider.notifier).save(pendingPayment(expiresAt: DateTime.utc(2020)));

      final later = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionUserIdProvider.overrideWith(() => TestUserId('u1')),
      ]);
      addTearDown(later.dispose);

      expect(later.read(pendingPaymentProvider), isNull);
      expect(prefs.getString('agrisage.pending_payment'), isNull);
    });
  });

  group('PaymentLauncher', () {
    test('saves the payment before the payOS page can open, with the order it belongs to', () async {
      await boot();
      when(() => repo.startOrderPayment('o-1')).thenAnswer((_) async => PayosStart.fromJson(payosStartJson));

      final pending = await container.read(paymentLauncherProvider).startOrderPayment('o-1');

      expect(pending.orderId, 'o-1');
      expect(pending.context, PaymentContext.orderPayment);
      expect(pending.userId, 'u1');
      expect(container.read(pendingPaymentProvider)?.paymentId, 'pay-1');
      expect(PendingPaymentStore(prefs).read()?.checkoutUrl, 'https://pay.payos.vn/web/abc');
    });

    test('a debt repayment belongs to no order', () async {
      await boot();
      when(() => repo.startDebtRepayment(500000)).thenAnswer((_) async => PayosStart.fromJson(payosStartJson));

      final pending = await container.read(paymentLauncherProvider).startDebtRepayment(500000);

      expect(pending.orderId, isNull);
      expect(pending.isDebtRepayment, isTrue);
    });

    test('nothing is saved when payOS cannot be reached', () async {
      await boot();
      when(() => repo.startOrderPayment(any())).thenThrow(const AppException(kind: AppErrorKind.server, message: 'down', statusCode: 503));

      await expectLater(container.read(paymentLauncherProvider).startOrderPayment('o-1'), throwsA(isA<AppException>()));
      expect(container.read(pendingPaymentProvider), isNull);
    });
  });

  group('PaymentRepository', () {
    late DioAdapter adapter;
    late PaymentRepository real;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      adapter = DioAdapter(dio: dio);
      real = PaymentRepository(dio);
    });

    test('an order payment asks for the unpaid rest of that order', () async {
      adapter.onPost(
        '/api/me/payments/payos',
        (server) => server.reply(200, payosStartJson),
        data: {'paymentContext': 'ORDER_PAYMENT', 'orderId': 'o-1', 'amount': null},
      );
      final start = await real.startOrderPayment('o-1');
      expect(start.checkoutUrl, 'https://pay.payos.vn/web/abc');
      expect(start.amount, 1560000);
      expect(start.expiresAt, DateTime.utc(2099));
    });

    test('a debt repayment sends a whole amount and no order', () async {
      adapter.onPost(
        '/api/me/payments/payos',
        (server) => server.reply(200, payosStartJson),
        data: {'paymentContext': 'DEBT_REPAYMENT', 'orderId': null, 'amount': 500000},
      );
      await real.startDebtRepayment(500000);
    });

    test('read, sync, cancel and simulate use their endpoints', () async {
      const body = {'id': 'pay-1', 'paymentNumber': 'P', 'paymentContext': 'ORDER_PAYMENT', 'amount': 1.0, 'status': 'PAID'};
      adapter.onGet('/api/me/payments/pay-1', (server) => server.reply(200, body));
      adapter.onPost('/api/payments/pay-1/sync', (server) => server.reply(200, body));
      adapter.onPost('/api/me/payments/pay-1/cancel', (server) => server.reply(200, {...body, 'status': 'CANCELLED'}));
      adapter.onPost('/api/payments/pay-1/simulate-paid', (server) => server.reply(200, body));

      expect((await real.payment('pay-1')).isPaid, isTrue);
      expect((await real.sync('pay-1')).isPaid, isTrue);
      expect((await real.cancel('pay-1')).status, 'CANCELLED');
      expect((await real.simulatePaid('pay-1')).isPaid, isTrue);
    });
  });

  group('PendingPayment', () {
    test('knows a test-gateway link and an expired one', () {
      expect(pendingPayment(checkoutUrl: simulatedCheckoutUrl).isSimulated, isTrue);
      expect(pendingPayment().isSimulated, isFalse);
      expect(pendingPayment(expiresAt: DateTime.utc(2020)).isExpired(DateTime.utc(2026)), isTrue);
      expect(pendingPayment().isExpired(DateTime.utc(2026)), isFalse);
    });

    test('a damaged or incomplete saved entry reads as nothing', () async {
      SharedPreferences.setMockInitialValues({'agrisage.pending_payment': '{not json'});
      final store = PendingPaymentStore(await SharedPreferences.getInstance());
      expect(store.read(), isNull);

      SharedPreferences.setMockInitialValues({'agrisage.pending_payment': '{"paymentId":"x"}'}); // no user
      expect(PendingPaymentStore(await SharedPreferences.getInstance()).read(), isNull);
    });
  });
}

/// Lets the microtask that starts the check, and the awaits inside it, run to the end.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
