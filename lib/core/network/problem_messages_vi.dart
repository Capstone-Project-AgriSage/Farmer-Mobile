// Turns the backend's English ProblemDetails text into Vietnamese.
//
// The server writes `detail` in English and the app cannot change that, so the messages a farmer can really hit are
// listed here. Anything that does not match returns null and the caller falls back to a sentence for the status code.

typedef _Build = String Function(RegExpMatch match);

class _Rule {
  const _Rule(this.pattern, this.build);
  final RegExp pattern;
  final _Build build;
}

final List<_Rule> _rules = [
  // ── Account ────────────────────────────────────────────────────
  _rule(r'Invalid phone number, email or password', (_) => 'Số điện thoại/email hoặc mật khẩu chưa đúng.'),
  _rule(r'current password is incorrect', (_) => 'Mật khẩu hiện tại chưa đúng.'),
  _rule(r'new password must be different', (_) => 'Mật khẩu mới phải khác mật khẩu hiện tại.'),
  _rule(r'account with this (phone number|email).*already exists',
      (_) => 'Số điện thoại hoặc email này đã được đăng ký.'),
  _rule(r'account is not active', (_) => 'Tài khoản đang bị khóa hoặc chưa kích hoạt.'),
  _rule(r'no customer profile',
      (_) => 'Tài khoản chưa có hồ sơ khách hàng. Vui lòng liên hệ cửa hàng để được hỗ trợ.'),
  _rule(r'Authentication is required', (_) => 'Bạn cần đăng nhập để tiếp tục.'),
  _rule(r'phone (number )?must be a valid Vietnamese mobile|phone must be a valid Vietnamese mobile|Invalid phone number',
      (_) => 'Số điện thoại chưa hợp lệ.'),
  _rule(r'A phone number or an email is required', (_) => 'Cần nhập số điện thoại hoặc email.'),
  // ── Addresses ──────────────────────────────────────────────────
  _rule(r'keep at most (\d+) addresses', (m) => 'Bác chỉ lưu được tối đa ${m[1]} địa chỉ.'),
  _rule(r'default address changed at the same time', (_) => 'Địa chỉ mặc định vừa thay đổi, vui lòng thử lại.'),
  // ── Cart / order ───────────────────────────────────────────────
  _rule(r'cart is empty', (_) => 'Giỏ hàng đang trống.'),
  _rule(r'line\(s\) cannot be ordered',
      (_) => 'Có sản phẩm trong giỏ không đặt được (hết hàng hoặc chưa có giá). Vui lòng kiểm tra lại giỏ hàng.'),
  _rule(r'only an order waiting for confirmation can be cancelled online',
      (_) => 'Chỉ hủy được đơn đang chờ cửa hàng xác nhận. Bác vui lòng liên hệ cửa hàng.'),
  _rule(r'Not enough sellable stock', (_) => 'Kho không đủ hàng cho đơn ghi nợ này.'),
  _rule(r'addressId must be one of', (_) => 'Địa chỉ giao hàng không hợp lệ. Vui lòng chọn lại.'),
  _rule(r'DELIVERY order needs exactly one of', (_) => 'Vui lòng chọn một địa chỉ giao hàng.'),
  _rule(r'at most \d+ lines', (_) => 'Một đơn hàng có tối đa số dòng cho phép. Vui lòng giảm bớt sản phẩm.'),
  // ── Payment ────────────────────────────────────────────────────
  _rule(r'cannot take a payment', (_) => 'Đơn hàng ở trạng thái hiện tại không thể thanh toán.'),
  _rule(r'has nothing left to pay', (_) => 'Đơn hàng không còn khoản nào cần thanh toán.'),
  _rule(r'earlier online payment for this order has just been confirmed',
      (_) => 'Khoản thanh toán trước của đơn này vừa được xác nhận. Vui lòng kiểm tra lại đơn hàng.'),
  _rule(r'only a pending payment can be (cancelled|paid)',
      (_) => 'Giao dịch này không còn ở trạng thái chờ thanh toán.'),
  _rule(r'payOS takes whole VND only', (_) => 'Cổng thanh toán chỉ nhận số tiền tròn đồng.'),
  _rule(r'customer owes ([\d.,]+); the payment is', (m) => 'Số tiền trả vượt quá dư nợ hiện tại (${m[1]} đ).'),
  _rule(r'Payment must be positive and within current outstanding debt',
      (_) => 'Số tiền trả phải lớn hơn 0 và không vượt quá dư nợ hiện tại.'),
  // ── Debt / credit ──────────────────────────────────────────────
  _rule(r'Debt actions require a reason|A reason is required|requires a reason', (_) => 'Vui lòng nhập lý do.'),
  _rule(r'Payment does not cover the order total', (_) => 'Khoản thanh toán chưa đủ cho tổng đơn hàng.'),
  _rule(r'Credit refused: OVERDUE_DEBT',
      (_) => 'Bác đang có nợ quá hạn nên chưa mua ghi nợ được. Bác thanh toán khoản quá hạn hoặc chọn trả bằng payOS.'),
  _rule(r'Credit refused: INSUFFICIENT_CREDIT',
      (_) => 'Hạn mức ghi nợ còn lại chưa đủ cho đơn này. Bác chọn trả bằng payOS hoặc giảm bớt sản phẩm.'),
  _rule(r'Credit refused: (CREDIT_DISABLED|NO_CREDIT_LIMIT|NO_CREDIT_TERM|CUSTOMER_INACTIVE|CUSTOMER_NOT_FOUND)',
      (_) => 'Bác chưa dùng được hình thức mua ghi nợ (chưa có hạn mức hoặc hồ sơ đang bị khóa). Vui lòng chọn payOS.'),
  _rule(r'Credit refused', (_) => 'Cửa hàng chưa cho Bác mua ghi nợ đơn này. Vui lòng chọn payOS.'),
  // ── Returns ────────────────────────────────────────────────────
  _rule(r'cancel only a REQUESTED return', (_) => 'Chỉ hủy được yêu cầu trả hàng đang chờ xử lý.'),
  _rule(r'returned quantity exceeds', (_) => 'Số lượng trả vượt quá số lượng đã nhận.'),
  // ── Delivery (driver app) ──────────────────────────────────────
  _rule(r"receiver's name and a proof photo are required", (_) => 'Cần nhập tên người nhận và chụp ảnh bằng chứng.'),
  _rule(r'Nothing was delivered: give the failure reason', (_) => 'Vui lòng nhập lý do không giao được.'),
  _rule(r'Only an active member of the store can carry out',
      (_) => 'Chỉ nhân viên đang hoạt động của cửa hàng mới thực hiện được việc giao hàng.'),
  // ── Concurrency / throttling ───────────────────────────────────
  _rule(r'at the same time; (try again|reload)', (_) => 'Có thao tác khác diễn ra cùng lúc. Vui lòng thử lại.'),
  _rule(r'changed by someone else', (_) => 'Dữ liệu vừa được thay đổi ở nơi khác. Vui lòng tải lại và thử lại.'),
  _rule(r'same unique value already exists', (_) => 'Thông tin này đã tồn tại.'),
  _rule(r'Too many attempts', (_) => 'Bạn thao tác quá nhiều. Vui lòng thử lại sau 1 phút.'),
  // ── Not found ──────────────────────────────────────────────────
  _rule(r"^(Customer debt account|Customer credit profile) .*was not found", (_) => 'Bác chưa có sổ nợ.'),
  _rule(r"^Order .*was not found", (_) => 'Không tìm thấy đơn hàng.'),
  _rule(r"^Payment .*was not found", (_) => 'Không tìm thấy giao dịch thanh toán.'),
  _rule(r"^Debt entry .*was not found", (_) => 'Không tìm thấy khoản nợ.'),
  _rule(r"^Address .*was not found", (_) => 'Không tìm thấy địa chỉ.'),
  _rule(r"^Delivery .*was not found", (_) => 'Không tìm thấy phiếu giao hàng.'),
  _rule(r"^Sales return .*was not found", (_) => 'Không tìm thấy yêu cầu trả hàng.'),
  _rule(r"was not found", (_) => 'Không tìm thấy dữ liệu yêu cầu.'),
  // ── Request validation (FluentValidation) ──────────────────────
  _rule(r"'([^']+)' must not be empty", (m) => '${_fieldName(m[1]!)} không được để trống.'),
  _rule(r"length of '([^']+)' must be at least (\d+) characters",
      (m) => '${_fieldName(m[1]!)} phải có ít nhất ${m[2]} ký tự.'),
  _rule(r"length of '([^']+)' must be (\d+) characters or fewer",
      (m) => '${_fieldName(m[1]!)} tối đa ${m[2]} ký tự.'),
  _rule(r"'([^']+)' is not a valid email address", (_) => 'Email chưa đúng định dạng.'),
];

