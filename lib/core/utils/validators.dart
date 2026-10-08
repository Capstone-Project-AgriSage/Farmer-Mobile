// Form checks that mirror the backend rules, so most mistakes are caught before a request is sent. The server still
// decides; each of these returns a Vietnamese message, or null when the value is acceptable.

/// The backend's rule: `^(0|\+?84)(3|5|7|8|9)\d{8}$` after removing separators.
final RegExp _vnMobile = RegExp(r'^(0|\+?84)(3|5|7|8|9)\d{8}$');

String? validateRequired(String? value, String message) =>
    (value == null || value.trim().isEmpty) ? message : null;

String? validateFullName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Vui lòng nhập họ và tên';
  if (text.length > 150) return 'Họ và tên tối đa 150 ký tự';
  return null;
}

bool isValidVnPhone(String? value) => _vnMobile.hasMatch(stripPhoneSeparators(value ?? ''));

String stripPhoneSeparators(String value) => value.replaceAll(RegExp(r'[\s.\-()]'), '');

String? validateVnPhone(String? value) {
  if (value == null || value.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
  if (!isValidVnPhone(value)) return 'Số điện thoại chưa hợp lệ (ví dụ 0912345678)';
  return null;
}

/// Empty is allowed; otherwise it must look like an email.
String? validateOptionalEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.length > 254 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
    return 'Email chưa đúng định dạng';
  }
  return null;
}

/// New passwords: 8 to 128 characters (the backend's `PasswordRules`).
String? validateNewPassword(String? value) {
  final text = value ?? '';
  if (text.isEmpty) return 'Vui lòng nhập mật khẩu';
  if (text.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
  if (text.length > 128) return 'Mật khẩu tối đa 128 ký tự';
  return null;
}
