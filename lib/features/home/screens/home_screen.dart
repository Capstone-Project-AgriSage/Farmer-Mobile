import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../router/app_router.dart';
import '../../payment/widgets/pending_payment_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionUserProvider)?.fullName ?? '';
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context, name),
              const SizedBox(height: 12),
              
              Text('Hôm nay bạn cần hỗ trợ gì?', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 20),

              // An unfinished payOS payment, if any
              const PendingPaymentBanner(),

              // AI Banner
              _buildAiBanner(context),
              const SizedBox(height: 20),

              // Shortcuts to the parts of the app that have real data
              _buildShortcuts(context),
              const SizedBox(height: 20),

              // Articles have no backend yet
              _buildNewsRow(context),
              const SizedBox(height: 80), // Padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E20), // Dark green
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(initialsOf(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TÀI KHOẢN NÔNG DÂN', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('Xin chào, $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h4.copyWith(color: const Color(0xFF1F2937))),
                ],
              ),
            ),
          ],
        ),
        ),
        // No unread dot: notifications have no backend yet, so there is never anything to flag.
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, size: 28),
          color: AppColors.textPrimary,
          onPressed: () => context.go('${AppRoutes.home}/notifications'),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('AI hỗ trợ · Chuyên viên xác nhận', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),
          const Text('Kiểm tra bệnh trên cây lúa', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Chụp ảnh lá lúa gửi cho chuyên viên đại lý. Sau khi xác nhận bệnh, Bác nhận cách xử lý và sản phẩm phù hợp.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.5),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcuts(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildShortcut(Icons.storefront_outlined, 'Mua sắm', () => context.go(AppRoutes.products))),
        const SizedBox(width: 12),
        Expanded(child: _buildShortcut(Icons.receipt_long_outlined, 'Đơn hàng', () => context.push(AppRoutes.orderList))),
        const SizedBox(width: 12),
        Expanded(child: _buildShortcut(Icons.account_balance_wallet_outlined, 'Công nợ', () => context.go(AppRoutes.debt))),
      ],
    );
  }

  Widget _buildShortcut(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsRow(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('${AppRoutes.home}/articles'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.article_outlined, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(child: Text('Tin tức & kiến thức', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.statusWarningSurface, borderRadius: BorderRadius.circular(10)),
                child: Text('Sắp ra mắt', style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
