import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 12),
              
              Text('Hôm nay bạn cần hỗ trợ gì?', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 20),

              // AI Banner
              _buildAiBanner(context),
              const SizedBox(height: 20),

              // Approved Suggestion Card
              _buildSuggestionCard(context),
              const SizedBox(height: 20),

              // Orders Card
              _buildOrdersCard(context),
              const SizedBox(height: 80), // Padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E20), // Dark green
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('TH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TÀI KHOẢN NÔNG DÂN', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text('Xin chào, Trần Văn Hải', style: AppTextStyles.h4.copyWith(color: const Color(0xFF1F2937))),
              ],
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined, size: 28),
              color: AppColors.textPrimary,
              onPressed: () => context.go('${AppRoutes.home}/notifications'),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20), // Dark green
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: const NetworkImage('https://cdn-icons-png.flaticon.com/512/6183/6183181.png'), // Placeholder leaf watermark
          fit: BoxFit.none,
          alignment: Alignment.centerRight,
          colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.05), BlendMode.dstIn),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Hỗ trợ nhận diện AI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),
          const Text('Kiểm tra bệnh trên cây lúa', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Chụp ảnh lá lúa để AGRISAGE hỗ trợ nhận diện bệnh và đề xuất sản phẩm phù hợp.',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.aiScan),
                  icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1B5E20), size: 20),
                  label: const Text('Chụp ảnh', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/ai-scan/history'),
                  icon: const Icon(Icons.history, color: Colors.white, size: 20),
                  label: const Text('Xem lịch sử', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3D15), // Darker green
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_outlined, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text('GỢI Ý ĐÃ ĐƯỢC DUYỆT', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.statusSuccessSurface, borderRadius: BorderRadius.circular(12)),
                child: Text('Đại lý xác nhận', style: AppTextStyles.caption.copyWith(color: AppColors.statusSuccess, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bệnh vừa nhận diện:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              Text('04/12/2024', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Đạo ôn lá (Pyricularia oryzae)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          Text('GỢI Ý SẢN PHẨM THƯƠNG MẠI', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thuốc đặc trị Fuji-One 40WP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('85.000đ', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text('Đã thẩm định bởi Đại lý Cần Thơ', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              GestureDetector(
                onTap: () {},
                child: Text('Đặt mua >', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ĐƠN HÀNG CỦA BẠN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
              GestureDetector(
                onTap: () => context.go(AppRoutes.orderList),
                child: Text('Xem tất cả >', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildOrderStatBox('Chờ xác nhận', '0', false)),
              const SizedBox(width: 8),
              Expanded(child: _buildOrderStatBox('Đang giao', '1', true)),
              const SizedBox(width: 8),
              Expanded(child: _buildOrderStatBox('Hoàn thành', '13', false)),
            ],
          ),
          const SizedBox(height: 16),
          // Order Detail Snippet
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('#DH-8842', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text('Đang vận chuyển', style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Text('4.850.000đ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hôm nay, 02/12/2024', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    Text('5 bao Phân NPK', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text('Tài xế đang giao tới ấp Thới Phước', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text('Chi tiết', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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

  Widget _buildOrderStatBox(String title, String count, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? Colors.orange.shade200 : AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(title, style: AppTextStyles.caption.copyWith(color: isActive ? Colors.orange.shade800 : AppColors.textSecondary, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500)),
          const SizedBox(height: 4),
          Text(count, style: AppTextStyles.h4.copyWith(color: isActive ? Colors.orange.shade800 : AppColors.textPrimary)),
        ],
      ),
    );
  }
}
