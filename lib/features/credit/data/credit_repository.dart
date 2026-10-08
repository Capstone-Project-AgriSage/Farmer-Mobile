import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'credit_models.dart';

class CreditRepository {
  CreditRepository(this._dio);

  final Dio _dio;

  /// The credit line, or null when the farmer has no credit profile (the server answers 404).
  Future<MyCredit?> myCredit() async {
    try {
      return await guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/credit');
        return MyCredit.fromJson(response.data ?? const {});
      });
    } on AppException catch (error) {
      if (error.kind == AppErrorKind.notFound) return null;
      rethrow;
    }
  }
}

final creditRepositoryProvider = Provider<CreditRepository>((ref) => CreditRepository(ref.watch(dioProvider)));
