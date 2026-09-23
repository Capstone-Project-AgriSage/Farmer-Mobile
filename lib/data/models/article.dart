class Article {
  final String id;
  final String title;
  final String snippet;
  final String content;
  final String imageUrl;
  final String category;
  final String author;
  final DateTime publishedAt;
  final int viewCount;

  Article({
    required this.id,
    required this.title,
    required this.snippet,
    required this.content,
    required this.imageUrl,
    required this.category,
    required this.author,
    required this.publishedAt,
    this.viewCount = 0,
  });
}
