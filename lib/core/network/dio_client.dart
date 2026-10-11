import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../auth/session_provider.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

BaseOptions _baseOptions(String baseUrl) => BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: const {'Accept': 'application/json'},
      // Dio mặc định chỉ coi 2xx là thành công; giữ nguyên để lỗi đi qua
      // DioException và được ApiException.from chuyển đổi.
    );

/// Tạo Dio đã gắn interceptor. Tách riêng để test được với adapter giả.
Dio createApiDio({
  required String baseUrl,
  required TokenStorage storage,
  required Future<void> Function() onSessionExpired,
  bool enableLogging = false,
  HttpClientAdapter? adapter,
  DateTime Function()? now,
}) {
  final dio = Dio(_baseOptions(baseUrl));
  final refreshDio = Dio(_baseOptions(baseUrl));
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
    refreshDio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      storage: storage,
      onSessionExpired: onSessionExpired,
      now: now,
    ),
  );
  if (enableLogging) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false, // có Authorization
        requestBody: false, // có mật khẩu ở login/register
        responseBody: true,
        error: true,
        compact: true,
        maxWidth: 100,
        // Response của /api/auth/* chứa token nên không log.
        filter: (options, args) => !options.path.startsWith('/api/auth'),
      ),
    );
  }
  return dio;
}

/// Dio dùng chung cho mọi repository.
final dioProvider = Provider<Dio>((ref) {
  return createApiDio(
    baseUrl: AppConfig.apiBaseUrl,
    storage: ref.watch(tokenStorageProvider),
    onSessionExpired: () async =>
        ref.read(sessionProvider.notifier).markUnauthenticated(),
    enableLogging: kDebugMode,
  );
});
