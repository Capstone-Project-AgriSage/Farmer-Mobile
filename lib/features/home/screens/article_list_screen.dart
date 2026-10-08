import 'package:flutter/material.dart';
import '../../../core/widgets/coming_soon_view.dart';

/// The server has no article feature yet, so there is nothing to list.
class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Tin tức & Kiến thức',
      icon: Icons.article_outlined,
      message: 'Bài viết về kỹ thuật canh tác, phòng trừ sâu bệnh và giá nông sản sẽ có ở đây.',
    );
  }
}
