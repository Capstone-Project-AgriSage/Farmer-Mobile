import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paged.dart';
import 'debt_models.dart';

/// `/api/me/debt*`: everything here is the farmer's own debt; the server never accepts another farmer's id.
class DebtRepository {
  DebtRepository(this._dio);

  final Dio _dio;

  /// The debt account, or null when the farmer has no credit profile and so no debt book (the server answers 404).
  Future<DebtAccount?> account() async {
    try {
      return await guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/debt');
        return DebtAccount.fromJson(response.data ?? const {});
      });
    } on AppException catch (error) {
      if (error.kind == AppErrorKind.notFound) return null;
      rethrow;
    }
  }

  /// The farmer's debts, optionally of one status. No credit profile means nothing to list, not an error.
  Future<Paged<DebtEntryListItem>> entries({String? status, int page = 1, int pageSize = 20}) async {
    try {
      return await guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/me/debt-entries',
          queryParameters: {
            if (status != null && status.isNotEmpty) 'status': status,
            'page': page,
            'pageSize': pageSize,
          },
        );
        return Paged.fromJson(response.data ?? const {}, DebtEntryListItem.fromJson);
      });
    } on AppException catch (error) {
      if (error.kind == AppErrorKind.notFound) return const Paged.empty();
      rethrow;
    }
  }

  Future<DebtEntryDetail> entry(String id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/debt-entries/$id');
        return DebtEntryDetail.fromJson(response.data ?? const {});
      });

  /// The store reviews it and keeps the amount, adjusts it or cancels the entry; payments are not blocked meanwhile.
  Future<DebtEntryDetail> dispute(String id, String reason) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/me/debt-entries/$id/dispute',
          data: {'reason': reason.trim()},
        );
        return DebtEntryDetail.fromJson(response.data ?? const {});
      });

  /// Which entries a repayment of `amount` would settle, oldest due date first.
  Future<AllocationPreview> allocationPreview(int amount) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/me/debt/allocation-preview',
          queryParameters: {'amount': amount},
        );
        return AllocationPreview.fromJson(response.data ?? const {});
      });
}

final debtRepositoryProvider = Provider<DebtRepository>((ref) => DebtRepository(ref.watch(dioProvider)));
