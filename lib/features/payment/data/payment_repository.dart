import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'payment_models.dart';

class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  /// A payOS link for the unpaid rest of an order. `amount` stays null: the server works it out.
  Future<PayosStart> startOrderPayment(String orderId) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/me/payments/payos',
          data: {'paymentContext': PaymentContext.orderPayment, 'orderId': orderId, 'amount': null},
        );
        return PayosStart.fromJson(response.data ?? const {});
      });

  /// A payOS link to pay `amount` (whole VND) towards the farmer's debt; the server settles the oldest debts first.
  Future<PayosStart> startDebtRepayment(int amount) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/me/payments/payos',
          data: {'paymentContext': PaymentContext.debtRepayment, 'orderId': null, 'amount': amount},
        );
        return PayosStart.fromJson(response.data ?? const {});
      });

  Future<PaymentInfo> payment(String id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/payments/$id');
        return PaymentInfo.fromJson(response.data ?? const {});
      });

  /// Asks the server to check the payment with payOS again (the webhook can be late).
  Future<PaymentInfo> sync(String id) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/payments/$id/sync');
        return PaymentInfo.fromJson(response.data ?? const {});
      });

  Future<PaymentInfo> cancel(String id) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/me/payments/$id/cancel');
        return PaymentInfo.fromJson(response.data ?? const {});
      });

  /// Test environment only: the API must run with `PayOS:Mode=Simulated` (it answers 404 otherwise).
  Future<PaymentInfo> simulatePaid(String id) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/payments/$id/simulate-paid');
        return PaymentInfo.fromJson(response.data ?? const {});
      });
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => PaymentRepository(ref.watch(dioProvider)));
