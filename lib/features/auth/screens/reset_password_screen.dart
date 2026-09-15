import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  @override void dispose() { _passwordCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
      body: Padding(padding: const EdgeInsets.all(24), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mật khẩu mới', style: AppTextStyles.h2),
        const SizedBox(height: 28),
        TextFormField(controller: _passwordCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Mật khẩu mới (tối thiểu 6 ký tự)'), validator: (v) => v!.length < 6 ? 'Quá ngắn' : null),
        const SizedBox(height: 14),
        TextFormField(controller: _confirmCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Xác nhận mật khẩu'), validator: (v) => v != _passwordCtrl.text ? 'Không khớp' : null),
        const SizedBox(height: 28),
        ElevatedButton(onPressed: () { if (_formKey.currentState!.validate()) context.go(AppRoutes.login); }, child: const Text('Đặt lại mật khẩu')),
      ]))),
    );
  }
}