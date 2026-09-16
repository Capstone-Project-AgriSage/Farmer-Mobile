import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/order.dart';
import '../../../data/mock/mock_orders.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    // Find order by ID or use first mock
    final order = mockOrders.firstWhere((o) => o.id == orderId, orElse: () => mockOrders.first);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Order Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Mã đơn: ${order.orderCode}', style: AppTextStyles.labelLarge),
                      Text(_formatDate(order.createdAt), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 12, color: _getStatusColor(order.status)),
                      const SizedBox(width: 8),
                      Text(order.statusLabel, style: AppTextStyles.bodyMedium.copyWith(color: _getStatusColor(order.status), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Delivery Address ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Địa chỉ nhận hàng', style: AppTextStyles.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Trần Văn Hải | 0912345678', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    order.deliveryAddress ?? 'Không có địa chỉ',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Order Items ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Danh sách sản phẩm', style: AppTextStyles.labelLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('${item.unit} x ${item.quantity}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('${_formatPrice(item.unitPrice)}đ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Summary ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Tạm tính', order.totalAmount),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Phí giao hàng', 30000), // Mock fee
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderSubtle),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Thành tiền', style: AppTextStyles.labelLarge),
                      Text(
                        '${_formatPrice(order.totalAmount + 30000)}đ',
                        style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.payment, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('Thanh toán: ', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      Text(
                        order.paymentMethod == PaymentMethod.qr ? 'Chuyển khoản QR' : 'Ghi nợ đại lý',
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Actions ───────────────────────────────────────────────
            if (order.status == OrderStatus.pending)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Yêu cầu huỷ đơn đã được gửi')),
                    );
                    context.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusError,
                    side: const BorderSide(color: AppColors.statusError),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Huỷ đơn hàng'),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text('${_formatPrice(amount)}đ', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return const Color(0xFFF57F17);
      case OrderStatus.confirmed: return const Color(0xFF1976D2);
      case OrderStatus.delivering: return const Color(0xFF0288D1);
      case OrderStatus.delivered: return AppColors.statusSuccess;
      case OrderStatus.cancelled: return AppColors.statusError;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.');
  }
}
