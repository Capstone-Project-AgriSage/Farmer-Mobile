import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/token_storage.dart';

/// Kết quả đăng nhập/đăng ký: token + người dùng cơ bản.
class AuthResult {
  const AuthResult({required this.tokens, required this.user});

  final AuthTokens tokens;
  final SessionUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthResult(
      tokens: AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        sessionId: json['sessionId']?.toString(),
      ),
      user: SessionUser.fromJson(user),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.id,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
    required this.isCurrent,
  });

  final String id;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
  final bool isCurrent;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        lastUsedAt: DateTime.parse(json['lastUsedAt'] as String).toLocal(),
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
        isCurrent: json['isCurrent'] as bool? ?? false,
      );
}

/// Gọi `/api/auth/*`. Lỗi được ném dưới dạng [ApiException] với thông báo
/// đúng ngữ cảnh (401 ở đăng nhập là "sai thông tin", không phải "hết phiên").
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<T> _run<T>(Future<T> Function() call,
      {Map<int, String> messages = const {}}) async {
    try {
      return await call();
    } on DioException catch (e) {
      final error = ApiException.from(e);
      final override = messages[error.statusCode];
      throw override == null ? error : error.withMessage(override);
    }
  }

  Future<AuthResult> login(String identifier, String password) => _run(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/auth/login',
            data: {'identifier': identifier.trim(), 'password': password},
          );
          return AuthResult.fromJson(res.data!);
        },
        messages: {
          401: 'Số điện thoại/email hoặc mật khẩu không đúng.',
          403: 'Tài khoản này hiện không hoạt động.',
        },
      );

  Future<AuthResult> register({
    required String fullName,
    required String phoneNumber,
    String? email,
    required String password,
  }) =>
      _run(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/auth/register',
            data: {
              'fullName': fullName.trim(),
              'phoneNumber': phoneNumber.trim(),
              if (email != null && email.trim().isNotEmpty)
                'email': email.trim(),
              'password': password,
            },
          );
          return AuthResult.fromJson(res.data!);
        },
        messages: {
          409: 'Số điện thoại hoặc email này đã được đăng ký.',
        },
      );

  Future<SessionUser> me() => _run(() async {
        final res = await _dio.get<Map<String, dynamic>>('/api/auth/me');
        return SessionUser.fromJson(res.data!);
      });

  /// Đăng xuất phiên hiện tại. [accessToken] dùng khi chưa lưu token.
  Future<void> logout({String? accessToken}) => _run(() async {
        await _dio.post<void>(
          '/api/auth/logout',
          options: accessToken == null
              ? null
              : Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
      });

  Future<void> logoutAll() =>
      _run(() => _dio.post<void>('/api/auth/logout-all'));

  Future<List<AuthSession>> sessions() => _run(() async {
        final res = await _dio.get<List<dynamic>>('/api/auth/sessions');
        return [
          for (final s in res.data!)
            AuthSession.fromJson(s as Map<String, dynamic>),
        ];
      });

  Future<void> revokeSession(String id) =>
      _run(() => _dio.delete<void>('/api/auth/sessions/$id'));

  /// Đổi mật khẩu thành công thì backend huỷ MỌI phiên (kể cả phiên này).
  Future<void> changePassword(String current, String next) => _run(
        () => _dio.post<void>(
          '/api/auth/change-password',
          data: {'currentPassword': current, 'newPassword': next},
        ),
        messages: {
          401: 'Mật khẩu hiện tại không đúng.',
          422: 'Mật khẩu mới phải khác mật khẩu hiện tại.',
        },
      );

  /// Luôn 202 dù tài khoản có tồn tại hay không (không lộ thông tin).
  /// 503 khi máy chủ chưa cấu hình kênh gửi email/SMS.
  Future<void> forgotPassword(String identifier) => _run(
        () => _dio.post<void>(
          '/api/auth/forgot-password',
          data: {'identifier': identifier.trim()},
        ),
        messages: {
          503: 'Hiện chưa gửi được mã xác nhận. Vui lòng thử lại sau.',
        },
      );

  Future<void> resetPassword(String token, String newPassword) => _run(
        () => _dio.post<void>(
          '/api/auth/reset-password',
          data: {'token': token.trim(), 'newPassword': newPassword},
        ),
        messages: {
          422: 'Mã xác nhận không đúng hoặc đã hết hạn.',
        },
      );

  Future<void> requestPhoneVerification() => _run(
        () => _dio.post<void>('/api/auth/phone-verification/request'),
        messages: {
          503: 'Hiện chưa gửi được mã qua SMS. Vui lòng thử lại sau.',
          422: 'Tài khoản chưa có số điện thoại để xác minh.',
        },
      );

  Future<void> confirmPhone(String code) => _run(
        () => _dio.post<void>(
          '/api/auth/phone-verification/confirm',
          data: {'code': code.trim()},
        ),
        messages: {422: 'Mã OTP không đúng hoặc đã hết hạn.'},
      );

  Future<void> requestEmailVerification() => _run(
        () => _dio.post<void>('/api/auth/email-verification/request'),
        messages: {
          503: 'Hiện chưa gửi được email. Vui lòng thử lại sau.',
          422: 'Tài khoản chưa có email để xác minh.',
        },
      );

  Future<void> confirmEmail(String token) => _run(
        () => _dio.post<void>(
          '/api/auth/email-verification/confirm',
          data: {'token': token.trim()},
        ),
        messages: {422: 'Mã xác nhận không đúng hoặc đã hết hạn.'},
      );
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));
