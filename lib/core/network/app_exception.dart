import 'dart:io';

import 'package:dio/dio.dart';

import 'problem_messages_vi.dart';

enum AppErrorKind {
  offline,
  timeout,
  unauthorized,
  sessionExpired,
  wrongRole,
  forbidden,
  notFound,
  conflict,
  validation,
  businessRule,
  rateLimited,
  server,
  cancelled,
  unknown,
}

/// The one error type the UI sees. `message` is always Vietnamese and safe to show.
class AppException implements Exception {
  const AppException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.traceId,
  });

  const AppException.sessionExpired()
      : this(
          kind: AppErrorKind.sessionExpired,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          statusCode: 401,
        );

  const AppException.offline()
      : this(
          kind: AppErrorKind.offline,
          message: 'Không có kết nối mạng. Vui lòng kiểm tra Wi-Fi hoặc 4G rồi thử lại.',
        );

  const AppException.timeout()
      : this(
          kind: AppErrorKind.timeout,
          message: 'Kết nối quá chậm nên chưa nhận được phản hồi. Vui lòng thử lại.',
        );

  final AppErrorKind kind;
  final String message;
  final int? statusCode;

  /// Field name (first letter lower case, as the web sends it) to its Vietnamese messages. Only set for a 400.
  final Map<String, List<String>> fieldErrors;
  final String? traceId;

  /// A failure that is worth offering "Thử lại" for: the request may well succeed a moment later.
  bool get isRetryable =>
      kind == AppErrorKind.offline || kind == AppErrorKind.timeout || kind == AppErrorKind.server;

  /// The request was sent but the answer was lost, so the server may have acted. A POST must not be repeated blindly.
  bool get outcomeUnknown => kind == AppErrorKind.timeout;

  bool get isAuthFailure =>
      kind == AppErrorKind.sessionExpired || kind == AppErrorKind.unauthorized;

  String? fieldError(String field) {
    final messages = fieldErrors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  factory AppException.fromDio(DioException error) {
    final inner = error.error;
    if (inner is AppException) return inner;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException.timeout();
      case DioExceptionType.connectionError:
        return const AppException.offline();
      case DioExceptionType.cancel:
        return const AppException(kind: AppErrorKind.cancelled, message: 'Đã hủy thao tác.');
      case DioExceptionType.badCertificate:
        return const AppException(
          kind: AppErrorKind.unknown,
          message: 'Không xác minh được chứng chỉ bảo mật của máy chủ.',
        );
      case DioExceptionType.badResponse:
        final response = error.response;
        if (response != null) return AppException.fromResponse(response);
        return const AppException(kind: AppErrorKind.unknown, message: 'Đã xảy ra lỗi không mong muốn.');
      default: // unknown, and any type a newer Dio adds
        if (inner is SocketException || inner is HttpException) return const AppException.offline();
        return AppException(kind: AppErrorKind.unknown, message: fallbackMessageForStatus(null));
    }
  }

  factory AppException.fromResponse(Response<dynamic> response) {
    final status = response.statusCode;
    final data = response.data;
    final problem = data is Map ? data : const <String, dynamic>{};

    final detail = problem['detail'] is String ? problem['detail'] as String : null;
    final traceId = problem['traceId'] is String ? problem['traceId'] as String : null;
    final fieldErrors = _parseFieldErrors(problem['errors']);

    String message = translateProblemDetail(detail) ?? fallbackMessageForStatus(status);
    if (status == 400 && fieldErrors.isNotEmpty) {
      message = fieldErrors.values.first.first;
    } else if (status == 422 && fieldErrors.isNotEmpty && translateProblemDetail(detail) == null) {
      message = fieldErrors.values.first.first;
    }

    return AppException(
      kind: _kindForStatus(status),
      message: message,
      statusCode: status,
      fieldErrors: fieldErrors,
      traceId: traceId,
    );
  }

  static AppErrorKind _kindForStatus(int? status) => switch (status) {
        400 => AppErrorKind.validation,
        401 => AppErrorKind.unauthorized,
        403 => AppErrorKind.forbidden,
        404 => AppErrorKind.notFound,
        409 => AppErrorKind.conflict,
        422 => AppErrorKind.businessRule,
        429 => AppErrorKind.rateLimited,
        final s? when s >= 500 => AppErrorKind.server,
        _ => AppErrorKind.unknown,
      };

  static Map<String, List<String>> _parseFieldErrors(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, List<String>>{};
    raw.forEach((key, value) {
      if (key is! String || value is! List) return;
      final messages = value
          .whereType<String>()
          .map((m) => translateProblemDetail(m) ?? m)
          .toList(growable: false);
      if (messages.isEmpty) return;
      result[_lowerFirst(key)] = messages;
    });
    return result;
  }

  static String _lowerFirst(String key) => key.isEmpty ? key : key[0].toLowerCase() + key.substring(1);

  @override
  String toString() => 'AppException($kind, $statusCode, $message)';
}

/// The Vietnamese text for any error caught in the UI.
String messageOf(Object error) =>
    error is AppException ? error.message : 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';

/// Runs a Dio call and rethrows any failure as an [AppException].
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (error) {
    throw AppException.fromDio(error);
  }
}
