import '../utils/json_utils.dart';

/// The server's page envelope: `{ items, page, pageSize, totalCount }`.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  const Paged.empty()
      : items = const [],
        page = 1,
        pageSize = 20,
        totalCount = 0;

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  int get totalPages => pageSize <= 0 ? 0 : (totalCount + pageSize - 1) ~/ pageSize;
  bool get hasMore => page < totalPages;

  factory Paged.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic> json) parse) {
    final raw = json['items'];
    final items = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(parse).toList(growable: false)
        : <T>[];
    return Paged(
      items: items,
      page: asInt(json['page'], 1),
      pageSize: asInt(json['pageSize'], items.length),
      totalCount: asInt(json['totalCount'], items.length),
    );
  }

  /// This page followed by the next one (infinite scroll).
  Paged<T> append(Paged<T> next) => Paged(
        items: [...items, ...next.items],
        page: next.page,
        pageSize: next.pageSize,
        totalCount: next.totalCount,
      );
}
