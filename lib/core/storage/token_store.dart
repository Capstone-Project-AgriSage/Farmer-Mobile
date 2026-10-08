import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What the app keeps between launches: the access token and when it expires. Nothing else.
class StoredSession {
  const StoredSession({required this.accessToken, required this.expiresAt});
  final String accessToken;
  final DateTime expiresAt; // UTC
}

abstract interface class TokenStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

/// Android Keystore backed storage. The token never goes to shared preferences, logs or the screen.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'agrisage.access_token';
  static const _expiresKey = 'agrisage.access_token_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final expires = await _storage.read(key: _expiresKey);
      if (token == null || token.isEmpty || expires == null) return null;
      final expiresAt = DateTime.tryParse(expires);
      if (expiresAt == null) return null;
      return StoredSession(accessToken: token, expiresAt: expiresAt.toUtc());
    } catch (_) {
      // A corrupt keystore entry must not stop the app from starting; the user simply signs in again.
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) async {
    await _storage.write(key: _tokenKey, value: session.accessToken);
    await _storage.write(key: _expiresKey, value: session.expiresAt.toUtc().toIso8601String());
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _expiresKey);
    } catch (_) {
      // Nothing more to do: the in-memory session is already gone.
    }
  }
}
