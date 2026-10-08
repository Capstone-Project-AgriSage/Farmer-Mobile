import '../../../core/utils/json_utils.dart';

abstract final class PaymentContext {
  static const orderPayment = 'ORDER_PAYMENT';
  static const debtRepayment = 'DEBT_REPAYMENT';
}

abstract final class PaymentStatus {
  static const pending = 'PENDING';
  static const paid = 'PAID';
}

/// `POST /api/me/payments/payos`: a payOS payment link for an order, or for a debt repayment.
class PayosStart {
  const PayosStart({
    required this.paymentId,
    required this.paymentNumber,
    required this.amount,
    required this.checkoutUrl,
    required this.status,
    this.expiresAt,
  });

  final String paymentId;
  final String paymentNumber;
  final double amount;
  final String checkoutUrl;
  final DateTime? expiresAt;
  final String status;

  factory PayosStart.fromJson(Map<String, dynamic> json) => PayosStart(
        paymentId: asString(json['paymentId']),
        paymentNumber: asString(json['paymentNumber']),
        amount: asDouble(json['amount']),
        checkoutUrl: asString(json['checkoutUrl']),
        expiresAt: asDateTime(json['expiresAt']),
        status: asString(json['status']),
      );
}

/// One row of a payment list (`PaymentListItem`).
class PaymentListItem {
  const PaymentListItem({
    required this.id,
    required this.paymentNumber,
    required this.paymentContext,
    required this.paymentMethod,
    required this.amount,
    required this.status,
    this.confirmedAt,
    this.initiatedAt,
  });

  final String id;
  final String paymentNumber;
  final String paymentContext;
  final String paymentMethod;
  final double amount;
  final String status;
  final DateTime? confirmedAt;
  final DateTime? initiatedAt;

  /// When the money arrived, or else when the payment was started.
  DateTime? get when => confirmedAt ?? initiatedAt;

  factory PaymentListItem.fromJson(Map<String, dynamic> json) => PaymentListItem(
        id: asString(json['id']),
        paymentNumber: asString(json['paymentNumber']),
        paymentContext: asString(json['paymentContext']),
        paymentMethod: asString(json['paymentMethod']),
        amount: asDouble(json['amount']),
        status: asString(json['status']),
        confirmedAt: asDateTime(json['confirmedAt']),
        initiatedAt: asDateTime(json['initiatedAt']),
      );
}

class RefundInfo {
  const RefundInfo({required this.id, required this.refundNumber, required this.amount, required this.status});

  final String id;
  final String refundNumber;
  final double amount;
  final String status;

  bool get isCompleted => status == 'COMPLETED';

  factory RefundInfo.fromJson(Map<String, dynamic> json) => RefundInfo(
        id: asString(json['id']),
        refundNumber: asString(json['refundNumber']),
        amount: asDouble(json['amount']),
        status: asString(json['status']),
      );
}

/// `GET /api/me/orders/{id}/payments`: what an order costs, what is paid, what is left, and the payments themselves.
class OrderPaymentSummary {
  const OrderPaymentSummary({
    required this.orderId,
    required this.orderTotal,
    required this.paidAmount,
    required this.remainingToPay,
    required this.payments,
    required this.refunds,
  });

  final String orderId;
  final double orderTotal;
  final double paidAmount;
  final double remainingToPay;
  final List<PaymentListItem> payments;
  final List<RefundInfo> refunds;

  /// Cancelled payment attempts are noise to the farmer.
  List<PaymentListItem> get visiblePayments => payments.where((p) => p.status != 'CANCELLED').toList(growable: false);

  factory OrderPaymentSummary.fromJson(Map<String, dynamic> json) => OrderPaymentSummary(
        orderId: asString(json['orderId']),
        orderTotal: asDouble(json['orderTotal']),
        paidAmount: asDouble(json['paidAmount']),
        remainingToPay: asDouble(json['remainingToPay']),
        payments: asObjectList(json['payments']).map(PaymentListItem.fromJson).toList(growable: false),
        refunds: asObjectList(json['refunds']).map(RefundInfo.fromJson).toList(growable: false),
      );
}

/// What the server says about one payment (`PaymentResponse`). The app trusts this and nothing from the address of a
/// page: the `status=PAID` that payOS puts on its return link proves nothing.
class PaymentInfo {
  const PaymentInfo({
    required this.id,
    required this.paymentNumber,
    required this.paymentContext,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.confirmedAt,
    this.initiatedAt,
  });

  final String id;
  final String paymentNumber;
  final String paymentContext;
  final String? paymentMethod;
  final double amount;
  final String status;
  final DateTime? confirmedAt;
  final DateTime? initiatedAt;

  bool get isPaid => status == PaymentStatus.paid;
  bool get isPending => status == PaymentStatus.pending;

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
        id: asString(json['id']),
        paymentNumber: asString(json['paymentNumber']),
        paymentContext: asString(json['paymentContext']),
        paymentMethod: asStringOrNull(json['paymentMethod']),
        amount: asDouble(json['amount']),
        status: asString(json['status']),
        confirmedAt: asDateTime(json['confirmedAt']),
        initiatedAt: asDateTime(json['initiatedAt']),
      );
}
