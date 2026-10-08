/// `1.234.567 ₫` (Vietnamese grouping). Whole amounts show no decimals; a fraction shows up to two.
String formatVnd(num value, {bool symbol = true}) {
  final negative = value < 0;
  final cents = (value.abs() * 100).round();
  final whole = cents ~/ 100;
  final fraction = cents % 100;

  final digits = whole.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }

  var text = grouped.toString();
  if (fraction != 0) {
    text +=
        ',${fraction.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
  }
  return '${negative ? '-' : ''}$text${symbol ? ' ₫' : ''}';
}

/// A quantity without a pointless `.0` (`3` not `3.0`, `2.5` stays).
String formatQuantity(num value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Up to two letters for an avatar: the first letter of the first and of the last word that has one
/// (`Trần Văn Hải` -> `TH`; a trailing `(sửa)` still counts as the word `sửa`).
String initialsOf(String name) {
  final letters = name
      .trim()
      .split(RegExp(r'\s+'))
      .map((word) => _letterOrDigit.firstMatch(word)?[0])
      .whereType<String>()
      .toList();
  if (letters.isEmpty) return '?';
  if (letters.length == 1) return letters.first.toUpperCase();
  return (letters.first + letters.last).toUpperCase();
}
