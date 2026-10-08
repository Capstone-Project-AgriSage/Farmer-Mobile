import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/json_utils.dart';
import 'payment_models.dart';

/// A payOS payment the farmer has started and not finished.
///
/// payOS sends the buyer back with its own order code only, and the server has no lookup by that code, so the payment
/// id is saved **before** the payOS page opens. That is also what lets the app find the payment again after it was
/// killed while the farmer was in a banking app. Nothing secret is stored: the link is the public pay page.
class PendingPayment {
  const PendingPayment({
    required this.paymentId,
    required this.paymentNumber,
    required this.context,
    required this.amount,
    required this.checkoutUrl,
    required this.userId,
    this.orderId,
    this.expiresAt,
  });

  final String paymentId;
  final String paymentNumber;

  /// [PaymentContext.orderPayment] or [PaymentContext.debtRepayment].
  final String context;
  final double amount;
  final String checkoutUrl;

  /// The farmer it belongs to, so another account on the same phone never sees it.
  final String userId;

  /// Null for a debt repayment: it belongs to no single order.
  final String? orderId;
  final DateTime? expiresAt;

  bool get isDebtRepayment => context == PaymentContext.debtRepayment;

  /// The test gateway marks its links `simulated=1`.
  bool get isSimulated => Uri.tryParse(checkoutUrl)?.queryParameters['simulated'] == '1';

  bool isExpired(DateTime now) => expiresAt != null && !now.toUtc().isBefore(expiresAt!);

  factory PendingPayment.fromStart(
    PayosStart start, {
    required String context,
    required String userId,
    String? orderId,
  }) =>
      PendingPayment(
        paymentId: start.paymentId,
        paymentNumber: start.paymentNumber,
        context: context,
        amount: start.amount,
        checkoutUrl: start.checkoutUrl,
        userId: userId,
        orderId: orderId,
        expiresAt: start.expiresAt,
      );

  Map<String, dynamic> toJson() => {
        'paymentId': paymentId,
        'paymentNumber': paymentNumber,
        'context': context,
        'amount': amount,
        'checkoutUrl': checkoutUrl,
        'userId': userId,
        'orderId': orderId,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
      };

  static PendingPayment? fromJson(Map<String, dynamic> json) {
    final paymentId = asString(json['paymentId']);
    final userId = asString(json['userId']);
    if (paymentId.isEmpty || userId.isEmpty) return null;
    return PendingPayment(
      paymentId: paymentId,
      paymentNumber: asString(json['paymentNumber']),
      context: asString(json['context'], PaymentContext.orderPayment),
      amount: asDouble(json['amount']),
      checkoutUrl: asString(json['checkoutUrl']),
      userId: userId,
      orderId: asStringOrNull(json['orderId']),
      expiresAt: asDateTime(json['expiresAt']),
    );
  }
}

/// Keeps the unfinished payment between app launches (plain preferences, no secrets).
class PendingPaymentStore {
  PendingPaymentStore(this._prefs);

  static const _key = 'agrisage.pending_payment';

  final SharedPreferences _prefs;

  PendingPayment? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? PendingPayment.fromJson(decoded) : null;
    } catch (_) {
      return null; // a damaged entry is the same as none
    }
  }

  static String encode(PendingPayment payment) => jsonEncode(payment.toJson());

  Future<void> write(PendingPayment payment) => _prefs.setString(_key, encode(payment));

  Future<void> clear() => _prefs.remove(_key);
}
