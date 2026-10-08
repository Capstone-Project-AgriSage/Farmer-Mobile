import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
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
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) => OrderRepository(ref.watch(dioProvider)));
