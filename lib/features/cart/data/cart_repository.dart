import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'cart_models.dart';

/// `/api/me/cart`: every call answers with the whole cart, re-priced by the server.
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  Future<Cart> get() => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/cart');
        return Cart.fromJson(response.data ?? const {});
      });

  /// Adding a product + packaging that is already in the cart adds to that line's quantity.
  Future<Cart> addItem({
    required String storeProductId,
    required String productPackagingId,
    required int quantity,
  }) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/me/cart/items',
          data: {
            'storeProductId': storeProductId,
            'productPackagingId': productPackagingId,
            'quantity': quantity,
          },
        );
        return Cart.fromJson(response.data ?? const {});
      });

  Future<Cart> updateQuantity(String itemId, int quantity) => guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>(
          '/api/me/cart/items/$itemId',
          data: {'quantity': quantity},
        );
        return Cart.fromJson(response.data ?? const {});
      });

  Future<Cart> removeItem(String itemId) => guardApi(() async {
        final response = await _dio.delete<Map<String, dynamic>>('/api/me/cart/items/$itemId');
        return Cart.fromJson(response.data ?? const {});
      });

  Future<void> clear() => guardApi(() async {
        await _dio.delete<void>('/api/me/cart');
      });
}

final cartRepositoryProvider = Provider<CartRepository>((ref) => CartRepository(ref.watch(dioProvider)));
