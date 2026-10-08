import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';
import '../utils/json_utils.dart';

enum SessionStatus {
  /// The app has just started and has not yet decided whether the stored token is still good.
  restoring,
  signedOut,
  signedIn,
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.email,
  });

  final String id;
  final String fullName;
  final String role;
  final String? phoneNumber;
  final String? email;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: asString(json['id']),
        fullName: asString(json['fullName']),
        role: asString(json['role']),
        phoneNumber: asStringOrNull(json['phoneNumber']),
        email: asStringOrNull(json['email']),
      );
}

/// The signed-in state of the app. It is the router's `refreshListenable`, so a sign-out or an expiry anywhere (for
/// example in the HTTP interceptor) sends the user back to the login screen.
class SessionManager extends ChangeNotifier {
  SessionManager({required TokenStore store, DateTime Function()? clock})
      : _store = store,
        _clock = clock ?? DateTime.now;

  /// A token is treated as expired this long before its real expiry, so a request is never sent with a token that
  /// dies on the way.
  static const expirySkew = Duration(seconds: 30);

  final TokenStore _store;
  final DateTime Function() _clock;

  SessionStatus _status = SessionStatus.restoring;
  String? _token;
  DateTime? _expiresAt;
  SessionUser? _user;
  String? _message;

  SessionStatus get status => _status;
  bool get isSignedIn => _status == SessionStatus.signedIn;
  String? get token => _token;
  DateTime? get expiresAt => _expiresAt;
  SessionUser? get user => _user;

  /// Why the user was signed out (shown once on the login screen), or null.
  String? get message => _message;

  bool get isExpired {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return false;
    return !_clock().toUtc().isBefore(expiresAt.subtract(expirySkew));
  }

  /// Reads the stored token. A usable one is held while the app asks the server who it belongs to
  /// ([completeRestore]); anything else leaves the user signed out.
  Future<void> restore() async {
    final stored = await _store.read();
    if (stored == null) {
      _setSignedOut();
      return;
    }
    _token = stored.accessToken;
    _expiresAt = stored.expiresAt;
    if (isExpired) {
      await _store.clear();
      _clearMemory();
      _setSignedOut(message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      return;
    }
    // Stays `restoring`: the router keeps the splash on screen until the server has confirmed the token.
  }

  bool get hasStoredToken => _status == SessionStatus.restoring && _token != null;

  void completeRestore(SessionUser user) {
    _user = user;
    _message = null;
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  Future<void> signIn({required String accessToken, required DateTime expiresAt, required SessionUser user}) async {
    _token = accessToken;
    _expiresAt = expiresAt.toUtc();
    _user = user;
    _message = null;
    await _store.write(StoredSession(accessToken: accessToken, expiresAt: _expiresAt!));
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  void updateUser(SessionUser user) {
    _user = user;
    notifyListeners();
  }

  /// The token is no longer good (expired, or the server answered 401). Safe to call from several requests at once.
  Future<void> expire({String? message}) async {
    if (_status == SessionStatus.signedOut && _token == null) return;
    await _store.clear();
    _clearMemory();
    _setSignedOut(message: message ?? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
  }

  /// The user chose to sign out.
  Future<void> signOut() async {
    await _store.clear();
    _clearMemory();
    _setSignedOut();
  }

  /// Drops a stored token the server did not accept for a reason other than expiry (for example a wrong role).
  Future<void> rejectRestored({String? message}) async {
    await _store.clear();
    _clearMemory();
    _setSignedOut(message: message);
  }

  void _clearMemory() {
    _token = null;
    _expiresAt = null;
    _user = null;
  }

  void _setSignedOut({String? message}) {
    _message = message;
    _status = SessionStatus.signedOut;
    notifyListeners();
  }
}
