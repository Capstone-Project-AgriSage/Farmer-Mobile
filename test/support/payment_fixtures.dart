import 'package:farmer_mobile/features/payment/data/payment_models.dart';
import 'package:farmer_mobile/features/payment/data/pending_payment.dart';

// Shapes follow PayOsPaymentResponse and PaymentResponse (FLOW_2 §6).

const payosStartJson = {
  'paymentId': 'pay-1',
  'paymentNumber': 'PAY-20261008-0001',
  'amount': 1560000.0,
  'checkoutUrl': 'https://pay.payos.vn/web/abc',
  'qrCode': '000201...',
  'providerOrderCode': 1700000001,
  'expiresAt': '2099-01-01T00:00:00+00:00',
  'status': 'PENDING',
};

PendingPayment pendingPayment({
  String id = 'pay-1',
  String? orderId = 'o-1',
  String context = PaymentContext.orderPayment,
  String checkoutUrl = 'https://pay.payos.vn/web/abc',
  String userId = 'u1',
  DateTime? expiresAt,
}) =>
    PendingPayment(
      paymentId: id,
      paymentNumber: 'PAY-20261008-0001',
      context: context,
      amount: 1560000,
      checkoutUrl: checkoutUrl,
      userId: userId,
      orderId: orderId,
      expiresAt: expiresAt ?? DateTime.utc(2099),
    );

PaymentInfo paymentInfo(String status, {double amount = 1560000}) => PaymentInfo(
      id: 'pay-1',
      paymentNumber: 'PAY-20261008-0001',
      paymentContext: PaymentContext.orderPayment,
      amount: amount,
      status: status,
    );

const simulatedCheckoutUrl = 'http://localhost:5174/payments/payos/return?simulated=1&orderCode=1700000001';
