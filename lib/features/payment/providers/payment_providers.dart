import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/app_prefs.dart';
import '../data/payment_models.dart';
import '../data/payment_repository.dart';
import '../data/pending_payment.dart';

final pendingPaymentStoreProvider = Provider<PendingPaymentStore>(
  (ref) => PendingPaymentStore(ref.watch(sharedPreferencesProvider)),
);

/// The farmer's unfinished payOS payment, or null. Another account's, or one whose link has expired, does not count.
class PendingPaymentController extends Notifier<PendingPayment?> {
  @override
  PendingPayment? build() {
    final userId = ref.watch(sessionUserIdProvider);
    final store = ref.watch(pendingPaymentStoreProvider);
    final saved = store.read();
    if (saved == null || userId == null || saved.userId != userId) return null;
    if (saved.isExpired(DateTime.now())) {
      store.clear();
      return null;
    }
    return saved;
  }

  Future<void> save(PendingPayment payment) async {
    await ref.read(pendingPaymentStoreProvider).write(payment);
    state = payment;
  }

  Future<void> clear() async {
    await ref.read(pendingPaymentStoreProvider).clear();
    state = null;
  }
}

final pendingPaymentProvider = NotifierProvider<PendingPaymentController, PendingPayment?>(PendingPaymentController.new);

/// Creates a payOS link and remembers it **before** the payOS page opens (see [PendingPayment]).
class PaymentLauncher {
  PaymentLauncher(this._ref);

  final Ref _ref;

  Future<PendingPayment> startOrderPayment(String orderId) async {
    final start = await _ref.read(paymentRepositoryProvider).startOrderPayment(orderId);
    return _remember(start, context: PaymentContext.orderPayment, orderId: orderId);
  }

  Future<PendingPayment> startDebtRepayment(int amount) async {
    final start = await _ref.read(paymentRepositoryProvider).startDebtRepayment(amount);
    return _remember(start, context: PaymentContext.debtRepayment);
  }

  Future<PendingPayment> _remember(PayosStart start, {required String context, String? orderId}) async {
    final userId = _ref.read(sessionUserIdProvider);
    if (userId == null) throw const AppException.sessionExpired();
    final pending = PendingPayment.fromStart(start, context: context, userId: userId, orderId: orderId);
    await _ref.read(pendingPaymentProvider.notifier).save(pending);
    return pending;
  }
}

final paymentLauncherProvider = Provider<PaymentLauncher>(PaymentLauncher.new);

// ── The result screen ────────────────────────────────────────────────────────────────────────────────────────────────

/// Why the result screen was opened. It decides only what to do first, never whether the payment succeeded.
enum PaymentHint {
  /// payOS sent the buyer back to the return page.
  returned,

  /// The buyer pressed cancel on the payOS page (or chose "Hủy giao dịch").
  cancelled,

  /// The buyer says they paid, or the app came back from a banking app: just ask the server.
  check,
}

class PaymentResultArgs {
  const PaymentResultArgs(this.payment, this.hint, {this.simulated = false});

  final PendingPayment payment;
  final PaymentHint hint;

  /// The return link carried `simulated=1` (the test gateway).
  final bool simulated;

  bool get isSimulated => simulated || payment.isSimulated;

  @override
  bool operator ==(Object other) =>
      other is PaymentResultArgs && other.payment.paymentId == payment.paymentId && other.hint == hint && other.simulated == simulated;

  @override
  int get hashCode => Object.hash(payment.paymentId, hint, simulated);
}

sealed class PaymentResultState {
  const PaymentResultState();
}

/// Asking the server; `attempt` counts the re-checks after the first answer.
class ResultChecking extends PaymentResultState {
  const ResultChecking({this.attempt = 0});
  final int attempt;
}

class ResultPaid extends PaymentResultState {
  const ResultPaid(this.payment);
  final PaymentInfo payment;
}

class ResultCancelled extends PaymentResultState {
  const ResultCancelled();
}

/// The payment failed, expired or was cancelled.
class ResultFailed extends PaymentResultState {
  const ResultFailed(this.message);
  final String message;
}

/// Still pending after the re-checks: money may be on its way, the farmer is asked to look again later.
class ResultStillPending extends PaymentResultState {
  const ResultStillPending(this.payment);
  final PaymentInfo payment;
}

