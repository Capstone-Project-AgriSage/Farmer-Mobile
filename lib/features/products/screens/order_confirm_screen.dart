import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class OrderConfirmScreen extends StatefulWidget {
  const OrderConfirmScreen({super.key});
  @override State<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends State<OrderConfirmScreen> {
  int _selectedPayment = 0; // 0: VietQR, 1: Ghi nợ
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Thanh toán'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
              child: Text('Bảo mật', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Trần Văn Hải', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            Text('0918 234 567', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Ấp Thới Phước, Xã Thới Đông, Thới Lai, Cần Thơ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.edit_note, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('Ghi chú: Giao buổi sáng, gọi trước khi chở phân', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Order Items Summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(Icons.receipt_long_outlined, 'ĐƠN HÀNG'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
                        child: Text('3 sản phẩm', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
                    child: Column(
                      children: [
                        _buildOrderItem('Phân NPK Đầu Trâu 20-20-15', 'Bao 50kg • SL: 1', '485.000đ'),
                        const SizedBox(height: 16),
                        _buildOrderItem('Thuốc Trừ Bệnh Beam 75WP', 'Gói 100g • SL: 2', '184.000đ'),
                        const SizedBox(height: 16),
                        _buildOrderItem('Lúa Giống ST25 Thượng Hạng', 'Bao 25kg • SL: 1', '650.000đ'),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.borderSubtle)),
                        _buildSummaryRow('Tạm tính', '1.319.000đ'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Phí giao hàng', '0đ'),
                        const SizedBox(height: 12),
                        _buildSummaryRow('Tổng thanh toán', '1.319.000đ', isTotal: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment Method
                  _buildSectionHeader(Icons.payments_outlined, 'PHƯƠNG THỨC THANH TOÁN'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // VietQR Option
                        GestureDetector(
                          onTap: () => setState(() => _selectedPayment = 0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: _selectedPayment == 0 ? const Color(0xFF1B5E20) : AppColors.borderSubtle, width: _selectedPayment == 0 ? 1.5 : 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(_selectedPayment == 0 ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _selectedPayment == 0 ? const Color(0xFF1B5E20) : AppColors.textMuted, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Thanh toán bằng VietQR', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text('Quét mã QR bằng ứng dụng ngân hàng', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Khuyên dùng', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                if (_selectedPayment == 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade100)),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('Giao dịch chuyển khoản cần được đại lý kiểm tra và xác nhận.', style: TextStyle(color: Colors.blue.shade700, fontSize: 11))),
                                      ],
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Debt Option
                        GestureDetector(
                          onTap: () => setState(() => _selectedPayment = 1),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: _selectedPayment == 1 ? const Color(0xFF1B5E20) : AppColors.borderSubtle, width: _selectedPayment == 1 ? 1.5 : 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(_selectedPayment == 1 ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _selectedPayment == 1 ? const Color(0xFF1B5E20) : AppColors.textMuted, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Mua hàng ghi nợ', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Khoản nợ cần được bạn xác nhận sau khi đơn hàng được xử lý', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade200)),
                                  child: Text('Kỳ nhận sau', style: TextStyle(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _isChecked,
                          onChanged: (val) => setState(() => _isChecked = val ?? false),
                          activeColor: const Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tôi đã kiểm tra thông tin đơn hàng và đồng ý tiếp tục.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
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
                  onPressed: _isChecked ? () {
                    if (_selectedPayment == 0) {
                      // Navigate to QR
                      context.push('/payment/qr');
                    } else {
                      // Debt flow...
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20), // Dark green
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Text('Đặt hàng', style: TextStyle(color: _isChecked ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: _isChecked ? Colors.white : Colors.grey.shade500, size: 18),
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
          Text(actionText, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF1B5E20), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildOrderItem(String name, String qtyAndUnit, String price) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(4)),
          child: const Center(child: Icon(Icons.image_outlined, size: 16, color: AppColors.borderStrong)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              Text(qtyAndUnit, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
        Text(price, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
}
