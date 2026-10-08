import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paged.dart';
import '../../payment/data/payment_models.dart';
import 'delivery_models.dart';
import 'order_models.dart';

/// `/api/me/orders`.
class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  /// Creates the order from the farmer's active cart and empties that cart (the server does both).
  /// Never retried automatically: a request that timed out may still have created the order.
  Future<Order> checkout(CheckoutInput input) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/me/orders', data: input.toJson());
        return Order.fromJson(response.data ?? const {});
      });

  /// The farmer's orders, newest first. The server filters by one status at a time.
  Future<Paged<OrderListItem>> list({String? status, int page = 1, int pageSize = 20}) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/me/orders',
          queryParameters: {
            if (status != null && status.isNotEmpty) 'status': status,
            'page': page,
            'pageSize': pageSize,
          },
        );
        return Paged.fromJson(response.data ?? const {}, OrderListItem.fromJson);
      });

  Future<Order> get(String id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/orders/$id');
        return Order.fromJson(response.data ?? const {});
      });

  /// Only an order still waiting for the store's confirmation can be cancelled online.
  Future<Order> cancel(String id, {String? reason}) => guardApi(() async {
        final text = reason?.trim();
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/me/orders/$id/cancel',
          data: {'reason': (text == null || text.isEmpty) ? null : text},
        );
        return Order.fromJson(response.data ?? const {});
      });

  Future<OrderPaymentSummary> payments(String id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/orders/$id/payments');
        return OrderPaymentSummary.fromJson(response.data ?? const {});
      });

  Future<List<MyDelivery>> deliveries(String id) => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('/api/me/orders/$id/deliveries');
        return (response.data ?? const []).whereType<Map<String, dynamic>>().map(MyDelivery.fromJson).toList(growable: false);
      });
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository(ref.watch(dioProvider)));
