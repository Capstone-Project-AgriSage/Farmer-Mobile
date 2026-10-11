import 'package:dio/dio.dart';

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  businessRule,
  rateLimited,
  unavailable,
  server,
  cancelled,
  unknown,
}

/// Lỗi thống nhất cho toàn app. Backend trả RFC 7807 (`title`, `detail`,
/// `errors`, `traceId`); lớp này chuyển thành thông báo tiếng Việt.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.detail,
    this.fieldErrors = const {},
    this.traceId,
  });

  final ApiErrorKind kind;

  /// Thông báo tiếng Việt, hiển thị được cho người dùng.
  final String message;
  final int? statusCode;

  /// `detail` gốc từ backend (thường là tiếng Anh), dùng để log/debug.
  final String? detail;

  /// 400/422: lỗi theo trường hoặc theo dòng, ví dụ `items[0]`.
  final Map<String, List<String>> fieldErrors;
  final String? traceId;

  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;

  /// 409: có thao tác khác vừa chạy, nên tải lại rồi cho thử lại.
  bool get isConflict => kind == ApiErrorKind.conflict;

  /// Lỗi mạng/máy chủ (không phải do người dùng nhập sai).
  bool get isConnectivity =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.unavailable ||
      kind == ApiErrorKind.server;

  /// Giữ nguyên loại lỗi, đổi thông báo cho đúng ngữ cảnh màn hình
  /// (ví dụ 401 ở đăng nhập nghĩa là sai mật khẩu, không phải hết phiên).
  ApiException withMessage(String newMessage) => ApiException(
        kind: kind,
        message: newMessage,
        statusCode: statusCode,
        detail: detail,
        fieldErrors: fieldErrors,
        traceId: traceId,
      );

  static ApiException from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return _fromDio(error);
    return const ApiException(
      kind: ApiErrorKind.unknown,
      message: 'Đã có lỗi xảy ra. Vui lòng thử lại.',
    );
  }

  static ApiException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.cancelled,
          message: 'Yêu cầu đã bị huỷ.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          kind: ApiErrorKind.network,
          message: 'Kết nối không an toàn tới máy chủ.',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final response = e.response;
    if (response == null) {
      return const ApiException(
        kind: ApiErrorKind.network,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }

    final status = response.statusCode ?? 0;
    final body = response.data;
    String? detail;
    String? traceId;
    var fieldErrors = <String, List<String>>{};
    if (body is Map) {
      detail = body['detail']?.toString();
      traceId = body['traceId']?.toString();
      fieldErrors = _parseErrors(body['errors']);
    }

    final (kind, fallback) = _classify(status);
    // Với 400/409/422, `detail` là lý do nghiệp vụ nên ưu tiên hiển thị.
    final useDetail = detail != null &&
        detail.isNotEmpty &&
        (kind == ApiErrorKind.validation ||
            kind == ApiErrorKind.conflict ||
            kind == ApiErrorKind.businessRule);

    return ApiException(
      kind: kind,
      statusCode: status,
      message: useDetail ? detail : fallback,
      detail: detail,
      fieldErrors: fieldErrors,
      traceId: traceId,
    );
  }

  static (ApiErrorKind, String) _classify(int status) {
    switch (status) {
      case 400:
        return (ApiErrorKind.validation, 'Dữ liệu không hợp lệ.');
      case 401:
        return (
          ApiErrorKind.unauthorized,
          'Phiên đăng nhập hết hạn hoặc thông tin không đúng.'
        );
      case 403:
        return (
          ApiErrorKind.forbidden,
          'Bạn không có quyền thực hiện thao tác này.'
        );
      case 404:
        return (ApiErrorKind.notFound, 'Không tìm thấy dữ liệu.');
      case 409:
        return (
          ApiErrorKind.conflict,
          'Dữ liệu vừa được thay đổi. Vui lòng tải lại và thử lại.'
        );
      case 422:
        return (ApiErrorKind.businessRule, 'Thao tác không hợp lệ.');
      case 429:
        return (
          ApiErrorKind.rateLimited,
          'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.'
        );
      case 503:
        return (
          ApiErrorKind.unavailable,
          'Dịch vụ tạm thời gián đoạn. Vui lòng thử lại sau.'
        );
    }
    if (status >= 500) {
      return (ApiErrorKind.server, 'Máy chủ gặp sự cố. Vui lòng thử lại sau.');
    }
    return (ApiErrorKind.unknown, 'Đã có lỗi xảy ra. Vui lòng thử lại.');
  }

  static Map<String, List<String>> _parseErrors(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): entry.value is List
            ? [for (final v in entry.value as List) v.toString()]
            : [entry.value.toString()],
    };
  }

  @override
  String toString() => 'ApiException($kind, $statusCode, $message)';
}
