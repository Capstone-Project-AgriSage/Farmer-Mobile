import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'notification_models.dart';

/// Thông báo trong app của người dùng (`/api/me/notifications`).
class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;

  Future<PagedResult<AppNotification>> list({int page = 1, String? status}) =>
      apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/notifications',
          queryParameters:
              cleanQuery({'page': page, 'pageSize': pageSize, 'status': status}),
        );
        return PagedResult.fromJson(res.data!, AppNotification.fromJson);
      });

  Future<int> unreadCount() => apiCall(() async {
        final res =
            await _dio.get<Map<String, dynamic>>('/api/me/notifications/unread-count');
        return asInt(res.data!['count']) ?? 0;
      });

  /// Đánh dấu đã đọc (idempotent).
  Future<void> markRead(String id) => apiCall(
        () => _dio.post<void>('/api/me/notifications/$id/read'),
        messages: {404: 'Thông báo không còn tồn tại.'},
      );

  Future<void> markAllRead() =>
      apiCall(() => _dio.post<void>('/api/me/notifications/read-all'));

  /// Xoá = lưu trữ (không hiện lại trong danh sách).
  Future<void> archive(String id) => apiCall(
        () => _dio.delete<void>('/api/me/notifications/$id'),
        messages: {404: 'Thông báo không còn tồn tại.'},
      );
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => NotificationRepository(ref.watch(dioProvider)));
