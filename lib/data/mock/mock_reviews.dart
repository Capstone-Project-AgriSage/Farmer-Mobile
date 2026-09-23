import '../models/review.dart';

final List<Review> mockReviews = [
  Review(
    id: 'r1',
    productId: 'npk-dau-trau', // This matches the slug or ID of a mock product
    userId: 'u123',
    userName: 'Nguyễn Văn Nam',
    userAvatar: '', // Empty for default placeholder
    rating: 5.0,
    comment: 'Phân bón tốt, tan nhanh, lúa xanh mướt. Đại lý giao hàng nhanh chóng, đóng gói cẩn thận.',
    imageUrls: ['https://images.unsplash.com/photo-1627920769843-5daaf19c1181?q=80&w=200&auto=format&fit=crop'],
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Review(
    id: 'r2',
    productId: 'npk-dau-trau',
    userId: 'u456',
    userName: 'Lê Hữu Đạt',
    userAvatar: '',
    rating: 4.0,
    comment: 'Chất lượng ổn định như mọi khi. Tuy nhiên giá dạo này hơi cao một chút.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  Review(
    id: 'r3',
    productId: 'npk-dau-trau',
    userId: 'u789',
    userName: 'Trần Thị Thu',
    userAvatar: '',
    rating: 5.0,
    comment: 'Mình mua nhiều lần ở đại lý này rồi, luôn an tâm về chất lượng hàng chính hãng.',
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    isVerifiedPurchase: true,
  ),
];
