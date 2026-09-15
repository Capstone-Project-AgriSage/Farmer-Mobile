import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final List<int> _quantities = [1, 2, 1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('3 sản phẩm', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF0FDF4),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Giao hàng trực tiếp từ Đại lý vật tư gần nhất', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product List
                  _buildCartItem(0, 'Phân NPK Đầu Trâu 20-20-15', 'Bao 50kg', 485000),
                  const SizedBox(height: 12),
                  _buildCartItem(1, 'Thuốc Trừ Bệnh Beam 75WP', 'Gói 100g (92.000đ/gói)', 184000),
                  const SizedBox(height: 12),
                  _buildCartItem(2, 'Lúa Giống ST25 Thượng Hạng', 'Bao 25kg (Cấp xác nhận)', 650000),
                  
                  const SizedBox(height: 24),
                  // Shipping Info
                  _buildSectionHeader(Icons.location_on_outlined, 'THÔNG TIN NHẬN HÀNG', actionText: 'Thay đổi'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Trần Văn Hải', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('|', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.borderStrong)),
                            ),
                            Text('0918 234 567', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Ấp Thới Phước, Thới Lai, Cần Thơ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Note
                  Row(
                    children: [
                      _buildSectionHeader(Icons.edit_note, 'GHI CHÚ CHO ĐẠI LÝ'),
                      const SizedBox(width: 4),
                      Text('(Không bắt buộc)', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
                    child: TextField(
                      decoration: InputDecoration(border: InputBorder.none, hintText: 'Ví dụ: Giao buổi sáng, gọi trước...', hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                      maxLines: 2,
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Summary
                  _buildSectionHeader(Icons.receipt_long_outlined, 'TÓM TẮT ĐƠN HÀNG'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
                    child: Column(
                      children: [
                        _buildSummaryRow('Tạm tính (3 món)', '1.319.000đ'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Phí giao hàng', '0đ'),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.borderSubtle)),
                        _buildSummaryRow('Tổng thanh toán', '1.319.000đ', isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Bottom Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tổng thanh toán', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      Text('1.319.000đ', style: AppTextStyles.h3.copyWith(color: const Color(0xFF1B5E20))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => context.push(AppRoutes.orderConfirm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20), // Dark green
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    children: const [
                      Text('Tiếp tục thanh toán', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, {String? actionText}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF4B5563)),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
          ],
        ),
        if (actionText != null)
          Text(actionText, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isTotal ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold) : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: isTotal ? AppTextStyles.h4.copyWith(color: const Color(0xFF1B5E20)) : AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCartItem(int index, String title, String unit, int price) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Icon(Icons.image_outlined, color: AppColors.borderStrong)),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                  ],
                ),
                const SizedBox(height: 2),
                Text(unit, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${price.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')}đ',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                    ),
                    // Quantity control
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          _buildQuantityBtn(Icons.remove, () {
                            if (_quantities[index] > 1) {
                              setState(() => _quantities[index]--);
                            }
                          }),
                          Container(
                            width: 32,
                            alignment: Alignment.center,
                            child: Text('${_quantities[index]}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          _buildQuantityBtn(Icons.add, () {
                            setState(() => _quantities[index]++);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
