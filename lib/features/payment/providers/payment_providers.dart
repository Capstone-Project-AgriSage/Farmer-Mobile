import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/app_prefs.dart';
import '../../debt/providers/debt_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../orders/data/order_models.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/providers/order_providers.dart';
import '../data/pending_payment.dart';

// Luồng payOS trong app (thiết kế của nhánh feature/mobile-diagnosis, nối vào kiến trúc hiện tại):
// tạo link → LƯU khoản thanh toán dở → mở trang payOS trong WebView → màn kết quả luôn hỏi server.

final pendingPaymentStoreProvider = Provider<PendingPaymentStore>(
  (ref) => PendingPaymentStore(PrefsKeyValueStore(ref.watch(sharedPreferencesProvider))),
);

/// Id người đang đăng nhập (null khi chưa). Tách riêng để test dễ ghi đè.
final sessionUserIdProvider =
    Provider<String?>((ref) => ref.watch(sessionProvider.select((s) => s.user?.id)));

/// Khoản thanh toán payOS dở của nông dân này, hoặc null. Của tài khoản khác, hoặc link đã hết hạn thì không tính.
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

final pendingPaymentProvider =
    NotifierProvider<PendingPaymentController, PendingPayment?>(PendingPaymentController.new);

/// Tạo link payOS và nhớ nó **trước khi** trang payOS mở (xem [PendingPayment]).
class PaymentLauncher {
  PaymentLauncher(this._ref);

  final Ref _ref;

  Future<PendingPayment> startOrderPayment(String orderId) async {
    final link = await _ref.read(paymentRepositoryProvider).createForOrder(orderId);
    return _remember(link, context: PaymentContext.orderPayment, orderId: orderId);
  }

  Future<PendingPayment> startDebtRepayment(int amount) async {
    final link = await _ref.read(paymentRepositoryProvider).createForDebt(amount.toDouble());
    return _remember(link, context: PaymentContext.debtRepayment);
  }

  Future<PendingPayment> _remember(PayOsLink link,
      {required String context, String? orderId}) async {
    final userId = _ref.read(sessionUserIdProvider);
    if (userId == null) {
      throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    final pending =
        PendingPayment.fromLink(link, context: context, userId: userId, orderId: orderId);
    await _ref.read(pendingPaymentProvider.notifier).save(pending);
    return pending;
  }
}

final paymentLauncherProvider = Provider<PaymentLauncher>(PaymentLauncher.new);

// ── Màn kết quả ───────────────────────────────────────────────────────────────

/// Vì sao mở màn kết quả. Nó chỉ quyết định việc làm đầu tiên, KHÔNG quyết định thanh toán có thành công không.
enum PaymentHint {
  /// payOS đưa người mua về trang trả về.
  returned,

  /// Người mua bấm huỷ trên trang payOS (hoặc chọn "Hủy giao dịch").
  cancelled,

  /// Người mua nói đã trả, hoặc app vừa quay lại từ app ngân hàng: chỉ cần hỏi server.
  check,
}

class PaymentResultArgs {
  const PaymentResultArgs(this.payment, this.hint, {this.simulated = false});

  final PendingPayment payment;
  final PaymentHint hint;

  /// Link trả về có `simulated=1` (cổng thanh toán thử).
  final bool simulated;

  bool get isSimulated => simulated || payment.isSimulated;

  @override
  bool operator ==(Object other) =>
      other is PaymentResultArgs &&
      other.payment.paymentId == payment.paymentId &&
      other.hint == hint &&
      other.simulated == simulated;

