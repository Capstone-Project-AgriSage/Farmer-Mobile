import 'package:flutter/material.dart';
import '../../../core/widgets/coming_soon_view.dart';

/// There are no notifications to configure yet.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Cài đặt thông báo',
      icon: Icons.notifications_active_outlined,
      message: 'Khi ứng dụng bắt đầu gửi thông báo, Bác sẽ chọn loại thông báo muốn nhận ở đây.',
    );
  }
}
