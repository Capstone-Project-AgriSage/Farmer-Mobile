import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final List<String> _tabs = ['Tất cả', 'Chờ xác nhận', 'Đang xử lý', 'Đang giao'];
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Đơn hàng của tôi'),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textPrimary), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (Pill style)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isActive = _selectedTab == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF1B5E20) : Colors.white,
                        border: Border.all(color: isActive ? const Color(0xFF1B5E20) : AppColors.borderSubtle),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _tabs[index],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isActive ? Colors.white : AppColors.textSecondary,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Order List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildOrderCard(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, int index) {
    // Mock data
    final String orderId = index == 0 ? 'DH-2024-1082' : (index == 1 ? 'DH-2024-1080' : 'DH-2024-1078');
    final String date = index == 0 ? 'Hôm nay, 09:45' : (index == 1 ? '04/09/2026' : '02/09/2026');
    final String price = index == 0 ? '1.319.000đ' : (index == 1 ? '460.000đ' : '650.000đ');
    final String statusText = index == 0 ? 'Chờ xác nhận' : (index == 1 ? 'Đang xử lý' : 'Đang giao');
    final Color statusColor = index == 0 ? Colors.orange.shade800 : (index == 1 ? Colors.blue.shade700 : const Color(0xFF1B5E20));
    final Color statusBg = index == 0 ? Colors.orange.shade50 : (index == 1 ? Colors.blue.shade50 : const Color(0xFFF0FDF4));
    final String subStatus = index == 0 ? 'Ghi nợ' : (index == 1 ? 'Tiền mặt' : 'Chuyển khoản');
    final String actionText = index == 0 ? 'Xác nhận công nợ' : (index == 1 ? 'Xem chi tiết' : 'Theo dõi giao hàng');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, size: 20, color: const Color(0xFF1B5E20)),
                        const SizedBox(width: 8),
                        Text(orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(statusText, style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(subStatus, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: AppColors.borderSubtle),
          
          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildItemRow('Phân NPK Đầu Trâu 20-20-15', 'x1'),
                if (index < 2) const SizedBox(height: 8),
                if (index < 2) _buildItemRow('Thuốc Trừ Bệnh Beam 75WP', 'x2'),
                if (index == 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.add_circle_outline, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('1 sản phẩm khác (Lúa Giống ST25)', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderSubtle),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thành tiền', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    Text(price, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
                  ],
                ),
                index == 1 
                  ? OutlinedButton(
                      onPressed: () {}, 
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.borderStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
                    )
                  : ElevatedButton(
                      onPressed: () {
                        if (index == 0) {
                          context.push(AppRoutes.debtConfirm.replaceFirst(':id', 'DH-2024-1082'));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String name, String qty) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(name, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF4B5563)))),
        Text(qty, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
