import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _orderUpdates = true;
  bool _debtReminders = true;
  bool _promotions = false;
  bool _systemAlerts = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Cài đặt thông báo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
              child: Text(
                'QUẢN LÝ THÔNG BÁO',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Cập nhật đơn hàng',
                    subtitle: 'Thông báo khi đơn hàng được xác nhận, đang giao...',
                    icon: Icons.local_shipping_outlined,
                    value: _orderUpdates,
                    onChanged: (val) => setState(() => _orderUpdates = val),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.borderSubtle),
                  _buildSwitchTile(
                    title: 'Nhắc nhở công nợ',
                    subtitle: 'Nhận thông báo khi có khoản nợ sắp đến hạn.',
                    icon: Icons.account_balance_wallet_outlined,
                    value: _debtReminders,
                    onChanged: (val) => setState(() => _debtReminders = val),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.borderSubtle),
                  _buildSwitchTile(
                    title: 'Khuyến mãi & Tin tức',
                    subtitle: 'Thông tin giảm giá, mẹo nông nghiệp mới nhất.',
                    icon: Icons.campaign_outlined,
                    value: _promotions,
                    onChanged: (val) => setState(() => _promotions = val),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.borderSubtle),
                  _buildSwitchTile(
                    title: 'Cập nhật hệ thống',
                    subtitle: 'Thông báo về tính năng mới, bảo trì ứng dụng.',
                    icon: Icons.system_update_outlined,
                    value: _systemAlerts,
                    onChanged: (val) => setState(() => _systemAlerts = val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
      title: Text(title, style: AppTextStyles.labelLarge),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, height: 1.3)),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        activeTrackColor: AppColors.primaryLight,
      ),
    );
  }
}