/// The test gateway: nothing will arrive from payOS, so wait for the test button.
class ResultSimulatedPending extends PaymentResultState {
  const ResultSimulatedPending(this.payment, {this.paying = false, this.error});
  final PaymentInfo payment;
  final bool paying;
  final String? error;
}

/// Could not ask the server (no network...). The farmer can try again; nothing is cancelled meanwhile.
class ResultError extends PaymentResultState {
  const ResultError(this.error);
  final AppException error;
}

/// How long to wait between re-checks, and how many. Replaced in tests.
class PaymentPolling {
  const PaymentPolling({this.interval = const Duration(seconds: 2), this.maxAttempts = 5});
  final Duration interval;
  final int maxAttempts;
}

final paymentPollingProvider = Provider<PaymentPolling>((ref) => const PaymentPolling());

/// Confirms one payment with the server.
///
/// - cancelled: tells the server to cancel it, forgets it;
/// - otherwise reads the payment; if it is still PENDING it asks the server to re-check with payOS (the webhook may be
///   late) every [PaymentPolling.interval], up to [PaymentPolling.maxAttempts] times;
/// - a simulated link waits for the test button instead of polling.
class PaymentResultController extends AutoDisposeFamilyNotifier<PaymentResultState, PaymentResultArgs> {
  bool _disposed = false;

  PaymentRepository get _repo => ref.read(paymentRepositoryProvider);

  @override
  PaymentResultState build(PaymentResultArgs arg) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // Start after build returns, so the first state is "checking".
    Future.microtask(_start);
    return const ResultChecking();
  }

  Future<void> _start() async {
    if (arg.hint == PaymentHint.cancelled) {
      try {
        await _repo.cancel(arg.payment.paymentId);
      } on AppException {
        // Already cancelled or already settled: either way the farmer is done with this link.
      }
      if (_disposed) return;
      await _forget();
      if (!_disposed) state = const ResultCancelled();
      return;
    }
    await _check(0);
  }

  Future<void> retry() async {
    state = const ResultChecking();
    await _check(0);
  }

  Future<void> _check(int attempt) async {
    final polling = ref.read(paymentPollingProvider);
    try {
      final info = attempt == 0 ? await _repo.payment(arg.payment.paymentId) : await _repo.sync(arg.payment.paymentId);
      if (_disposed) return;

      if (info.isPaid) {
        await _forget();
        if (!_disposed) state = ResultPaid(info);
      } else if (info.isPending && arg.isSimulated) {
        state = ResultSimulatedPending(info);
      } else if (info.isPending && attempt < polling.maxAttempts) {
        state = ResultChecking(attempt: attempt + 1);
        await Future<void>.delayed(polling.interval);
        if (!_disposed) await _check(attempt + 1);
      } else if (info.isPending) {
        state = ResultStillPending(info);
      } else {
        await _forget();
        if (!_disposed) state = const ResultFailed('Thanh toán không thành công hoặc đã hết hạn.');
      }
    } on AppException catch (error) {
      if (!_disposed) state = ResultError(error);
    }
  }

  /// Test button (simulated links only): the server pays the link and settles it like a real status check.
  Future<void> simulatePay() async {
    final current = state;
    if (current is! ResultSimulatedPending || current.paying) return;
    state = ResultSimulatedPending(current.payment, paying: true);
    try {
      final info = await _repo.simulatePaid(arg.payment.paymentId);
      if (_disposed) return;
      if (info.isPaid) {
        await _forget();
        if (!_disposed) state = ResultPaid(info);
      } else {
        state = ResultSimulatedPending(info);
      }
    } on AppException catch (error) {
      if (_disposed) return;
      state = ResultSimulatedPending(
        current.payment,
        error: error.kind == AppErrorKind.notFound
            ? 'Máy chủ không ở chế độ thanh toán thử (PayOS:Mode=Simulated).'
            : 'Không thanh toán thử được. Bác tạo lại thanh toán rồi thử lại.',
      );
    }
  }

  Future<void> _forget() async {
    final pending = ref.read(pendingPaymentProvider);
    if (pending?.paymentId == arg.payment.paymentId) await ref.read(pendingPaymentProvider.notifier).clear();
  }
}

final paymentResultProvider = NotifierProvider.autoDispose
    .family<PaymentResultController, PaymentResultState, PaymentResultArgs>(PaymentResultController.new);
