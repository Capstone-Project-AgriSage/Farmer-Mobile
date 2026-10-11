/// Khớp `PagedResult<T>` của backend: `{items, page, pageSize, totalCount, totalPages}`.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    return PagedResult(
      items: [
        for (final item in (json['items'] as List? ?? const []))
          fromItem(item as Map<String, dynamic>),
      ],
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}
