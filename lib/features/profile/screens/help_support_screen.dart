import 'package:flutter/material.dart';
import '../../../core/widgets/coming_soon_view.dart';

/// No support channel exists in the server yet (and no hotline number is known), so none is shown.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Trợ giúp & Hỗ trợ',
      icon: Icons.support_agent,
      message: 'Kênh hỗ trợ trong ứng dụng đang được chuẩn bị. Khi cần giúp đỡ, Bác liên hệ trực tiếp cửa hàng.',
    );
  }
}
