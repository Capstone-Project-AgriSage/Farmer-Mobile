import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../router/app_router.dart';
import '../data/auth_repository.dart';
import '../data/auth_validators.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_widgets.dart';

enum VerifyChannel { phone, email }

/// Xác minh số điện thoại (OTP 6 số qua SMS) hoặc email (mã dán từ thư).
/// Cần đăng nhập. Vào màn là tự gửi mã; backend giới hạn gửi lại 60 giây.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.destination,
    this.channel = VerifyChannel.phone,
    @visibleForTesting this.resendSeconds = 60,
  });

  /// Số điện thoại hoặc email đang xác minh (chỉ để hiển thị).
  final String destination;
  final VerifyChannel channel;
  final int resendSeconds;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  Timer? _timer;
  int _cooldown = 0;
  bool _isSending = false;
  bool _isSubmitting = false;
  bool _sentOk = false;
  String _error = '';

  bool get _isPhone => widget.channel == VerifyChannel.phone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = widget.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    if (_isSending || _cooldown > 0) return;
    setState(() {
      _isSending = true;
      _error = '';
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await (_isPhone
          ? repo.requestPhoneVerification()
          : repo.requestEmailVerification());
      if (!mounted) return;
      _sentOk = true;
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirm() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = '';
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(authRepositoryProvider);
      await (_isPhone
          ? repo.confirmPhone(_codeCtrl.text)
          : repo.confirmEmail(_codeCtrl.text));
      // Tải lại để cờ "đã xác minh" cập nhật trên toàn app.
      await ref.read(authControllerProvider).refreshUser();
      messenger.showSnackBar(SnackBar(
        content: Text(_isPhone
            ? 'Đã xác minh số điện thoại.'
            : 'Đã xác minh email.'),
      ));
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(AppRoutes.profile);
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
        title: Text(_isPhone ? 'Xác minh số điện thoại' : 'Xác minh email'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isPhone ? 'Nhập mã OTP' : 'Nhập mã xác nhận',
                  style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                _isPhone
                    ? 'Mã OTP gồm 6 số được gửi qua SMS đến\n${widget.destination}'
                    : 'Mã xác nhận được gửi đến email\n${widget.destination}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 32),
              TextFormField(
                key: const Key('verify_code'),
                controller: _codeCtrl,
                autofocus: true,
                textAlign: _isPhone ? TextAlign.center : TextAlign.start,
                keyboardType:
                    _isPhone ? TextInputType.number : TextInputType.text,
                autofillHints:
                    _isPhone ? const [AutofillHints.oneTimeCode] : null,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirm(),
                inputFormatters: _isPhone
                    // Lọc chữ số TRƯỚC rồi mới cắt 6, để dán "123 456" không mất số.
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ]
                    : null,
                style: _isPhone
                    ? AppTextStyles.h2.copyWith(letterSpacing: 12)
                    : null,
                decoration: InputDecoration(
                  hintText: _isPhone ? '• • • • • •' : 'Dán mã từ email',
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (_isPhone) {
                    return AuthValidators.isOtp(s)
                        ? null
                        : 'Vui lòng nhập đủ 6 số';
                  }
                  return AuthValidators.resetToken(s);
                },
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                AuthBanner(_error),
              ] else if (_sentOk) ...[
                const SizedBox(height: 16),
                const AuthBanner('Đã gửi mã. Vui lòng kiểm tra tin nhắn.',
                    isError: false),
              ],
              const SizedBox(height: 28),
              AuthSubmitButton(
                label: 'Xác nhận',
                isLoading: _isSubmitting,
                onPressed: _confirm,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  key: const Key('verify_resend'),
                  onPressed: (_cooldown > 0 || _isSending) ? null : _sendCode,
                  child: Text(
                    _isSending
                        ? 'Đang gửi...'
                        : _cooldown > 0
                            ? 'Gửi lại mã (${_cooldown}s)'
                            : 'Gửi lại mã',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
