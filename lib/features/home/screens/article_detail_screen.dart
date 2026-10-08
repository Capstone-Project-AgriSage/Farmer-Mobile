import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/mock/mock_articles.dart';

class ArticleDetailScreen extends StatelessWidget {
  final String articleId;
  const ArticleDetailScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context) {
    final article = mockArticles.firstWhere((a) => a.id == articleId, orElse: () => mockArticles.first);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(article.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      article.title,
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            
            // Meta Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(article.author, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          DateFormat('dd/MM/yyyy - HH:mm').format(article.publishedAt),
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${article.viewCount}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1, color: AppColors.borderSubtle),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                article.content,
                style: AppTextStyles.bodyMedium.copyWith(
                  height: 1.8,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