_Rule _rule(String pattern, _Build build) => _Rule(RegExp(pattern, caseSensitive: false), build);

const _fieldNames = <String, String>{
  'fullname': 'Họ tên',
  'password': 'Mật khẩu',
  'newpassword': 'Mật khẩu mới',
  'currentpassword': 'Mật khẩu hiện tại',
  'phonenumber': 'Số điện thoại',
  'email': 'Email',
  'identifier': 'Số điện thoại hoặc email',
  'reason': 'Lý do',
};

// FluentValidation names a property by its display text (`Full Name`), the JSON key has no space (`fullName`).
String _fieldName(String key) => _fieldNames[key.toLowerCase().replaceAll(' ', '')] ?? 'Thông tin này';

/// The Vietnamese text for one server message, or null when nothing in the table matches.
String? translateProblemDetail(String? detail) {
  final text = detail?.trim();
  if (text == null || text.isEmpty) return null;
  for (final rule in _rules) {
    final match = rule.pattern.firstMatch(text);
    if (match != null) return rule.build(match);
  }
  return null;
}

/// The sentence shown when the server text is unknown. Keyed by HTTP status.
String fallbackMessageForStatus(int? status) => switch (status) {
      400 => 'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.',
      401 => 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      403 => 'Bác không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu yêu cầu.',
      409 => 'Có thao tác khác diễn ra cùng lúc. Vui lòng thử lại.',
      422 => 'Không thực hiện được thao tác này ở trạng thái hiện tại.',
      429 => 'Bạn thao tác quá nhiều. Vui lòng thử lại sau 1 phút.',
      503 => 'Hệ thống tạm thời chưa phục vụ được. Vui lòng thử lại sau ít phút.',
      final s? when s >= 500 => 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.',
      _ => 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.',
    };
