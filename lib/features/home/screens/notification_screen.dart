import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/notification.dart';
import '../../../data/mock/mock_notifications.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: AppColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đánh dấu tất cả là đã đọc')),
              );
            },
          ),
        ],
      ),
      body: mockNotifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none, size: 64, color: AppColors.surfaceDim),
                  const SizedBox(height: 16),
                  Text('Bạn không có thông báo nào', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                ],
              ),
            )
          : ListView.separated(
              itemCount: mockNotifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (context, index) {
                final notification = mockNotifications[index];
                return _NotificationItem(notification: notification);
              },
            ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (notification.route != null) {
          context.push(notification.route!);
        }
      },
      child: Container(
        color: notification.isRead ? Colors.white : const Color(0xFFF0FDF4),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(notification.type),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(notification.type),
                color: _getIconColor(notification.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: notification.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.statusError,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: notification.isRead ? AppColors.textMuted : AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notification.createdAt),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.order: return Icons.local_shipping_outlined;
      case NotificationType.debt: return Icons.account_balance_wallet_outlined;
      case NotificationType.system: return Icons.system_update_outlined;
      case NotificationType.promotion: return Icons.campaign_outlined;
    }
  }

  Color _getIconColor(NotificationType type) {
    switch (type) {
      case NotificationType.order: return AppColors.primary;
      case NotificationType.debt: return AppColors.statusError;
      case NotificationType.system: return const Color(0xFF1565C0);
      case NotificationType.promotion: return const Color(0xFFE65100);
    }
  }

  Color _getIconBackgroundColor(NotificationType type) {
    return _getIconColor(type).withOpacity(0.1);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
