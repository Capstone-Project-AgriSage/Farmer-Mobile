import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false;
  @override void dispose() { _emailCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Padding(padding: const EdgeInsets.all(24), child: _sent
        ? Column(children: [
            const SizedBox(height: 40),
            const Icon(Icons.mark_email_read_outlined, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text('Đã gửi email đặt lại!', style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Kiểm tra hộp thư ${_emailCtrl.text} và làm theo hướng dẫn.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Về trang đăng nhập')),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Đặt lại mật khẩu', style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text('Nhập email để nhận link đặt lại mật khẩu.', style: AppTextStyles.bodySmall),
            const SizedBox(height: 28),
            TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'email@example.com')),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () { if (_emailCtrl.text.contains('@')) setState(() => _sent = true); }, child: const Text('Gửi link đặt lại')),
          ])),
    );
  }
}