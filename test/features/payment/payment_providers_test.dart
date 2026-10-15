import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/features/orders/data/order_models.dart';
import 'package:farmer_mobile/features/debt/data/debt_repository.dart';
import 'package:farmer_mobile/features/orders/data/order_repository.dart';
import 'package:farmer_mobile/features/payment/data/pending_payment.dart';
import 'package:farmer_mobile/features/payment/providers/payment_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/debt_fakes.dart';
import '../../helpers/order_fakes.dart';
import '../../helpers/payment_test_support.dart';

// Kiểm thử luồng payOS (thiết kế của nhánh feature/mobile-diagnosis, chuyển sang kiến trúc hiện tại).

const _simulatedUrl =
    'http://localhost:5174/payments/payos/return?simulated=1&orderCode=1700000001';

PendingPayment pendingPayment({
  String id = 'pay1',
  String? orderId = 'o1',
  String context = PaymentContext.orderPayment,
  String checkoutUrl = 'https://pay.payos.vn/web/abc',
  String userId = 'u1',
  DateTime? expiresAt,
}) =>
    PendingPayment(
      paymentId: id,
      paymentNumber: 'PM-20261012-0001',
      context: context,
      amount: 1560000,
      checkoutUrl: checkoutUrl,
      userId: userId,
      orderId: orderId,
      expiresAt: expiresAt ?? DateTime.utc(2099),
    );

const _offline = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ.');

