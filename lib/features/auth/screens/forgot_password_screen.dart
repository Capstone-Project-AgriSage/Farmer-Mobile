import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../router/app_router.dart';
import '../data/auth_repository.dart';
import '../data/auth_validators.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  bool _sent = false;
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .forgotPassword(_identifierCtrl.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Mang email/số điện thoại đã nhập sang màn đặt lại, để mã 6 số trong SMS
  /// đi kèm đúng số điện thoại.
  void _goToReset() {
    final identifier = _identifierCtrl.text.trim();
    context.go(AppRoutes.resetPassword,
        extra: identifier.isEmpty ? null : identifier);
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = _identifierCtrl.text.contains('@');
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Quên mật khẩu'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent
            ? Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.mark_email_read_outlined,
                      size: 80, color: AppColors.primary),
                  const SizedBox(height: 24),
                  Text('Đã gửi mã xác nhận',
                      style: AppTextStyles.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    // Backend luôn trả 202, không tiết lộ tài khoản có tồn tại.
                    'Nếu tài khoản tồn tại, mã xác nhận đã được gửi tới '
                    '${_identifierCtrl.text.trim()} '
                    '(${isEmail ? 'email' : 'tin nhắn SMS gồm 6 chữ số'}). '
                    'Mã có hiệu lực trong 10 phút.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    key: const Key('forgot_enter_code'),
                    onPressed: _goToReset,
                    child: const Text('Nhập mã xác nhận'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _sent = false),
                    child: const Text('Gửi lại'),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đặt lại mật khẩu', style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      'Nhập email hoặc số điện thoại đã đăng ký để nhận mã xác nhận.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('forgot_identifier'),
                      controller: _identifierCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Email hoặc số điện thoại',
                      ),
                      validator: AuthValidators.identifier,
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      AuthBanner(_error),
                    ],
                    const SizedBox(height: 24),
                    AuthSubmitButton(
                      label: 'Gửi mã xác nhận',
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _goToReset,
                        child: const Text('Tôi đã có mã xác nhận'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
