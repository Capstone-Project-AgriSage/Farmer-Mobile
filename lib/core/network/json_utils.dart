/// Helper parse JSON của backend (ASP.NET, camelCase, decimal là số JSON,
/// thời gian là ISO-8601 có offset).
double? asDouble(Object? v) => v == null ? null : (v as num).toDouble();

double asDoubleOr0(Object? v) => asDouble(v) ?? 0;

int? asInt(Object? v) => v == null ? null : (v as num).toInt();

DateTime? asDate(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

/// Bỏ các tham số query null/rỗng để không gửi `?search=null`.
Map<String, dynamic> cleanQuery(Map<String, dynamic> query) => {
      for (final e in query.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value,
    };
