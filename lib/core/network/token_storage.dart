import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.sessionId,
  });

  final String accessToken;
  final String refreshToken;
  final String? sessionId;
}

/// Lưu token trong keystore/keychain, có cache trong RAM để interceptor
/// không phải đọc storage ở mỗi request.
///
/// `persist: false` (không tick "Ghi nhớ đăng nhập") chỉ giữ token trong RAM:
/// tắt app là mất phiên. Các lần refresh sau đó giữ nguyên chế độ đã chọn.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kSession = 'session_id';

  final FlutterSecureStorage _storage;
  AuthTokens? _cache;
  bool _loaded = false;
  bool _persist = true;

  Future<AuthTokens?> read() async {
    if (_loaded) return _cache;
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    final session = await _storage.read(key: _kSession);
    _cache = (access != null && refresh != null)
        ? AuthTokens(
            accessToken: access,
            refreshToken: refresh,
            sessionId: session,
          )
        : null;
    _persist = true;
    _loaded = true;
    return _cache;
  }

  /// [persist] null = giữ chế độ hiện tại (dùng khi refresh token).
  Future<void> save(AuthTokens tokens, {bool? persist}) async {
    if (persist != null) _persist = persist;
    _cache = tokens;
    _loaded = true;
    if (!_persist) {
      await _deleteStored();
      return;
    }
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kRefresh, value: tokens.refreshToken);
    if (tokens.sessionId != null) {
      await _storage.write(key: _kSession, value: tokens.sessionId);
    }
  }

  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    _persist = true;
    await _deleteStored();
  }

  Future<void> _deleteStored() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kSession);
  }
}
