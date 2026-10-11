import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../router/app_router.dart';
import '../data/auth_validators.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    try {
      await ref.read(authControllerProvider).register(
            fullName: _nameCtrl.text,
            // Gửi số đã chuẩn hoá để khớp lúc đăng nhập.
            phoneNumber: AuthValidators.normalizePhone(_phoneCtrl.text)!,
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      // Thành công: đã đăng nhập, router guard chuyển sang Home.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Đăng ký tài khoản'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.welcome)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tạo tài khoản nông dân', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text('Điền đầy đủ thông tin để tham gia AgriSage',
                  style: AppTextStyles.bodySmall),
              const SizedBox(height: 28),
              TextFormField(
                key: const Key('register_name'),
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Họ và tên', hintText: 'Nguyễn Văn A'),
                validator: AuthValidators.fullName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register_phone'),
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Số điện thoại', hintText: '0912 345 678'),
                validator: AuthValidators.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register_email'),
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Email (tuỳ chọn)',
                    hintText: 'example@email.com'),
                validator: AuthValidators.optionalEmail,
              ),
              const SizedBox(height: 14),
              PasswordField(
                fieldKey: const Key('register_password'),
                controller: _passwordCtrl,
                label: 'Mật khẩu',
                hint: 'Tối thiểu 8 ký tự',
                textInputAction: TextInputAction.next,
                validator: AuthValidators.newPassword,
              ),
              const SizedBox(height: 14),
              PasswordField(
                fieldKey: const Key('register_confirm'),
                controller: _confirmCtrl,
                label: 'Nhập lại mật khẩu',
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                validator:
                    AuthValidators.confirmPassword(() => _passwordCtrl.text),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                AuthBanner(_error),
              ],
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Đăng ký',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Đã có tài khoản? ', style: AppTextStyles.bodySmall),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: Text(
                      'Đăng nhập',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
