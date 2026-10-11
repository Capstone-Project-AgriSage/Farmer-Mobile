import 'package:intl/intl.dart';

final _vnd = NumberFormat('#,##0', 'vi_VN');

/// 485000 → "485.000đ". Tiền VND không có phần lẻ khi hiển thị.
String formatVnd(num amount) => '${_vnd.format(amount.round())}đ';
