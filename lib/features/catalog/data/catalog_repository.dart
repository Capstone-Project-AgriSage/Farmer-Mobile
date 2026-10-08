import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paged.dart';
import 'catalog_models.dart';

/// What the product list asks for. Two queries are the same when both fields match, so the provider can cache them.
class ProductQuery {
  const ProductQuery({this.search = '', this.categoryId = ''});

  final String search;
  final String categoryId;

  ProductQuery copyWith({String? search, String? categoryId}) =>
      ProductQuery(search: search ?? this.search, categoryId: categoryId ?? this.categoryId);

  @override
  bool operator ==(Object other) =>
      other is ProductQuery && other.search == search && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(search, categoryId);
}

/// The public catalog (no sign-in needed).
class CatalogRepository {
  CatalogRepository(this._dio);

  final Dio _dio;

  Future<List<CatalogCategory>> categories() => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('/api/catalog/categories');
        final list = (response.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogCategory.fromJson)
            .where((c) => c.isActive)
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return list;
      });

  Future<Paged<CatalogProductListItem>> products({
    ProductQuery query = const ProductQuery(),
    int page = 1,
    int pageSize = 20,
  }) =>
      guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/catalog/products',
          queryParameters: {
            if (query.categoryId.isNotEmpty) 'CategoryId': query.categoryId,
            if (query.search.trim().isNotEmpty) 'Search': query.search.trim(),
            'Page': page,
            'PageSize': pageSize,
          },
        );
        return Paged.fromJson(response.data ?? const {}, CatalogProductListItem.fromJson);
      });

  Future<CatalogProduct> product(String id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/catalog/products/$id');
        return CatalogProduct.fromJson(response.data ?? const {});
      });
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => CatalogRepository(ref.watch(dioProvider)));
