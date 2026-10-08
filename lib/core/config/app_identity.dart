/// What this app is. The only file of `core/` that differs between the Farmer and the Delivery app.
abstract final class AppIdentity {
  /// The role the server must report for the signed-in user (RoleCodeFormat text, e.g. `FARMER`).
  static const requiredRole = 'FARMER';

  static const appName = 'AgriSage';

  static const wrongRoleMessage =
      'Tài khoản này không dùng được trên ứng dụng Nông dân. Vui lòng đăng nhập bằng tài khoản nông dân.';
}
