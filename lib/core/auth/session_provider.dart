import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionStatus {
  /// Chưa biết (đang khởi động, chưa đọc token).
  unknown,
  authenticated,
  unauthenticated,
}

/// Người dùng đang đăng nhập (`GET /api/auth/me`).
class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.email,
    this.phoneVerified = false,
    this.emailVerified = false,
  });

  final String id;
  final String fullName;
  final String role;
  final String? phoneNumber;
  final String? email;
  final bool phoneVerified;
  final bool emailVerified;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? '',
        role: json['role'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String?,
        email: json['email'] as String?,
        phoneVerified: json['phoneVerified'] as bool? ?? false,
        emailVerified: json['emailVerified'] as bool? ?? false,
      );

  /// Chữ cái đầu cho avatar mặc định, ví dụ "Trần Văn Hải" -> "TH".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class SessionState {
  const SessionState({this.status = SessionStatus.unknown, this.user});

  final SessionStatus status;
  final SessionUser? user;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

/// Trạng thái phiên đăng nhập toàn app: nguồn duy nhất cho router guard và UI.
/// Việc đăng nhập/đăng xuất nằm ở `AuthController`.
class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  void setAuthenticated(SessionUser user) => state =
      SessionState(status: SessionStatus.authenticated, user: user);

  void markUnauthenticated() =>
      state = const SessionState(status: SessionStatus.unauthenticated);

  /// Cập nhật thông tin người dùng (sau khi xác minh SĐT, sửa hồ sơ...).
  void updateUser(SessionUser user) {
    if (state.isAuthenticated) setAuthenticated(user);
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
