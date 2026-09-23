class Review {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String userAvatar;
  final double rating;
  final String comment;
  final List<String> imageUrls;
  final DateTime createdAt;
  final bool isVerifiedPurchase;

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.comment,
    this.imageUrls = const [],
    required this.createdAt,
    this.isVerifiedPurchase = true,
  });
}
