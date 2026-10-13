import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/json_utils.dart';

/// Trạng thái thông báo (`NotificationStatus` của backend).
abstract class NotificationStatus {
  static const unread = 'UNREAD';
  static const read = 'READ';

  /// Bộ lọc ở danh sách: null = tất cả (backend loại sẵn thông báo đã xoá).
  static const filters = <String?>[null, unread];

  static String label(String? s) => switch (s) {
        null => 'Tất cả',
        unread => 'Chưa đọc',
        _ => s,
      };
}

/// Nhóm hiển thị (biểu tượng + màu) của một thông báo, suy ra từ `notificationType`.
enum NotificationKind { order, delivery, payment, debt, returns, diagnosis, other }

NotificationKind kindOf(String type) {
  if (type.startsWith('ORDER_')) return NotificationKind.order;
  if (type.startsWith('DELIVERY_')) return NotificationKind.delivery;
  if (type.startsWith('PAYMENT_')) return NotificationKind.payment;
  if (type.startsWith('DEBT_') || type == 'CREDIT_LIMIT_CHANGED') {
    return NotificationKind.debt;
  }
  if (type.startsWith('RETURN_') || type.startsWith('REFUND_')) {
    return NotificationKind.returns;
  }
  if (type.contains('DIAGNOSIS')) return NotificationKind.diagnosis;
  return NotificationKind.other;
}

extension NotificationKindX on NotificationKind {
  IconData get icon => switch (this) {
        NotificationKind.order => Icons.receipt_long_outlined,
        NotificationKind.delivery => Icons.local_shipping_outlined,
        NotificationKind.payment => Icons.payments_outlined,
        NotificationKind.debt => Icons.account_balance_wallet_outlined,
        NotificationKind.returns => Icons.assignment_return_outlined,
        NotificationKind.diagnosis => Icons.eco_outlined,
        NotificationKind.other => Icons.notifications_outlined,
      };

  Color get color => switch (this) {
        NotificationKind.order || NotificationKind.delivery => AppColors.primary,
        NotificationKind.payment => const Color(0xFF1565C0),
        NotificationKind.debt => AppColors.statusError,
        NotificationKind.returns => const Color(0xFF6A1B9A),
        NotificationKind.diagnosis => AppColors.statusSuccess,
        NotificationKind.other => AppColors.textSecondary,
      };
}

/// Một thông báo (`NotificationResponse`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.entityType,
    this.entityId,
    this.orderId,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  /// `data` của backend chỉ chứa thông tin điều hướng.
  final String? entityType;
  final String? entityId;
  final String? orderId;

  NotificationKind get kind => kindOf(type);

  AppNotification asRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        message: message,
        createdAt: createdAt,
        isRead: true,
        entityType: entityType,
        entityId: entityId,
        orderId: orderId,
      );

  /// Màn hình tương ứng của app; null = không có nơi để mở.
  String? get route {
    final id = entityId;
    final order = orderId;
    switch (entityType) {
      case 'ORDER':
        return id == null ? null : '/orders/$id';
      case 'DELIVERY':
        return order == null ? null : '/orders/$order';
      case 'PAYMENT':
        // Thanh toán đơn hàng có orderId; trả nợ thì không.
        return order == null ? '/debt' : '/orders/$order';
      case 'DEBT_ENTRY':
        return id == null ? '/debt' : '/debt/$id';
      case 'CREDIT_PROFILE':
        return '/debt';
      case 'SALES_RETURN':
        return id == null ? '/returns' : '/returns/$id';
      case 'REFUND':
        return order == null ? '/returns' : '/orders/$order';
      case 'DIAGNOSIS_CASE':
        return id == null ? null : '/ai-scan/case/$id';
    }
    return null;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final m = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return AppNotification(
      id: json['id'] as String,
      type: json['notificationType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      isRead: json['status'] != NotificationStatus.unread,
      entityType: m['entityType']?.toString(),
      entityId: m['entityId']?.toString(),
      orderId: m['orderId']?.toString(),
    );
  }
}
