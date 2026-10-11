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

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _tokenCtrl.dispose();
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(_tokenCtrl.text, _passwordCtrl.text);
      messenger.showSnackBar(const SnackBar(
        content: Text('Đặt lại mật khẩu thành công. Vui lòng đăng nhập.'),
      ));
      if (mounted) context.go(AppRoutes.login);
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
        title: const Text('Đặt lại mật khẩu'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.forgotPassword)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mật khẩu mới', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'Dán mã xác nhận đã nhận qua email hoặc SMS, rồi đặt mật khẩu mới.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 28),
              TextFormField(
                key: const Key('reset_token'),
                controller: _tokenCtrl,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Mã xác nhận',
                  hintText: 'Dán mã từ email/SMS',
                ),
                validator: AuthValidators.resetToken,
              ),
              const SizedBox(height: 14),
              PasswordField(
                fieldKey: const Key('reset_password'),
                controller: _passwordCtrl,
                label: 'Mật khẩu mới',
                hint: 'Tối thiểu 8 ký tự',
                textInputAction: TextInputAction.next,
                validator: AuthValidators.newPassword,
              ),
              const SizedBox(height: 14),
              PasswordField(
                fieldKey: const Key('reset_confirm'),
                controller: _confirmCtrl,
                label: 'Xác nhận mật khẩu',
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
                label: 'Đặt lại mật khẩu',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
