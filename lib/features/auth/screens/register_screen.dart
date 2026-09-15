import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _isSubmitting = false;

  @override void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Đăng ký tài khoản'), leading: BackButton(onPressed: () => context.go(AppRoutes.welcome))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tạo tài khoản nông dân', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text('Điền đầy đủ thông tin để tham gia AgriSage', style: AppTextStyles.bodySmall),
          const SizedBox(height: 28),
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Họ và tên', hintText: 'Nguyễn Văn A'), validator: (v) => v!.trim().isEmpty ? 'Vui lòng nhập họ tên' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại', hintText: '0912 345 678'), validator: (v) => v!.length < 10 ? 'SĐT không hợp lệ' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (tuỳ chọn)', hintText: 'example@email.com')),
          const SizedBox(height: 14),
          TextFormField(controller: _passwordCtrl, obscureText: !_showPassword,
            decoration: InputDecoration(labelText: 'Mật khẩu', hintText: 'Tối thiểu 6 ký tự',
              suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textMuted), onPressed: () => setState(() => _showPassword = !_showPassword))),
            validator: (v) => v!.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () async {
              if (!_formKey.currentState!.validate()) return;
              setState(() => _isSubmitting = true);
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) context.go('${AppRoutes.otpVerify}?phone=${_phoneCtrl.text}');
            },
            child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Đăng ký')),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Đã có tài khoản? ', style: AppTextStyles.bodySmall),
            GestureDetector(onTap: () => context.go(AppRoutes.login), child: Text('Đăng nhập', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600))),
          ]),
        ])),
      ),
    );
  }
}