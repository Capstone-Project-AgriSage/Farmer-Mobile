import 'package:dio/dio.dart';

import '../session/session_manager.dart';
import 'app_exception.dart';

/// Puts the Bearer token on every call and turns every failure into an [AppException].
///
/// - A token that is (almost) expired is not sent: the session ends here, without a pointless round trip.
/// - A 401 ends the session, except on the sign-in/sign-up/change-password calls, where a 401 only means
///   "wrong credentials" (a wrong current password must not sign the user out).
/// - A 403 only reports an error; a 429 reports "too many attempts".
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required SessionManager session}) : _session = session;

  final SessionManager _session;

  /// Calls that carry no token, and calls whose 401 is a normal business answer.
  static const _anonymousPaths = {'/api/auth/login', '/api/auth/register'};
  static const _keepSessionOn401 = {'/api/auth/login', '/api/auth/register', '/api/auth/change-password'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_anonymousPaths.contains(options.path)) return handler.next(options);

    final token = _session.token;
    if (token == null) return handler.next(options);

    if (_session.isExpired) {
      _session.expire();
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const AppException.sessionExpired(),
        ),
        true,
      );
    }

    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is AppException) return handler.next(err);

    final exception = AppException.fromDio(err);
    if (err.response?.statusCode == 401 && !_keepSessionOn401.contains(err.requestOptions.path)) {
      _session.expire();
      return handler.next(err.copyWith(error: const AppException.sessionExpired()));
    }
    handler.next(err.copyWith(error: exception));
  }
}
