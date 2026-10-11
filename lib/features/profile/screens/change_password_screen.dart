import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_validators.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/widgets/auth_widgets.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    // Lấy trước vì màn này sẽ bị đóng khi phiên bị xoá.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(authControllerProvider)
          .changePassword(_oldCtrl.text, _newCtrl.text);
      // Backend huỷ mọi phiên khi đổi mật khẩu → router guard đưa về Welcome.
      messenger.showSnackBar(const SnackBar(
        content: Text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset,
                    size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Mật khẩu mới phải khác mật khẩu hiện tại. '
                'Sau khi đổi, bạn sẽ được đăng xuất khỏi mọi thiết bị.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              PasswordField(
                fieldKey: const Key('cp_current'),
                controller: _oldCtrl,
                label: 'Mật khẩu hiện tại',
                textInputAction: TextInputAction.next,
                validator: AuthValidators.existingPassword,
              ),
              const SizedBox(height: 16),
              PasswordField(
                fieldKey: const Key('cp_new'),
                controller: _newCtrl,
                label: 'Mật khẩu mới',
                hint: 'Tối thiểu 8 ký tự',
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final base = AuthValidators.newPassword(v);
                  if (base != null) return base;
                  return v == _oldCtrl.text
                      ? 'Mật khẩu mới phải khác mật khẩu hiện tại'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                fieldKey: const Key('cp_confirm'),
                controller: _confirmCtrl,
                label: 'Xác nhận mật khẩu mới',
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                validator:
                    AuthValidators.confirmPassword(() => _newCtrl.text),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                AuthBanner(_error),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: AuthSubmitButton(
                  label: 'Cập nhật mật khẩu',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
