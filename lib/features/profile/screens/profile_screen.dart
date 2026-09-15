import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E20), // Dark green
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 4),
                    ),
                    alignment: Alignment.center,
                    child: const Text('TH', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tài khoản nông dân', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text('Trần Văn Hải', style: AppTextStyles.h3.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('0912 345 678', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withOpacity(0.9))),
                    ],
                  ),
                ],
              ),
            ),
            
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSection(
                    'TÀI KHOẢN',
                    [
                      _buildTile(Icons.person_outline, 'Thông tin cá nhân', () => context.push('/profile/edit')),
                      _buildTile(Icons.lock_outline, 'Đổi mật khẩu', () => context.push('/profile/password')),
                      _buildTile(Icons.notifications_outlined, 'Cài đặt thông báo', () => context.push('/profile/notifications')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'HỖ TRỢ',
                    [
                      _buildTile(Icons.help_outline, 'Trợ giúp & Hỗ trợ', () => context.push('/profile/help')),
                      _buildTile(Icons.description_outlined, 'Điều khoản sử dụng', () => context.push('/profile/terms')),
                      _buildTile(Icons.privacy_tip_outlined, 'Chính sách bảo mật', () => context.push('/profile/privacy')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.welcome),
                      icon: const Icon(Icons.logout, color: AppColors.statusError),
                      label: Text('Đăng xuất', style: AppTextStyles.labelLarge.copyWith(color: AppColors.statusError)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.statusError.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              if (index < children.length - 1) {
                return Column(
                  children: [
                    child,
                    const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.borderSubtle),
                  ],
                );
              }
              return child;
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
