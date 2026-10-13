import 'package:flutter/material.dart';

import '../../../shared/widgets/coming_soon_view.dart';

/// Tuỳ chọn bật/tắt từng loại thông báo: backend chưa có API lưu cài đặt, nên
/// màn này nói rõ thay vì hiện các công tắc không có tác dụng.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Cài đặt thông báo',
      icon: Icons.notifications_active_outlined,
      message:
          'Hiện tại bạn nhận mọi thông báo về đơn hàng, công nợ, trả hàng và chẩn đoán trong mục Thông báo ở Trang chủ. '
          'Tuỳ chọn bật/tắt từng loại thông báo sẽ sớm có.',
    );
  }
}
