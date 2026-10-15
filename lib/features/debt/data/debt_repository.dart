import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'debt_models.dart';

/// Công nợ của nông dân (`/api/me/debt*`).
class DebtRepository {
  DebtRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;
  static const maxReasonLength = 1000;
  static const paymentContext = 'DEBT_REPAYMENT';

  /// Tài khoản công nợ. null = chưa có (cửa hàng chưa cấp hạn mức nên chưa mở sổ nợ).
  Future<DebtAccount?> account() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/me/debt');
      return DebtAccount.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.from(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// [status] là một trạng thái của backend, hoặc [DebtStatus.overdueFilter]
  /// để chỉ lấy khoản đã quá hạn.
  Future<PagedResult<DebtEntrySummary>> entries({
    int page = 1,
    int size = pageSize,
    String? status,
  }) =>
      apiCall(() async {
        final overdue = status == DebtStatus.overdueFilter;
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/debt-entries',
          queryParameters: cleanQuery({
            'page': page,
            'pageSize': size,
            if (overdue) 'overdueOnly': true else 'status': status,
            // Khoản chưa trả: đến hạn sớm nhất lên đầu (đúng thứ tự sẽ được trừ nợ).
            // Khoản đã đóng/tất cả: mới nhất lên đầu (mặc định của backend).
            if (_dueFirst(status)) 'sortBy': 'DueDate',
            if (_dueFirst(status)) 'descending': false,
          }),
        );
        return PagedResult.fromJson(res.data!, DebtEntrySummary.fromJson);
      });

  static bool _dueFirst(String? status) =>
      status == DebtStatus.overdueFilter ||
      status == DebtStatus.open ||
      status == DebtStatus.partiallyPaid ||
      status == DebtStatus.disputed;

  /// Vài khoản nợ chưa trả sắp đến hạn nhất, cho màn tổng quan.
  Future<List<DebtEntrySummary>> upcoming({int limit = 5}) async {
    final pages = await Future.wait([
      for (final s in [DebtStatus.open, DebtStatus.partiallyPaid, DebtStatus.disputed])
        entries(size: limit, status: s),
    ]);
    final all = [for (final p in pages) ...p.items]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return all.take(limit).toList();
  }

  Future<DebtEntryDetail> entry(String id) => apiCall(
        () async {
          final res =
              await _dio.get<Map<String, dynamic>>('/api/me/debt-entries/$id');
          return DebtEntryDetail.fromJson(res.data!);
        },
        messages: {404: 'Không tìm thấy khoản nợ.'},
      );

  /// Khiếu nại một khoản nợ. Khoản nợ vẫn phải trả trong lúc chờ cửa hàng xử lý.
  Future<DebtEntryDetail> dispute(String id, String reason) => apiCall(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/debt-entries/$id/dispute',
            data: {'reason': reason.trim()},
          );
          return DebtEntryDetail.fromJson(res.data!);
        },
        messages: {
          404: 'Không tìm thấy khoản nợ.',
          400: 'Vui lòng nhập lý do khiếu nại (tối đa $maxReasonLength ký tự).',
        },
        map: (e) {
          final d = e.detail ?? '';
          if (e.statusCode == 422 && d.contains('already disputed')) {
            return e.withMessage('Khoản nợ này đã được khiếu nại, đang chờ cửa hàng xử lý.');
          }
          if (e.statusCode == 422) {
            return e.withMessage('Khoản nợ đã đóng nên không thể khiếu nại.');
          }
          return e;
        },
      );

  /// Xem trước [amount] sẽ trừ vào những khoản nợ nào.
  Future<AllocationPreview> preview(double amount) => apiCall(
        () async {
          final res = await _dio.get<Map<String, dynamic>>(
            '/api/me/debt/allocation-preview',
            queryParameters: {'amount': _money(amount)},
          );
          return AllocationPreview.fromJson(res.data!);
        },
        messages: {
          404: 'Bạn chưa có công nợ nào.',
          422: 'Số tiền không hợp lệ.',
        },
      );

  /// Lịch sử các lần trả nợ (mọi trạng thái), mới nhất trước.
  ///
  /// `/api/me/payments` trộn cả thanh toán đơn hàng và không lọc được theo loại
  /// nên ở đây lọc lại phía app; `page`/`totalPages` là của trang gốc.
  Future<PagedResult<DebtPayment>> repayments({int page = 1}) => apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/payments',
          queryParameters: {'page': page, 'pageSize': 50},
        );
        final body = res.data!;
        final items = <DebtPayment>[
          for (final p in (body['items'] as List? ?? const []))
            if ((p as Map<String, dynamic>)['paymentContext'] == paymentContext)
              DebtPayment.fromJson(p),
        ];
        return PagedResult(
          items: items,
          page: asInt(body['page']) ?? page,
          pageSize: asInt(body['pageSize']) ?? 50,
          totalCount: asInt(body['totalCount']) ?? items.length,
          totalPages: asInt(body['totalPages']) ?? 1,
        );
      });

  /// Số nguyên thì gửi dạng số nguyên (`1500000`, không phải `1500000.0`).
  static Object _money(double v) => v == v.truncateToDouble() ? v.toInt() : v;
}

final debtRepositoryProvider =
    Provider<DebtRepository>((ref) => DebtRepository(ref.watch(dioProvider)));
