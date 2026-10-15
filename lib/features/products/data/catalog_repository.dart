import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'catalog_models.dart';

/// Catalog công khai (`/api/catalog/*`), không cần đăng nhập.
class CatalogRepository {
  CatalogRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;

  /// Backend giới hạn từ khoá 100 ký tự.
  static const maxSearchLength = 100;

  Future<List<CategoryNode>> categories() => apiCall(() async {
        final res = await _dio.get<List<dynamic>>('/api/catalog/categories');
        return [
          for (final c in res.data!) CategoryNode.fromJson(c as Map<String, dynamic>),
        ];
      });

  /// Lọc theo danh mục bao gồm cả danh mục con.
  Future<PagedResult<CatalogProduct>> products({
    int page = 1,
    int pageSize = pageSize,
    String? categoryId,
    String? search,
  }) =>
      apiCall(() async {
        final term = search?.trim();
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/catalog/products',
          queryParameters: cleanQuery({
            'page': page,
            'pageSize': pageSize,
            'categoryId': categoryId,
            'search': (term == null || term.length <= maxSearchLength)
                ? term
                : term.substring(0, maxSearchLength),
          }),
        );
        return PagedResult.fromJson(res.data!, CatalogProduct.fromJson);
      });

  Future<ProductDetail> product(String id) => apiCall(
        () async {
          final res =
              await _dio.get<Map<String, dynamic>>('/api/catalog/products/$id');
          return ProductDetail.fromJson(res.data!);
        },
        messages: {404: 'Sản phẩm không còn được bán hoặc không tồn tại.'},
      );
}

/// Giỏ hàng của nông dân (`/api/me/cart`). Mỗi thao tác trả về giỏ mới nhất.
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  /// Giới hạn phía app cho mỗi dòng (backend cho tới 100 triệu).
  static const maxQuantity = 9999;

  static const _notFound = 'Sản phẩm này không còn trong giỏ. Giỏ hàng đã được tải lại.';
  static const _unsellable =
      'Sản phẩm hoặc quy cách này hiện không thể đặt mua.';

  Future<Cart> get() => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>('/api/me/cart');
        return Cart.fromJson(res.data!);
      });

  /// Thêm cùng sản phẩm + quy cách lần nữa sẽ CỘNG DỒN số lượng.
  Future<Cart> add({
    required String storeProductId,
    required String packagingId,
    required int quantity,
  }) =>
      apiCall(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/cart/items',
            data: {
              'storeProductId': storeProductId,
              'productPackagingId': packagingId,
              'quantity': quantity,
            },
          );
          return Cart.fromJson(res.data!);
        },
        messages: {422: _unsellable},
      );

  /// THAY số lượng của một dòng.
  Future<Cart> setQuantity(String itemId, int quantity) => apiCall(
        () async {
          final res = await _dio.put<Map<String, dynamic>>(
            '/api/me/cart/items/$itemId',
            data: {'quantity': quantity},
          );
          return Cart.fromJson(res.data!);
        },
        messages: {404: _notFound, 422: _unsellable},
      );

  Future<Cart> remove(String itemId) => apiCall(
        () async {
          final res = await _dio
              .delete<Map<String, dynamic>>('/api/me/cart/items/$itemId');
          return Cart.fromJson(res.data!);
        },
        messages: {404: _notFound},
      );

  Future<void> clear() => apiCall(() => _dio.delete<void>('/api/me/cart'));
}

final catalogRepositoryProvider =
    Provider<CatalogRepository>((ref) => CatalogRepository(ref.watch(dioProvider)));

final cartRepositoryProvider =
    Provider<CartRepository>((ref) => CartRepository(ref.watch(dioProvider)));
