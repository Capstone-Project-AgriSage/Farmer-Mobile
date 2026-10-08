import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/utils/json_utils.dart';

/// What `POST /api/auth/login` and `/register` answer.
class AuthResult {
  const AuthResult({required this.accessToken, required this.expiresAt, required this.user});

  final String accessToken;
  final DateTime expiresAt;
  final SessionUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: asString(json['accessToken']),
        expiresAt: asDateTime(json['expiresAt']) ?? DateTime.now().toUtc(),
        user: SessionUser.fromJson(json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : {}),
      );
}

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthResult> login({required String identifier, required String password}) => guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/auth/login',
          data: {'identifier': identifier, 'password': password},
        );
        return AuthResult.fromJson(response.data ?? const {});
      });

  /// Registers a farmer. The server signs the new account in straight away (there is no OTP step yet).
  Future<AuthResult> register({
    required String fullName,
    required String? phoneNumber,
    required String? email,
    required String password,
  }) =>
      guardApi(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/auth/register',
          data: {
            'fullName': fullName,
            'phoneNumber': phoneNumber,
            'email': email,
            'password': password,
          },
        );
        return AuthResult.fromJson(response.data ?? const {});
      });

  /// The signed-in user, as the server knows them now.
  Future<SessionUser> me() => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/auth/me');
        return SessionUser.fromJson(response.data ?? const {});
      });

  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      guardApi(() async {
        await _dio.post<void>(
          '/api/auth/change-password',
          data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        );
      });
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(dioProvider)));
