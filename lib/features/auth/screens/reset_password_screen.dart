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

/// Bước 1 xác nhận mã, bước 2 mới đặt mật khẩu.
enum _ResetStep { code, password }

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// [initialIdentifier]: email/số điện thoại vừa nhập ở màn "Quên mật khẩu",
  /// để mã 6 số trong SMS đi kèm đúng số điện thoại.
  const ResetPasswordScreen({super.key, this.initialIdentifier});

  final String? initialIdentifier;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _identifierCtrl =
      TextEditingController(text: widget.initialIdentifier ?? '');
  final _tokenCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  _ResetStep _step = _ResetStep.code;
  bool _isSubmitting = false;
  String _error = '';

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _backToCode(String message) {
    _passwordCtrl.clear();
    _confirmCtrl.clear();
    setState(() {
      _step = _ResetStep.code;
      _error = message;
    });
  }

  /// Bước 1. Mã 6 số của SMS được máy chủ kiểm tra ngay (không bị dùng mất);
  /// mã dài trong email chỉ kiểm được khi lưu mật khẩu nên đi thẳng sang bước 2.
  Future<void> _confirmCode() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    final code = _tokenCtrl.text.trim();
    if (!AuthValidators.isOtp(code)) {
      setState(() {
        _step = _ResetStep.password;
        _error = '';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyResetCode(_identifierCtrl.text, code);
      if (mounted) setState(() => _step = _ResetStep.password);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(authRepositoryProvider);
      final code = _tokenCtrl.text.trim();
      if (AuthValidators.isOtp(code)) {
        // Mã 6 số của SMS chỉ có giá trị cùng số điện thoại.
        await repo.resetPasswordWithCode(
            _identifierCtrl.text, code, _passwordCtrl.text);
      } else {
        await repo.resetPassword(code, _passwordCtrl.text);
      }
      messenger.showSnackBar(const SnackBar(
        content: Text('Đặt lại mật khẩu thành công. Vui lòng đăng nhập.'),
      ));
      if (mounted) context.go(AppRoutes.login);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 422: mã đã bị dùng hết lượt hoặc hết hạn giữa hai bước, quay lại bước 1
      // thay vì để người dùng kẹt ở form mật khẩu.
      if (e.statusCode == 422) {
        _backToCode(e.message);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _back() {
    if (_step == _ResetStep.password && !_isSubmitting) {
      _backToCode('');
    } else {
      context.go(AppRoutes.forgotPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inCodeStep = _step == _ResetStep.code;
    final isOtp = AuthValidators.isOtp(_tokenCtrl.text.trim());
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Đặt lại mật khẩu'),
        leading: BackButton(onPressed: _back),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inCodeStep ? 'Xác nhận mã' : 'Mật khẩu mới',
                  style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                inCodeStep
                    ? 'Bước 1/2: nhập mã xác nhận, 6 chữ số trong tin nhắn '
                        'SMS (kèm số điện thoại nhận mã), hoặc dán mã dài '
                        'trong email.'
                    : isOtp
                        ? 'Bước 2/2: mã đã được xác nhận. Đặt mật khẩu mới '
                            'cho tài khoản.'
                        : 'Bước 2/2: đặt mật khẩu mới. Mã trong email được '
                            'kiểm tra khi lưu.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 28),
              if (inCodeStep) ...[
                TextFormField(
                  key: const Key('reset_identifier'),
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại hoặc email',
                    hintText: 'Nơi bạn nhận mã',
                  ),
                  // Chỉ bắt buộc khi mã là 6 số của SMS; mã email là token dài.
                  validator: (v) =>
                      AuthValidators.isOtp(_tokenCtrl.text.trim())
                          ? AuthValidators.phoneForSmsCode(v)
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('reset_token'),
                  controller: _tokenCtrl,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _confirmCode(),
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: 'Mã xác nhận',
                    hintText: '6 chữ số từ SMS, hoặc dán mã từ email',
                  ),
                  validator: AuthValidators.resetCode,
                ),
              ] else ...[
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
                  validator: AuthValidators.confirmPassword(
                      () => _passwordCtrl.text),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                AuthBanner(_error),
              ],
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: inCodeStep ? 'Xác nhận mã' : 'Đặt lại mật khẩu',
                isLoading: _isSubmitting,
                onPressed: inCodeStep ? _confirmCode : _submit,
              ),
              if (!inCodeStep) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    key: const Key('reset_back_to_code'),
                    onPressed: _isSubmitting ? null : () => _backToCode(''),
                    child: const Text('Nhập lại mã'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
