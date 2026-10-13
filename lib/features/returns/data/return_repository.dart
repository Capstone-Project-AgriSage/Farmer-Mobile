import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'return_models.dart';

/// Trả hàng của nông dân (`/api/me/returns`, `/api/me/orders/{id}/returnable`).
class ReturnRepository {
  ReturnRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;
  static const maxTextLength = 1000;

  /// Những món của đơn còn có thể trả.
  Future<Returnable> returnable(String orderId) => apiCall(
        () async {
          final res = await _dio
              .get<Map<String, dynamic>>('/api/me/orders/$orderId/returnable');
          return Returnable.fromJson(res.data!);
        },
        messages: {404: 'Không tìm thấy đơn hàng.'},
      );

  /// Gửi yêu cầu trả hàng. [lines] đã được chia theo nguồn (xem [ReturnLineRequest.allocate]).
  Future<ReturnDetail> create({
    required String orderId,
    required List<ReturnLineRequest> lines,
    String? note,
  }) =>
      apiCall(
        () async {
          final n = note?.trim();
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/returns',
            data: {
              'orderId': orderId,
              'items': [for (final l in lines) l.toJson()],
              if (n != null && n.isNotEmpty) 'note': n,
            },
          );
          return ReturnDetail.fromJson(res.data!);
        },
        messages: {404: 'Không tìm thấy đơn hàng.'},
        map: (e) {
          final d = e.detail ?? '';
          if (e.statusCode == 422) {
            if (d.contains('exceeds')) {
              return e.withMessage(
                  'Số lượng trả vượt quá số lượng có thể trả. Vui lòng tải lại và chọn lại.');
            }
            if (d.contains('fulfillment source')) {
              return e.withMessage(
                  'Hàng này chưa được giao hoặc đã trả hết, không thể yêu cầu trả.');
            }
          }
          if (e.statusCode == 400) {
            return e.withMessage(
                'Yêu cầu trả hàng chưa hợp lệ. Vui lòng kiểm tra số lượng, lý do và ghi chú.');
          }
          return e;
        },
      );

  Future<PagedResult<ReturnSummary>> list({int page = 1}) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/returns',
          queryParameters: cleanQuery({'page': page, 'pageSize': pageSize}),
        );
        return PagedResult.fromJson(res.data!, ReturnSummary.fromJson);
      });

  Future<ReturnDetail> get(String id) => apiCall(
        () async {
          final res = await _dio.get<Map<String, dynamic>>('/api/me/returns/$id');
          return ReturnDetail.fromJson(res.data!);
        },
        messages: {404: 'Không tìm thấy yêu cầu trả hàng.'},
      );

  /// Chỉ huỷ được khi cửa hàng chưa duyệt.
  Future<ReturnDetail> cancel(String id, String reason) => apiCall(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/returns/$id/cancel',
            data: {'reason': reason.trim()},
          );
          return ReturnDetail.fromJson(res.data!);
        },
        messages: {
          404: 'Không tìm thấy yêu cầu trả hàng.',
          400: 'Vui lòng nhập lý do huỷ (tối đa $maxTextLength ký tự).',
        },
        map: (e) => e.statusCode == 422
            ? e.withMessage('Cửa hàng đã xử lý yêu cầu này nên không thể huỷ.')
            : e,
      );
}

final returnRepositoryProvider =
    Provider<ReturnRepository>((ref) => ReturnRepository(ref.watch(dioProvider)));
