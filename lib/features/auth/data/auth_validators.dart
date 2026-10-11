/// Kiểm tra phía client, khớp luật của backend (`ContactNormalizer`,
/// `PasswordRules`) để báo lỗi sớm; backend vẫn là nơi quyết định cuối cùng.
abstract class AuthValidators {
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;

  static final _separators = RegExp(r'[\s.\-()]');
  static final _mobile = RegExp(r'^0(3|5|7|8|9)\d{8}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Chuẩn hoá về dạng 0xxxxxxxxx; null nếu không phải số di động Việt Nam.
  static String? normalizePhone(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    var digits = input.replaceAll(_separators, '');
    if (digits.startsWith('+84')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('84') && digits.length == 11) {
      digits = '0${digits.substring(2)}';
    }
    return _mobile.hasMatch(digits) ? digits : null;
  }

  static bool isEmail(String input) => _email.hasMatch(input.trim());

  static String? fullName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Vui lòng nhập họ và tên';
    if (s.length > 150) return 'Họ tên tối đa 150 ký tự';
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
    return normalizePhone(v) == null
        ? 'Số điện thoại di động Việt Nam không hợp lệ'
        : null;
  }

  /// Email tuỳ chọn: rỗng là hợp lệ.
  static String? optionalEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    if (s.length > 255) return 'Email tối đa 255 ký tự';
    return isEmail(s) ? null : 'Email không hợp lệ';
  }

  /// Email hoặc số điện thoại (đăng nhập, quên mật khẩu).
  static String? identifier(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Vui lòng nhập email hoặc số điện thoại';
    if (s.contains('@')) return isEmail(s) ? null : 'Email không hợp lệ';
    return normalizePhone(s) == null
        ? 'Số điện thoại hoặc email không hợp lệ'
        : null;
  }

  /// Mật khẩu mới: 8–128 ký tự (backend không yêu cầu thành phần ký tự).
  static String? newPassword(String? v) {
    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < passwordMinLength) {
      return 'Mật khẩu tối thiểu $passwordMinLength ký tự';
    }
    if (v.length > passwordMaxLength) {
      return 'Mật khẩu tối đa $passwordMaxLength ký tự';
    }
    return null;
  }

  /// Mật khẩu hiện có (đăng nhập): không áp luật độ dài để không chặn
  /// tài khoản cũ.
  static String? existingPassword(String? v) =>
      (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null;

  static String? Function(String?) confirmPassword(String Function() other) =>
      (v) => v == other() ? null : 'Mật khẩu xác nhận không khớp';

  /// Mã đặt lại mật khẩu: `{32 hex}.{43 ký tự base64url}`.
  static final _resetToken = RegExp(r'^[a-fA-F0-9]{32}\.[A-Za-z0-9_-]{43}$');
  static bool isResetToken(String v) => _resetToken.hasMatch(v.trim());

  static String? resetToken(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Vui lòng dán mã xác nhận';
    return isResetToken(s) ? null : 'Mã xác nhận không đúng định dạng';
  }

  static bool isOtp(String v) => RegExp(r'^[0-9]{6}$').hasMatch(v);
}
