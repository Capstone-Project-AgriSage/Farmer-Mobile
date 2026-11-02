import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'advisory_models.dart';

/// Tư vấn vật tư: từ một vấn đề trên ruộng lúa đến sản phẩm, số lượng cho diện tích và giỏ hàng
/// (`/api/me/advisory`, ADVISORY.md mục 5). Giá và số lượng do server tính; app không tự tính.
class AdvisoryRepository {
  AdvisoryRepository(this._dio);

  final Dio _dio;

  static const maxSearchLength = 100;
  static const pageSize = 50;

  /// Giới hạn của server: diện tích lớn hơn 0 và tối đa 1.000.000 m².
  static const maxAreaSqm = 1000000.0;

  /// Tìm vấn đề theo tên, từ khoá, triệu chứng (không phân biệt dấu). Bỏ trống = liệt kê tất cả.
  Future<PagedResult<AdvisoryProblem>> problems({String? search, String? type, int page = 1}) => apiCall(
        () async {
          final res = await _dio.get<Map<String, dynamic>>(
            '/api/me/advisory/problems',
            queryParameters: cleanQuery({
              'search': search?.trim(),
              'type': type,
              'page': page,
              'pageSize': pageSize,
            }),
          );
          return PagedResult.fromJson(res.data!, AdvisoryProblem.fromJson);
        },
        messages: {
          400: 'Từ khoá tìm kiếm chưa hợp lệ.',
        },
      );

  /// Sản phẩm cho vấn đề, tính theo bảng giá của nông dân; mỗi lần gọi được ghi lại thành một ca tư vấn.
  Future<AdvisoryRecommendation> recommend(AdvisoryQuery query) => apiCall(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/advisory/recommendations',
            data: {
              'diseaseId': query.diseaseId,
              if (query.areaSqm != null) 'areaSqm': query.areaSqm,
              if (query.growthStage != null) 'growthStage': query.growthStage,
              if (query.diagnosisCaseId != null) 'diagnosisCaseId': query.diagnosisCaseId,
            },
          );
          return AdvisoryRecommendation.fromJson(res.data!);
        },
        messages: {
          400: 'Diện tích hoặc giai đoạn chưa hợp lệ.',
          404: 'Không tìm thấy vấn đề này. Hãy chọn lại.',
        },
      );
}

final advisoryRepositoryProvider =
    Provider<AdvisoryRepository>((ref) => AdvisoryRepository(ref.watch(dioProvider)));
