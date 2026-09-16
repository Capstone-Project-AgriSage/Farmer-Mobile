import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/mock/mock_diagnoses.dart';
import '../../../router/app_router.dart';

class ProductSuggestionScreen extends StatelessWidget {
  const ProductSuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = mockDiagnoses[0]; // Đạo ôn lá — đã có suggestedProducts
    final products = result.suggestedProducts;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Thuốc gợi ý')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Approved Badge ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.statusSuccess,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Đại lý đã duyệt', style: AppTextStyles.labelLarge.copyWith(color: const Color(0xFF1B5E20))),
                              Text('Sản phẩm phù hợp với bệnh ${result.diseaseName}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Disease Summary ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B1FA2).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.blur_on, color: Color(0xFF7B1FA2), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(result.diseaseName, style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                              Text(result.diseaseNameEn, style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${(result.confidence * 100).toInt()}%', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Section Header ──────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.local_florist, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('SẢN PHẨM ĐƯỢC GỢI Ý (${products.length})', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Product Cards ───────────────────────────────────
                  ...products.asMap().entries.map((entry) {
                    final i = entry.key;
                    final product = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < products.length - 1 ? 12 : 0),
                      child: _ProductCard(product: product),
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Note ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFE082))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sản phẩm được đại lý chọn dựa trên kết quả chẩn đoán AI. Liên hệ đại lý nếu cần tư vấn thêm.',
                            style: AppTextStyles.caption.copyWith(color: const Color(0xFF5D4037), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // ── Bottom Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tổng ${products.length} sản phẩm', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    Text(
                      '${_formatPrice(products.fold<int>(0, (sum, p) => sum + p.price))}đ',
                      style: AppTextStyles.h4.copyWith(color: const Color(0xFF1B5E20)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.cart),
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text('Thêm tất cả vào giỏ hàng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Image + Name + Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(Icons.medication_outlined, color: AppColors.primary, size: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(product.unit, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Text(
                      '${product.price.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')}đ',
                      style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),

          // Usage
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cách dùng:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    Text(product.usage, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dosage
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.science_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Liều lượng:', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    Text(product.dosage, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Add to cart button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã thêm ${product.name} vào giỏ hàng'), duration: const Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text('Thêm vào giỏ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: const BorderSide(color: AppColors.primary),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
