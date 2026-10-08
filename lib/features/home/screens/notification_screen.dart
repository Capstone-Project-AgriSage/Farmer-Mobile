import 'package:flutter/material.dart';
import '../../../core/widgets/coming_soon_view.dart';

/// The server has no notification feature yet, so there is nothing to list.
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Thông báo',
      icon: Icons.notifications_none_outlined,
      message: 'Thông báo từ cửa hàng sẽ hiện ở đây. Hiện Bác xem trạng thái đơn hàng ở mục Đơn hàng và công nợ ở mục Công nợ.',
    );
  }
}
