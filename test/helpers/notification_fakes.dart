import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/features/notifications/data/notification_models.dart';
import 'package:farmer_mobile/features/notifications/data/notification_repository.dart';

Map<String, dynamic> notifJson(
  String id, {
  String type = 'ORDER_STATUS_CHANGED',
  String title = 'Đơn hàng đã được xác nhận',
  String message = 'Đơn hàng đã được xác nhận. Vui lòng xem chi tiết đơn hàng.',
  bool read = false,
  String? entityType = 'ORDER',
  String? entityId,
  String? orderId,
  bool noData = false,
}) =>
    {
      'id': id,
      'notificationType': type,
      'title': title,
      'message': message,
      'data': noData
          ? null
          : {'entityType': entityType, 'entityId': entityId ?? 'e-$id', 'orderId': orderId},
      'status': read ? 'READ' : 'UNREAD',
      'readAt': read ? '2026-10-12T04:00:00Z' : null,
      'createdAt': '2026-10-12T02:00:00Z',
    };

AppNotification notifOf(
  String id, {
  String type = 'ORDER_STATUS_CHANGED',
  String title = 'Đơn hàng đã được xác nhận',
  bool read = false,
  String? entityType = 'ORDER',
  String? entityId,
  String? orderId,
  DateTime? at,
}) =>
    AppNotification(
      id: id,
      type: type,
      title: title,
      message: 'Nội dung $id',
      createdAt: at ?? DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: read,
      entityType: entityType,
      entityId: entityType == null ? null : (entityId ?? 'e-$id'),
      orderId: orderId,
    );

class FakeNotificationRepository extends NotificationRepository {
  FakeNotificationRepository() : super(Dio());

  final List<String> calls = [];
  List<AppNotification> items = [];
  int pageSize0 = 20;
  int? unread0;

  Object? listError;
  Object? countError;
  Object? readError;
  Object? readAllError;
  Object? archiveError;
  Future<void>? readGate;

  final List<({int page, String? status})> listCalls = [];
  final List<String> read = [];
  final List<String> archived = [];

  int get unread => unread0 ?? items.where((n) => !n.isRead).length;

  @override
  Future<PagedResult<AppNotification>> list({int page = 1, String? status}) async {
    calls.add('list');
    listCalls.add((page: page, status: status));
    if (listError != null) throw listError!;
    final filtered = items.where((n) => status == null || !n.isRead).toList();
    final per = pageSize0;
    return PagedResult(
      items: filtered.skip((page - 1) * per).take(per).toList(),
      page: page,
      pageSize: per,
      totalCount: filtered.length,
      totalPages: (filtered.length + per - 1) ~/ per,
    );
  }

  @override
  Future<int> unreadCount() async {
    calls.add('count');
    if (countError != null) throw countError!;
    return unread;
  }

  @override
  Future<void> markRead(String id) async {
    calls.add('read:$id');
    await readGate;
    if (readError != null) throw readError!;
    read.add(id);
    items = [for (final n in items) n.id == id ? n.asRead() : n];
  }

  @override
  Future<void> markAllRead() async {
    calls.add('readAll');
    if (readAllError != null) throw readAllError!;
    items = [for (final n in items) n.asRead()];
  }

  @override
  Future<void> archive(String id) async {
    calls.add('archive:$id');
    if (archiveError != null) throw archiveError!;
    archived.add(id);
    items = [for (final n in items) if (n.id != id) n];
  }
}

const notifNet = ApiException(
    kind: ApiErrorKind.network, message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.');
