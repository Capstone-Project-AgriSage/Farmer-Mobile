import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/env.dart';
import '../session/session_manager.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final session = SessionManager(store: ref.watch(tokenStoreProvider));
  ref.onDispose(session.dispose);
  return session;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(AuthInterceptor(session: ref.watch(sessionManagerProvider)));
  if (kDebugMode) {
    // Never log headers (they hold the token) or bodies (they hold passwords).
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        compact: true,
      ),
    );
  }
  return dio;
});
