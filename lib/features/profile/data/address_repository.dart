import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'address_models.dart';

/// `/api/me/addresses`.
class AddressRepository {
  AddressRepository(this._dio);

  final Dio _dio;

  Future<List<Address>> list() => guardApi(() async {
        final response = await _dio.get<List<dynamic>>('/api/me/addresses');
        return (response.data ?? const []).whereType<Map<String, dynamic>>().map(Address.fromJson).toList(growable: false);
      });

  Future<Address> create(AddressInput input) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/me/addresses', data: input.toJson());
        return Address.fromJson(response.data ?? const {});
      });

  Future<Address> update(String id, AddressInput input) => guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>('/api/me/addresses/$id', data: input.toJson());
        return Address.fromJson(response.data ?? const {});
      });

  Future<void> delete(String id) => guardApi(() async {
        await _dio.delete<void>('/api/me/addresses/$id');
      });

  Future<Address> setDefault(String id) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>('/api/me/addresses/$id/set-default');
        return Address.fromJson(response.data ?? const {});
      });
}

final addressRepositoryProvider = Provider<AddressRepository>((ref) => AddressRepository(ref.watch(dioProvider)));