void main() {
  late FakePaymentRepository repo;
  late MemoryKeyValueStore store;
  late ProviderContainer container;

  void boot({String? userId = 'u1'}) {
    repo = FakePaymentRepository();
    store = MemoryKeyValueStore();
    container = ProviderContainer(overrides: [
      paymentRepositoryProvider.overrideWithValue(repo),
      // Thanh toán xong làm mới đơn/công nợ: dùng bản giả để không gọi mạng thật.
      orderRepositoryProvider.overrideWithValue(FakeOrderRepository()),
      debtRepositoryProvider.overrideWithValue(FakeDebtRepository()),
      sessionUserIdProvider.overrideWithValue(userId),
      ...paymentTestOverrides(store),
    ]);
    addTearDown(container.dispose);
  }

  /// Mở provider kết quả, nhớ khoản thanh toán dở, để lần kiểm tra đầu chạy hết.
  Future<List<PaymentResultState>> openResult(PaymentResultArgs args,
      {bool remember = true}) async {
    if (remember) await container.read(pendingPaymentProvider.notifier).save(args.payment);
    final states = <PaymentResultState>[];
    container.listen(paymentResultProvider(args), (_, next) => states.add(next),
        fireImmediately: true);
    await _settle();
    return states;
  }

  group('PaymentResultController', () {
    test('server báo PAID: thành công và quên khoản dở', () async {
      boot();
      repo.statuses.add('PAID');

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.first, isA<ResultChecking>());
      expect(states.last, isA<ResultPaid>());
      expect(container.read(pendingPaymentProvider), isNull);
      expect(store.data[PendingPaymentStore.key], isNull);
      expect(repo.calls.where((c) => c.startsWith('sync')), isEmpty);
    });

    test('link trả về nói PAID nhưng server nói PENDING: KHÔNG bao giờ hiện thành công', () async {
      boot();
      repo.statuses.addAll(['PENDING', 'PENDING', 'PENDING', 'PENDING']);

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.whereType<ResultPaid>(), isEmpty);
      expect(states.last, isA<ResultStillPending>());
    });

    test('PENDING lúc đầu, rồi PAID sau khi server hỏi lại payOS', () async {
      boot();
      repo.statuses.addAll(['PENDING', 'PENDING', 'PAID']);

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.last, isA<ResultPaid>());
      expect(repo.calls.where((c) => c.startsWith('sync')), hasLength(2));
      expect(states.whereType<ResultChecking>().map((s) => s.attempt),
          containsAllInOrder([0, 1, 2]));
    });

    test('hết lần hỏi lại mà vẫn PENDING: nhờ xem lại sau, giữ banner', () async {
      boot();
      repo.statuses.addAll(List.filled(10, 'PENDING'));

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.check));

      expect(states.last, isA<ResultStillPending>());
      expect(repo.calls.where((c) => c.startsWith('sync')), hasLength(3)); // maxAttempts của test
      expect(container.read(pendingPaymentProvider), isNotNull,
          reason: 'có thể vẫn được trả: giữ banner');
    });

    test('FAILED: thất bại và quên khoản dở', () async {
      boot();
      repo.statuses.add('FAILED');

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.returned));

      expect(states.last, isA<ResultFailed>());
      expect(container.read(pendingPaymentProvider), isNull);
    });

    test('huỷ: báo server huỷ; huỷ lỗi cũng không sao', () async {
      boot();
      repo.cancelError = const ApiException(
          kind: ApiErrorKind.businessRule, message: 'x', statusCode: 422);

      final states = await openResult(PaymentResultArgs(pendingPayment(), PaymentHint.cancelled));

      expect(repo.calls, ['cancel:pay1']);
      expect(states.last, isA<ResultCancelled>());
      expect(container.read(pendingPaymentProvider), isNull);
    });

    test('link thử: chờ nút thử thay vì hỏi lại', () async {
      boot();
      repo.statuses.add('PENDING');

      final args = PaymentResultArgs(pendingPayment(checkoutUrl: _simulatedUrl),
          PaymentHint.returned,
          simulated: true);
      final states = await openResult(args);

      expect(states.last, isA<ResultSimulatedPending>());
      expect(repo.calls.where((c) => c.startsWith('sync')), isEmpty);
    });

    test('nút thử trả link và kết quả thành PAID', () async {
      boot();
      repo.statuses.add('PENDING');

      final args = PaymentResultArgs(pendingPayment(checkoutUrl: _simulatedUrl),
          PaymentHint.returned,
          simulated: true);
      final states = await openResult(args);
      await container.read(paymentResultProvider(args).notifier).simulatePay();
      await _settle();

      expect(states.last, isA<ResultPaid>());
      expect(container.read(pendingPaymentProvider), isNull);
    });

    test('nút thử trên server không ở chế độ thử: giải thích', () async {
      boot();
      repo.statuses.add('PENDING');
      repo.simulateError = const ApiException(
          kind: ApiErrorKind.notFound, message: 'x', statusCode: 404);

      final args = PaymentResultArgs(pendingPayment(checkoutUrl: _simulatedUrl),
          PaymentHint.returned,
          simulated: true);
      final states = await openResult(args);
      await container.read(paymentResultProvider(args).notifier).simulatePay();
      await _settle();

      final last = states.last as ResultSimulatedPending;
      expect(last.error, contains('PayOS:Mode=Simulated'));
      expect(last.paying, isFalse);
    });

    test('mất mạng: lỗi để thử lại, và khoản thanh toán KHÔNG bị huỷ trong lúc đó', () async {
      boot();
      repo.getError = _offline;

      final args = PaymentResultArgs(pendingPayment(), PaymentHint.check);
      final states = await openResult(args);
      expect(states.last, isA<ResultError>());
      expect(repo.calls.where((c) => c.startsWith('cancel')), isEmpty);
      expect(container.read(pendingPaymentProvider), isNotNull);

      repo.getError = null;
      repo.statuses.add('PAID');
      await container.read(paymentResultProvider(args).notifier).retry();
      await _settle();
      expect(states.last, isA<ResultPaid>());
    });
  });

  group('PendingPaymentController', () {
    test('giữ khoản dở của người đang đăng nhập qua lần khởi động lại', () async {
      boot();
      await container.read(pendingPaymentProvider.notifier).save(pendingPayment());

      final restarted = ProviderContainer(overrides: [
        sessionUserIdProvider.overrideWithValue('u1'),
        ...paymentTestOverrides(store),
      ]);
      addTearDown(restarted.dispose);

      expect(restarted.read(pendingPaymentProvider)?.paymentId, 'pay1');
    });

    test('khoản dở của tài khoản khác không hiện', () async {
      boot();
      await container
          .read(pendingPaymentProvider.notifier)
          .save(pendingPayment(userId: 'someone-else'));

      final other = ProviderContainer(overrides: [
        sessionUserIdProvider.overrideWithValue('u1'),
        ...paymentTestOverrides(store),
      ]);
      addTearDown(other.dispose);

      expect(other.read(pendingPaymentProvider), isNull);
    });

    test('link hết hạn bị bỏ', () async {
      boot();
      await container
          .read(pendingPaymentProvider.notifier)
          .save(pendingPayment(expiresAt: DateTime.utc(2020)));

      final later = ProviderContainer(overrides: [
        sessionUserIdProvider.overrideWithValue('u1'),
        ...paymentTestOverrides(store),
      ]);
      addTearDown(later.dispose);

      expect(later.read(pendingPaymentProvider), isNull);
      expect(store.data[PendingPaymentStore.key], isNull);
    });
  });

  group('PaymentLauncher', () {
    test('lưu khoản thanh toán TRƯỚC khi trang payOS mở, kèm đơn của nó', () async {
      boot();

      final pending = await container.read(paymentLauncherProvider).startOrderPayment('o1');

      expect(repo.calls, ['create:o1']);
      expect(pending.orderId, 'o1');
      expect(pending.context, PaymentContext.orderPayment);
      expect(pending.userId, 'u1');
      expect(container.read(pendingPaymentProvider)?.paymentId, 'pay1');
      expect(PendingPaymentStore(store).read()?.checkoutUrl, 'https://pay.payos.vn/web/pay1');
    });

    test('trả nợ không thuộc đơn nào', () async {
      boot();

      final pending = await container.read(paymentLauncherProvider).startDebtRepayment(500000);

      expect(repo.lastDebtAmount, 500000);
      expect(pending.orderId, isNull);
      expect(pending.isDebtRepayment, isTrue);
    });

    test('payOS không tới được: không lưu gì', () async {
      boot();
      repo.createError = const ApiException(
          kind: ApiErrorKind.unavailable, message: 'down', statusCode: 503);

      await expectLater(container.read(paymentLauncherProvider).startOrderPayment('o1'),
          throwsA(isA<ApiException>()));
      expect(container.read(pendingPaymentProvider), isNull);
    });

    test('chưa đăng nhập: báo phiên hết hạn, không lưu', () async {
      boot(userId: null);

      await expectLater(
          container.read(paymentLauncherProvider).startOrderPayment('o1'),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)));
      expect(container.read(pendingPaymentProvider), isNull);
    });
  });

  group('PendingPayment', () {
    test('nhận ra link thử và link hết hạn', () {
      expect(pendingPayment(checkoutUrl: _simulatedUrl).isSimulated, isTrue);
      expect(pendingPayment().isSimulated, isFalse);
      expect(pendingPayment(expiresAt: DateTime.utc(2020)).isExpired(DateTime.utc(2026)), isTrue);
      expect(pendingPayment().isExpired(DateTime.utc(2026)), isFalse);
    });

    test('mục lưu hỏng hoặc thiếu coi như không có', () {
      final mem = MemoryKeyValueStore();
      mem.data[PendingPaymentStore.key] = '{not json';
      expect(PendingPaymentStore(mem).read(), isNull);

      mem.data[PendingPaymentStore.key] = '{"paymentId":"x"}'; // thiếu người dùng
      expect(PendingPaymentStore(mem).read(), isNull);
    });

    test('ghi rồi đọc lại đủ trường', () async {
      final mem = MemoryKeyValueStore();
      final s = PendingPaymentStore(mem);
      await s.write(pendingPayment());
      final back = s.read()!;
      expect(back.paymentId, 'pay1');
      expect(back.orderId, 'o1');
      expect(back.amount, 1560000);
      expect(back.expiresAt, DateTime.utc(2099));
      await s.clear();
      expect(s.read(), isNull);
    });

    test('PayOsLink → PendingPayment giữ đúng link và hạn', () {
      final link = PayOsLink(
        paymentId: 'p9',
        paymentNumber: 'PM-9',
        amount: 100,
        checkoutUrl: 'https://pay.payos.vn/web/p9',
        status: 'PENDING',
        expiresAt: DateTime.utc(2099),
      );
      final p = PendingPayment.fromLink(link,
          context: PaymentContext.debtRepayment, userId: 'u1');
      expect(p.paymentId, 'p9');
      expect(p.isDebtRepayment, isTrue);
      expect(p.checkoutUrl, 'https://pay.payos.vn/web/p9');
    });
  });
}

/// Cho microtask bắt đầu kiểm tra và các `await` bên trong chạy hết.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