  @override
  int get hashCode => Object.hash(payment.paymentId, hint, simulated);
}

sealed class PaymentResultState {
  const PaymentResultState();
}

/// Đang hỏi server; `attempt` đếm số lần hỏi lại sau câu trả lời đầu.
class ResultChecking extends PaymentResultState {
  const ResultChecking({this.attempt = 0});
  final int attempt;
}

class ResultPaid extends PaymentResultState {
  const ResultPaid(this.payment);
  final Payment payment;
}

class ResultCancelled extends PaymentResultState {
  const ResultCancelled();
}

/// Thanh toán thất bại, hết hạn hoặc bị huỷ.
class ResultFailed extends PaymentResultState {
  const ResultFailed(this.message);
  final String message;
}

/// Sau các lần hỏi lại vẫn PENDING: tiền có thể đang trên đường, nhờ nông dân xem lại sau.
class ResultStillPending extends PaymentResultState {
  const ResultStillPending(this.payment);
  final Payment payment;
}

/// Cổng thanh toán thử: sẽ không có gì đến từ payOS, nên chờ nút thử.
class ResultSimulatedPending extends PaymentResultState {
  const ResultSimulatedPending(this.payment, {this.paying = false, this.error});
  final Payment payment;
  final bool paying;
  final String? error;
}

/// Không hỏi được server (mất mạng...). Nông dân thử lại được; trong lúc đó không có gì bị huỷ.
class ResultError extends PaymentResultState {
  const ResultError(this.error);
  final ApiException error;
}

/// Chờ bao lâu giữa các lần hỏi lại và hỏi tối đa mấy lần. Test thay bằng giá trị khác.
class PaymentPolling {
  const PaymentPolling({this.interval = const Duration(seconds: 2), this.maxAttempts = 5});
  final Duration interval;
  final int maxAttempts;
}

final paymentPollingProvider = Provider<PaymentPolling>((ref) => const PaymentPolling());

/// Xác nhận MỘT khoản thanh toán với server.
///
/// - huỷ: báo server huỷ, rồi quên nó;
/// - còn lại: đọc khoản thanh toán; nếu vẫn PENDING thì nhờ server hỏi lại payOS (webhook có thể chậm)
///   mỗi [PaymentPolling.interval], tối đa [PaymentPolling.maxAttempts] lần;
/// - link thử thì chờ nút thử thay vì hỏi lại.
class PaymentResultController
    extends AutoDisposeFamilyNotifier<PaymentResultState, PaymentResultArgs> {
  bool _disposed = false;

  PaymentRepository get _repo => ref.read(paymentRepositoryProvider);

  @override
  PaymentResultState build(PaymentResultArgs arg) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // Chạy sau khi build xong để trạng thái đầu tiên là "đang kiểm tra".
    Future.microtask(_start);
    return const ResultChecking();
  }

  Future<void> _start() async {
    if (arg.hint == PaymentHint.cancelled) {
      try {
        await _repo.cancel(arg.payment.paymentId);
      } on ApiException {
        // Đã huỷ hoặc đã thanh toán xong: dù sao nông dân cũng xong với link này.
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
      final info = attempt == 0
          ? await _repo.get(arg.payment.paymentId)
          : await _repo.sync(arg.payment.paymentId);
      if (_disposed) return;

      if (info.isPaid) {
        await _forget();
        if (!_disposed) {
          state = ResultPaid(info);
          _refreshAfterPaid();
        }
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
        if (!_disposed) {
          state = const ResultFailed('Thanh toán không thành công hoặc đã hết hạn.');
        }
      }
    } on ApiException catch (error) {
      if (!_disposed) state = ResultError(error);
    }
  }

  /// Nút thử (chỉ link thử): server tự trả link rồi quyết toán như một lần kiểm tra thật.
  Future<void> simulatePay() async {
    final current = state;
    if (current is! ResultSimulatedPending || current.paying) return;
    state = ResultSimulatedPending(current.payment, paying: true);
    try {
      final info = await _repo.simulatePaid(arg.payment.paymentId);
      if (_disposed) return;
      if (info.isPaid) {
        await _forget();
        if (!_disposed) {
          state = ResultPaid(info);
          _refreshAfterPaid();
        }
      } else {
        state = ResultSimulatedPending(info);
      }
    } on ApiException catch (error) {
      if (_disposed) return;
      state = ResultSimulatedPending(
        current.payment,
        error: error.kind == ApiErrorKind.notFound
            ? 'Máy chủ không ở chế độ thanh toán thử (PayOS:Mode=Simulated).'
            : 'Không thanh toán thử được. Bạn tạo lại thanh toán rồi thử lại.',
      );
    }
  }

  /// Tiền vào làm đổi đơn hàng hoặc công nợ: mọi nơi đang hiện chúng phải hỏi lại server.
  void _refreshAfterPaid() {
    ref
      ..invalidate(myOrdersProvider)
      ..invalidate(homeOrderStatsProvider)
      ..invalidate(debtAccountProvider)
      ..invalidate(upcomingDebtsProvider)
      ..invalidate(myDebtEntriesProvider)
      ..invalidate(debtRepaymentsProvider);
    final orderId = arg.payment.orderId;
    if (orderId != null) {
      ref
        ..invalidate(orderDetailProvider(orderId))
        ..invalidate(orderPaymentsProvider(orderId));
    }
  }

  Future<void> _forget() async {
    final pending = ref.read(pendingPaymentProvider);
    if (pending?.paymentId == arg.payment.paymentId) {
      await ref.read(pendingPaymentProvider.notifier).clear();
    }
  }
}

final paymentResultProvider = NotifierProvider.autoDispose
    .family<PaymentResultController, PaymentResultState, PaymentResultArgs>(
        PaymentResultController.new);
