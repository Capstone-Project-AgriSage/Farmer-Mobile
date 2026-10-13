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

/// Login Screen — bám sát UI LoginPage.tsx của Farmer-Web
/// Layout: logo top + form (email/phone, password) + forgot + submit
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _rememberMe = true;
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    try {
      await ref.read(authControllerProvider).login(
            _identifierCtrl.text,
            _passwordCtrl.text,
            rememberMe: _rememberMe,
          );
      // Thành công: router guard tự chuyển sang Home khi phiên được thiết lập.
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => context.go(AppRoutes.welcome),
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 24),
                Text('Đăng nhập', style: AppTextStyles.h1),
                const SizedBox(height: 6),
                Text(
                  'Chào mừng trở lại với hệ sinh thái AgriSage',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                Text('EMAIL HOẶC SỐ ĐIỆN THOẠI',
                    style: AppTextStyles.labelSmall),
                const SizedBox(height: 6),
                TextFormField(
                  key: const Key('login_identifier'),
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    hintText: 'Nhập email hoặc số điện thoại',
                  ),
                  validator: AuthValidators.identifier,
                ),
                const SizedBox(height: 16),
                Text('MẬT KHẨU', style: AppTextStyles.labelSmall),
                const SizedBox(height: 6),
                PasswordField(
                  fieldKey: const Key('login_password'),
                  controller: _passwordCtrl,
                  hint: 'Nhập mật khẩu',
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: _handleSubmit,
                  validator: AuthValidators.existingPassword,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              key: const Key('login_remember'),
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? true),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text('Ghi nhớ đăng nhập',
                              style: AppTextStyles.bodySmall)),
                        ],
                      ),
                    )),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.forgotPassword),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        'Quên mật khẩu?',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AuthBanner(_error),
                ],
                const SizedBox(height: 24),
                AuthSubmitButton(
                  label: 'Đăng nhập',
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Chưa có tài khoản? ', style: AppTextStyles.bodySmall),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.register),
                      child: Text(
                        'Đăng ký ngay',
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
      ),
    );
  }
}
