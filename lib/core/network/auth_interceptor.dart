import 'dart:convert';

import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Gắn Bearer token và giữ phiên sống bằng refresh token.
///
/// - Trước mỗi request: nếu access token sắp hết hạn (đọc `exp` trong JWT) thì
///   refresh trước, để các route trả 401 "sai mật khẩu" (đổi mật khẩu) không bị
///   nhầm với token hết hạn.
/// - Khi gặp 401: refresh đúng một lần rồi gọi lại request.
/// - Mọi lần refresh đi qua [_refreshOnce] nên chạy tuần tự, không song song
///   (refresh token xoay vòng, gọi song song sẽ làm hỏng phiên).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required Dio refreshDio,
    required TokenStorage storage,
    required Future<void> Function() onSessionExpired,
    DateTime Function()? now,
  })  : _dio = dio,
        _refreshDio = refreshDio,
        _storage = storage,
        _onSessionExpired = onSessionExpired,
        _now = now ?? DateTime.now;

  final Dio _dio;

  /// Dio không có interceptor, tránh vòng lặp khi gọi refresh.
  final Dio _refreshDio;
  final TokenStorage _storage;
  final Future<void> Function() _onSessionExpired;
  final DateTime Function() _now;

  Future<AuthTokens?>? _inflight;

  static const _retriedKey = 'auth_retried';
  static const _explicitKey = 'auth_explicit';
  static const _expirySkew = Duration(seconds: 30);

  /// Không gắn token.
  static const _noBearerPaths = [
    '/api/auth/login',
    '/api/auth/register',
    '/api/auth/refresh',
    '/api/auth/forgot-password',
    '/api/auth/reset-password',
    '/api/catalog',
  ];

  /// Không refresh khi 401 (401 ở đây là lỗi nghiệp vụ, không phải token).
  static const _noRefreshPaths = [
    ..._noBearerPaths,
    '/api/auth/change-password',
  ];

  static bool _matches(List<String> prefixes, String path) =>
      prefixes.any(path.startsWith);

  /// `exp` của JWT; null nếu không đọc được (coi như chưa hết hạn).
  static DateTime? jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final exp = (jsonDecode(payload) as Map<String, dynamic>)['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      return null;
    }
  }

  bool _isExpiring(String accessToken) {
    final exp = jwtExpiry(accessToken);
    return exp != null && exp.isBefore(_now().add(_expirySkew));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_matches(_noBearerPaths, options.path)) return handler.next(options);

    // Nơi gọi đã tự chỉ định token (ví dụ đóng phiên vừa mở nhưng chưa lưu):
    // không được ghi đè bằng token đang lưu, và cũng không refresh hộ.
    if (options.headers.containsKey('Authorization')) {
      options.extra[_explicitKey] = true;
      return handler.next(options);
    }

    var tokens = await _storage.read();
    if (tokens != null && _isExpiring(tokens.accessToken)) {
      try {
        tokens = await _refreshOnce(tokens) ?? tokens;
      } on DioException {
        // Lỗi mạng khi refresh: cứ gửi, để request báo lỗi mạng/401 đúng nghĩa.
      }
    }
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final unauthorized = err.response?.statusCode == 401;
    if (!unauthorized ||
        _matches(_noRefreshPaths, request.path) ||
        request.extra[_retriedKey] == true ||
        request.extra[_explicitKey] == true) {
      return handler.next(err);
    }

    final sent = request.headers['Authorization'] as String?;
    final tokens = await _storage.read();
    if (tokens == null) return handler.next(err);

    // Request trước đó đã làm mới token xong: chỉ cần gọi lại bằng token mới.
    if (sent != null && sent != 'Bearer ${tokens.accessToken}') {
      return _retry(request, tokens.accessToken, handler);
    }

    final AuthTokens? fresh;
    try {
      fresh = await _refreshOnce(tokens);
    } on DioException catch (e) {
      // Lỗi mạng/5xx khi refresh: giữ token, báo lỗi của lần refresh.
      return handler.next(e);
    }
    if (fresh == null) {
      await _storage.clear();
      await _onSessionExpired();
      return handler.next(err);
    }
    return _retry(request, fresh.accessToken, handler);
  }

  Future<AuthTokens?> _refreshOnce(AuthTokens seen) =>
      _inflight ??= _doRefresh(seen).whenComplete(() => _inflight = null);

  /// Trả null khi server từ chối refresh token (phiên đã hết).
  Future<AuthTokens?> _doRefresh(AuthTokens seen) async {
    // Có lần refresh khác vừa xong trong lúc chờ: dùng token mới của nó.
    final latest = await _storage.read();
    if (latest == null) return null;
    if (latest.accessToken != seen.accessToken) return latest;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': latest.refreshToken},
      );
      final data = response.data;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      if (access == null || refresh == null) return null;
      final fresh = AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        sessionId: data?['sessionId']?.toString() ?? latest.sessionId,
      );
      await _storage.save(fresh);
      return fresh;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400 || status == 403) return null;
      rethrow;
    }
  }

  Future<void> _retry(
    RequestOptions request,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
