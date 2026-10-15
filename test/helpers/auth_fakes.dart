import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/token_storage.dart';
import 'package:farmer_mobile/features/auth/data/auth_repository.dart';

/// TokenStorage chạy trong RAM, đếm số lần ghi để test chế độ "ghi nhớ".
class MemoryTokenStorage extends TokenStorage {
  MemoryTokenStorage([this.tokens]);

  AuthTokens? tokens;
  bool? lastPersist;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens t, {bool? persist}) async {
    tokens = t;
    if (persist != null) lastPersist = persist;
  }

  @override
  Future<void> clear() async => tokens = null;
}

typedef FakeHandler = ResponseBody Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object? body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

ResponseBody emptyBody(int status) => ResponseBody.fromString('', status);

/// Dữ liệu mẫu giống phản hồi thật của backend.
Map<String, dynamic> authJson({
  String role = 'FARMER',
  String access = 'acc1',
  String refresh = 'ref1',
}) =>
    {
      'accessToken': access,
      'expiresAt': '2026-10-12T10:00:00Z',
      'refreshToken': refresh,
      'refreshExpiresAt': '2026-11-12T10:00:00Z',
      'sessionId': 'sess-1',
      'user': {
        'id': 'u1',
        'fullName': 'Trần Văn Hải',
        'phoneNumber': '0912345678',
        'email': null,
        'role': role,
      },
    };

Map<String, dynamic> meJson({
  String role = 'FARMER',
  bool phoneVerified = false,
  bool emailVerified = false,
  String? email,
}) =>
    {
      'id': 'u1',
      'fullName': 'Trần Văn Hải',
      'phoneNumber': '0912345678',
      'email': email,
      'role': role,
      'status': 'ACTIVE',
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
      'canReviewAi': false,
    };

Map<String, dynamic> problem(int status, String detail,
        {Map<String, dynamic>? errors}) =>
    {
      'title': 'x',
      'status': status,
      'detail': detail,
      if (errors != null) 'errors': errors,
      'traceId': 't1',
    };

/// Repository giả: ghi lại lời gọi, kết quả cấu hình được từng hàm.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(Dio());

  final List<String> calls = [];

  Future<AuthResult> Function(String identifier, String password)? onLogin;
  Future<AuthResult> Function()? onRegister;
  Future<SessionUser> Function()? onMe;
  Future<void> Function({String? accessToken})? onLogout;
  Future<void> Function()? onChangePassword;
  Future<void> Function()? onForgot;
  Future<void> Function()? onReset;
  Future<void> Function()? onVerifyCode;
  Future<void> Function()? onRequestPhone;
  Future<void> Function()? onConfirmPhone;
  Future<void> Function()? onRequestEmail;
  Future<void> Function()? onConfirmEmail;

  String? lastIdentifier;
  String? lastPassword;
  String? lastRegisterPhone;
  String? lastRegisterEmail;
  String? lastResetToken;
  String? lastResetCodeIdentifier;
  String? lastResetCode;
  String? lastVerifyIdentifier;
  String? lastVerifyCode;
  String? lastLogoutToken;

  @override
  Future<AuthResult> login(String identifier, String password) {
    calls.add('login');
    lastIdentifier = identifier;
    lastPassword = password;
    return onLogin!(identifier, password);
  }

  @override
  Future<AuthResult> register({
    required String fullName,
    required String phoneNumber,
    String? email,
    required String password,
  }) {
    calls.add('register');
    lastRegisterPhone = phoneNumber;
    lastRegisterEmail = email;
    return onRegister!();
  }

  @override
  Future<SessionUser> me() {
    calls.add('me');
    return onMe!();
  }

  @override
  Future<void> logout({String? accessToken}) {
    calls.add('logout');
    lastLogoutToken = accessToken;
    return onLogout?.call(accessToken: accessToken) ?? Future.value();
  }

  Object? logoutAllError;

  @override
  Future<void> logoutAll() async {
    calls.add('logoutAll');
    if (logoutAllError != null) throw logoutAllError!;
  }

  List<AuthSession> sessions0 = [];
  Object? sessionsError;
  Object? revokeError;
  final List<String> revoked = [];

  @override
  Future<List<AuthSession>> sessions() async {
    calls.add('sessions');
    if (sessionsError != null) throw sessionsError!;
    return List.of(sessions0);
  }

  @override
  Future<void> revokeSession(String id) async {
    calls.add('revoke:$id');
    if (revokeError != null) throw revokeError!;
    revoked.add(id);
    sessions0 = [for (final s in sessions0) if (s.id != id) s];
  }

  @override
  Future<void> changePassword(String current, String next) {
    calls.add('changePassword');
    return onChangePassword?.call() ?? Future.value();
  }

  @override
  Future<void> forgotPassword(String identifier) {
    calls.add('forgotPassword');
    lastIdentifier = identifier;
    return onForgot?.call() ?? Future.value();
  }

  @override
  Future<void> resetPassword(String token, String newPassword) {
    calls.add('resetPassword');
    lastResetToken = token;
    return onReset?.call() ?? Future.value();
  }

  @override
  Future<void> resetPasswordWithCode(
      String identifier, String code, String newPassword) {
    calls.add('resetPasswordWithCode');
    lastResetCodeIdentifier = identifier;
    lastResetCode = code;
    return onReset?.call() ?? Future.value();
  }

  @override
  Future<void> verifyResetCode(String identifier, String code) {
    calls.add('verifyResetCode');
    lastVerifyIdentifier = identifier;
    lastVerifyCode = code;
    return onVerifyCode?.call() ?? Future.value();
  }

  @override
  Future<void> requestPhoneVerification() {
    calls.add('requestPhone');
    return onRequestPhone?.call() ?? Future.value();
  }

  @override
  Future<void> confirmPhone(String code) {
    calls.add('confirmPhone:$code');
    return onConfirmPhone?.call() ?? Future.value();
  }

  @override
  Future<void> requestEmailVerification() {
    calls.add('requestEmail');
    return onRequestEmail?.call() ?? Future.value();
  }

  @override
  Future<void> confirmEmail(String token) {
    calls.add('confirmEmail:$token');
    return onConfirmEmail?.call() ?? Future.value();
  }
}

AuthResult fakeAuthResult({String role = 'FARMER'}) =>
    AuthResult.fromJson(authJson(role: role));

/// Kho token lỗi (keystore hỏng): các thao tác ném PlatformException-giống.
class BrokenTokenStorage extends MemoryTokenStorage {
  BrokenTokenStorage({this.failRead = false, this.failSave = false, this.failClear = false});

  final bool failRead;
  final bool failSave;
  final bool failClear;

  @override
  Future<AuthTokens?> read() async {
    if (failRead) throw StateError('keystore');
    return super.read();
  }

  @override
  Future<void> save(AuthTokens t, {bool? persist}) async {
    if (failSave) throw StateError('keystore');
    return super.save(t, persist: persist);
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      tokens = null; // RAM đã xoá, phần lưu trữ thì lỗi
      throw StateError('keystore');
    }
    return super.clear();
  }
}
