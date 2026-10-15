import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../orders/data/order_models.dart';

/// Ngữ cảnh của khoản thanh toán payOS (`paymentContext` của backend).
abstract final class PaymentContext {
  static const orderPayment = 'ORDER_PAYMENT';
  static const debtRepayment = 'DEBT_REPAYMENT';
}

/// Một khoản thanh toán payOS nông dân đã bắt đầu mà chưa xong.
///
/// payOS chỉ gửi người mua quay lại với mã đơn của riêng nó, còn server không tra được theo mã
/// đó, nên app lưu `paymentId` **trước khi mở trang payOS**. Nhờ vậy khi app bị tắt lúc người dùng
/// đang ở app ngân hàng, mở lại vẫn tìm thấy khoản thanh toán. Không lưu bí mật nào: link chỉ là
/// trang thanh toán công khai.
///
/// (Thiết kế của nhánh feature/mobile-diagnosis, chuyển sang kiến trúc hiện tại.)
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

  /// [PaymentContext.orderPayment] hoặc [PaymentContext.debtRepayment].
  final String context;
  final double amount;
  final String checkoutUrl;

  /// Chủ của khoản thanh toán, để tài khoản khác trên cùng điện thoại không thấy nó.
  final String userId;

  /// null với trả nợ: không thuộc đơn nào.
  final String? orderId;
  final DateTime? expiresAt;

  bool get isDebtRepayment => context == PaymentContext.debtRepayment;

  /// Cổng thanh toán thử đánh dấu link bằng `simulated=1`.
  bool get isSimulated =>
      Uri.tryParse(checkoutUrl)?.queryParameters['simulated'] == '1';

  bool isExpired(DateTime now) =>
      expiresAt != null && !now.toUtc().isBefore(expiresAt!.toUtc());

  factory PendingPayment.fromLink(
    PayOsLink link, {
    required String context,
    required String userId,
    String? orderId,
  }) =>
      PendingPayment(
        paymentId: link.paymentId,
        paymentNumber: link.paymentNumber,
        context: context,
        amount: link.amount,
        checkoutUrl: link.checkoutUrl,
        userId: userId,
        orderId: orderId,
        expiresAt: link.expiresAt,
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
    final paymentId = json['paymentId'];
    final userId = json['userId'];
    if (paymentId is! String || paymentId.isEmpty) return null;
    if (userId is! String || userId.isEmpty) return null;
    final expires = json['expiresAt'];
    return PendingPayment(
      paymentId: paymentId,
      paymentNumber: json['paymentNumber'] as String? ?? '',
      context: json['context'] as String? ?? PaymentContext.orderPayment,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      checkoutUrl: json['checkoutUrl'] as String? ?? '',
      userId: userId,
      orderId: json['orderId'] as String?,
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
    );
  }
}

/// Kho khoá-giá trị tối thiểu mà [PendingPaymentStore] cần (để test thay bằng bộ nhớ).
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// [KeyValueStore] trên `shared_preferences`.
class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Giữ khoản thanh toán dở giữa các lần mở app (preferences thường, không bí mật).
class PendingPaymentStore {
  PendingPaymentStore(this._store);

  static const key = 'agrisage.pending_payment';

  final KeyValueStore _store;

  PendingPayment? read() {
    final raw = _store.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? PendingPayment.fromJson(decoded) : null;
    } catch (_) {
      return null; // mục hỏng coi như không có
    }
  }

  Future<void> write(PendingPayment payment) =>
      _store.setString(key, jsonEncode(payment.toJson()));

  Future<void> clear() => _store.remove(key);
}
