// Vietnam has no daylight saving: UTC+7 all year. The device clock may be set to any zone, so every date the app
// shows (and "today") is computed from UTC explicitly.

const vnOffset = Duration(hours: 7);

/// The wall-clock time in Vietnam, held in a UTC-flagged [DateTime] so its fields read as Vietnam time.
DateTime toVn(DateTime instant) => instant.toUtc().add(vnOffset);

/// Today's date in Vietnam (midnight, UTC-flagged).
DateTime vnToday([DateTime? now]) {
  final vn = toVn(now ?? DateTime.now());
  return DateTime.utc(vn.year, vn.month, vn.day);
}

/// `yyyy-MM-dd`, the form the API takes for `fromDate` / `toDate`.
String vnDateIso(DateTime instant) {
  final vn = toVn(instant);
  return '${vn.year.toString().padLeft(4, '0')}-${_two(vn.month)}-${_two(vn.day)}';
}

/// `dd/MM/yyyy`
String formatVnDate(DateTime? instant) {
  if (instant == null) return '—';
  final vn = toVn(instant);
  return '${_two(vn.day)}/${_two(vn.month)}/${vn.year}';
}

/// `HH:mm dd/MM/yyyy`
String formatVnDateTime(DateTime? instant) {
  if (instant == null) return '—';
  final vn = toVn(instant);
  return '${_two(vn.hour)}:${_two(vn.minute)} ${_two(vn.day)}/${_two(vn.month)}/${vn.year}';
}

String _two(int value) => value.toString().padLeft(2, '0');
