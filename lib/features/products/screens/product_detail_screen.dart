import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class ProductDetailScreen extends StatefulWidget {
  final String slug;
  const ProductDetailScreen({super.key, required this.slug});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
                onPressed: () => context.go(AppRoutes.cart),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.statusError, shape: BoxShape.circle),
                  child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Placeholder
            Container(
              height: 250,
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.borderStrong)),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('Chính hãng Bình Điền', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Info Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                        child: Text('Phân bón', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.statusSuccess),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 8, color: AppColors.statusSuccess),
                            const SizedBox(width: 4),
                            Text('Còn hàng', style: AppTextStyles.caption.copyWith(color: AppColors.statusSuccess, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Phân NPK Đầu Trâu 20-20-15', style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('485.000đ', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('/ bao 50kg', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),

            // Specs
            _buildSection(
              icon: Icons.tune,
              title: 'Thông số kỹ thuật',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildSpecRow('Đơn vị tính', 'Bao 50kg'),
                    const SizedBox(height: 12),
                    _buildSpecRow('Nhà sản xuất', 'Công ty CP Phân bón Bình Điền'),
                    const SizedBox(height: 12),
                    _buildSpecRow('Thành phần chính', 'N 20%, P2O5 20%, K2O 15% + TE (Vi lượng Bo, kẽm)'),
                    const SizedBox(height: 12),
                    _buildSpecRow('Quy cách đóng gói', 'Bao PE + PP chống ẩm 50kg'),
                  ],
                ),
              ),
            ),

            // Description
            _buildSection(
              icon: Icons.description_outlined,
              title: 'Thông tin sản phẩm',
              child: Text(
                'Phân bón NPK Đầu Trâu 20-20-15 bổ sung đầy đủ và cân đối hàm lượng đa - trung - vi lượng thiết yếu, giúp lúa đẻ nhánh khỏe, cứng cây, tăng tỷ lệ hạt chắc trên bông, tăng sức chống chịu sâu bệnh và điều kiện phèn, mặn tại vùng Đồng bằng sông Cửu Long.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.6),
              ),
            ),

            // Usage Guide
            _buildSection(
              icon: Icons.menu_book_outlined,
              title: 'Hướng dẫn sử dụng',
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusWarningSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.statusWarning.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.statusWarning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Nông dân tham khảo hướng dẫn trên bao bì và khuyến cáo kỹ thuật của đại lý vật tư nông nghiệp địa phương.', style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning.withOpacity(0.9), fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUsageItem('ĐỐI TƯỢNG SỬ DỤNG', 'Cây lúa (các vụ Đông Xuân, Hè Thu), cây ăn trái.'),
                        const SizedBox(height: 16),
                        _buildUsageItem('THỜI ĐIỂM BÓN', 'Bón đón đòng (40-45 ngày sau sạ) hoặc bón nuôi hạt.'),
                        const SizedBox(height: 16),
                        _buildUsageItem('LIỀU LƯỢNG THAM KHẢO', '80 - 100 kg/ha cho mỗi lần bón tùy chất đất.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Safety Warning
            _buildSection(
              icon: Icons.shield_outlined,
              title: 'Lưu ý an toàn',
              iconColor: AppColors.statusError,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildSafetyItem('Đọc kỹ hướng dẫn sử dụng in trên bao bì trước khi bón.'),
                    const SizedBox(height: 12),
                    _buildSafetyItem('Sử dụng găng tay, khẩu trang và đồ bảo hộ lao động khi pha trộn hoặc bón phân.'),
                    const SizedBox(height: 12),
                    _buildSafetyItem('Bảo quản nơi khô ráo, thoáng mát, xa nguồn nước sinh hoạt và tầm tay trẻ em.'),
                  ],
                ),
              ),
            ),

            // Related Products
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sản phẩm liên quan', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  Text('Xem thêm >', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _buildRelatedProduct('Thuốc Trừ Bệnh Beam 75WP', '90.000đ', 'gói 100g', true),
                  const SizedBox(width: 12),
                  _buildRelatedProduct('Lúa Giống ST25 Thượng Hạng', '650.000đ', 'bao 20kg', false),
                ],
              ),
            ),
            const SizedBox(height: 100), // padding for bottom bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            // Quantity Selector
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: () => setState(() { if (_quantity > 1) _quantity--; }),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('$_quantity', textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => setState(() { _quantity++; }),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Add to Cart Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Đã thêm vào giỏ hàng', style: TextStyle(color: Colors.white)),
                    backgroundColor: AppColors.primary,
                  ));
                },
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                label: const Text('Thêm vào giỏ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required Widget child, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildUsageItem(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(desc, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildSafetyItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.statusError, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
      ],
    );
  }

  Widget _buildRelatedProduct(String title, String price, String unit, bool isAvailable) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Center(child: Icon(Icons.image_outlined, size: 40, color: AppColors.borderStrong)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAvailable ? AppColors.primaryLight : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(isAvailable ? 'Còn hàng' : 'Sắp hết', style: TextStyle(fontSize: 9, color: isAvailable ? AppColors.primary : Colors.orange.shade800, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text(price, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                Text(unit, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
