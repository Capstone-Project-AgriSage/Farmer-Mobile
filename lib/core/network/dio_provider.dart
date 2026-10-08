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

/// The signed-in user's id, or null. Unlike [sessionManagerProvider] this notifies its dependants, so anything that
/// belongs to one user (cart, orders, debt) watches it and starts empty when someone else signs in.
class SessionUserId extends Notifier<String?> {
  @override
  String? build() {
    final session = ref.watch(sessionManagerProvider);
    void sync() => state = session.isSignedIn ? session.user?.id : null;
    session.addListener(sync);
    ref.onDispose(() => session.removeListener(sync));
    return session.isSignedIn ? session.user?.id : null;
  }
}

final sessionUserIdProvider = NotifierProvider<SessionUserId, String?>(SessionUserId.new);

/// The signed-in user's details (name, phone), rebuilt when someone signs in or out and when the user edits their own
/// profile. Screens that show the name watch this rather than reading [sessionManagerProvider], which never notifies.
final sessionUserProvider = Provider<SessionUser?>((ref) {
  ref.watch(sessionUserIdProvider);
  final session = ref.watch(sessionManagerProvider);
  void changed() => ref.invalidateSelf();
  session.profileChanges.addListener(changed);
  ref.onDispose(() => session.profileChanges.removeListener(changed));
  return session.user;
});
