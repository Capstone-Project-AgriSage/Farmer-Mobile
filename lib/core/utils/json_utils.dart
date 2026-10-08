// Small readers for the loosely typed JSON the API returns (numbers can arrive as int or double, dates as ISO text).

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool asBool(Object? value, [bool fallback = false]) => value is bool ? value : fallback;

String asString(Object? value, [String fallback = '']) => value is String ? value : fallback;

String? asStringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;

/// ISO 8601 text to a UTC [DateTime]. Text without an offset is read as UTC, as the server writes UTC.
DateTime? asDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed : DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
  );
}

List<Map<String, dynamic>> asObjectList(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList(growable: false) : const [];
