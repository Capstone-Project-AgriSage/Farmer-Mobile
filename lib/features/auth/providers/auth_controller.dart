import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/token_storage.dart';
import '../data/auth_repository.dart';

/// Kết quả khởi động app (splash).
enum BootstrapResult {
  authenticated,
  unauthenticated,

  /// Có token nhưng chưa hỏi được máy chủ (mất mạng, server lỗi): cho thử lại.
  offline,
}

/// Điều phối đăng nhập/đăng ký/đăng xuất giữa repository, token và phiên.
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);
  TokenStorage get _tokens => _ref.read(tokenStorageProvider);
  SessionNotifier get _session => _ref.read(sessionProvider.notifier);

  /// App này chỉ dành cho nông dân (role `FARMER`).
  static const farmerRole = 'FARMER';

  Future<void> login(
    String identifier,
    String password, {
    bool rememberMe = true,
  }) async {
    final result = await _repo.login(identifier, password);
    await _establish(result, rememberMe: rememberMe);
  }

  Future<void> register({
    required String fullName,
    required String phoneNumber,
    String? email,
    required String password,
  }) async {
    final result = await _repo.register(
      fullName: fullName,
      phoneNumber: phoneNumber,
      email: email,
      password: password,
    );
    await _establish(result, rememberMe: true);
  }

  Future<void> _establish(AuthResult result, {required bool rememberMe}) async {
    if (result.user.role != farmerRole) {
      // Tài khoản nhân viên/quản lý không dùng app nông dân: đóng phiên vừa mở.
      try {
        await _repo.logout(accessToken: result.tokens.accessToken);
      } on ApiException {
        // Không quan trọng: token này không được lưu.
      }
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        statusCode: 403,
        message: 'Ứng dụng này chỉ dành cho tài khoản nông dân.',
      );
    }
    try {
      await _tokens.save(result.tokens, persist: rememberMe);
    } catch (_) {
      // Keystore/Keychain lỗi: đóng phiên vừa mở trên server rồi báo người dùng.
      try {
        await _repo.logout(accessToken: result.tokens.accessToken);
      } catch (_) {}
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Không lưu được phiên đăng nhập trên thiết bị này. Vui lòng thử lại.',
      );
    }
    SessionUser user = result.user;
    try {
      // Lấy cờ đã xác minh SĐT/email (phản hồi đăng nhập không có).
      user = await _repo.me();
    } on ApiException {
      // Dùng thông tin cơ bản từ phản hồi đăng nhập.
    }
    _session.setAuthenticated(user);
  }

  /// Gọi ở splash: khôi phục phiên từ token đã lưu.
  Future<BootstrapResult> bootstrap() async {
    AuthTokens? tokens;
    try {
      tokens = await _tokens.read();
    } catch (_) {
      // Không đọc được kho token (keystore hỏng/khôi phục từ bản sao lưu): coi như
      // chưa đăng nhập thay vì kẹt ở màn splash.
      await _clearLocal();
      return BootstrapResult.unauthenticated;
    }
    if (tokens == null) {
      _session.markUnauthenticated();
      return BootstrapResult.unauthenticated;
    }
    try {
      final user = await _repo.me();
      if (user.role != farmerRole) {
        await _clearLocal();
        return BootstrapResult.unauthenticated;
      }
      _session.setAuthenticated(user);
      return BootstrapResult.authenticated;
    } on ApiException catch (e) {
      if (e.isConnectivity) return BootstrapResult.offline;
      // 401 (refresh cũng thất bại), 403 tài khoản bị khoá...
      await _clearLocal();
      return BootstrapResult.unauthenticated;
    }
  }

  /// Đăng xuất: thông báo server (nếu được) rồi xoá phiên cục bộ.
  Future<void> logout() async {
    try {
      await _repo.logout();
    } on ApiException {
      // Offline hay token hết hạn vẫn phải đăng xuất được ở máy này.
    }
    await _clearLocal();
  }

  Future<void> logoutAll() async {
    await _repo.logoutAll();
    await _clearLocal();
  }

  /// Backend huỷ mọi phiên khi đổi mật khẩu, nên đăng xuất cục bộ luôn.
  Future<void> changePassword(String current, String next) async {
    await _repo.changePassword(current, next);
    await _clearLocal();
  }

  /// Sau khi xác minh SĐT/email: tải lại thông tin người dùng.
  Future<void> refreshUser() async {
    final user = await _repo.me();
    _session.updateUser(user);
  }

  Future<void> _clearLocal() async {
    try {
      await _tokens.clear();
    } catch (_) {
      // Không xoá được khỏi keystore vẫn phải đăng xuất khỏi app (RAM đã được xoá).
    }
    _session.markUnauthenticated();
  }
}

final authControllerProvider = Provider<AuthController>(AuthController.new);
