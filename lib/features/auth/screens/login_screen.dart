import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../router/app_router.dart';
import '../providers/auth_providers.dart';

/// Login Screen — bám sát UI LoginPage.tsx của Farmer-Web
/// Layout: logo top + form (email/phone, password) + forgot + submit
/// Sau khi đăng nhập thành công, router tự đưa người dùng về trang họ định vào (tham số `from`) hoặc Trang chủ.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).login(
          identifier: _identifierCtrl.text,
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isSubmitting = auth.isLoading;
    final error = auth.hasError ? messageOf(auth.error!) : null;
    // Why the user was sent back here (for example "phiên đăng nhập đã hết hạn").
    final notice = ref.watch(sessionManagerProvider).message;

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
                // Back button
                IconButton(
                  onPressed: () => context.go(AppRoutes.welcome),
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 24),

                // Header — bám sát "Đăng nhập / Chào mừng trở lại"
                Text('Đăng nhập', style: AppTextStyles.h1),
                const SizedBox(height: 6),
                Text(
                  'Chào mừng trở lại với hệ sinh thái AgriSage',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                if (notice != null && error == null) ...[
                  _Banner(text: notice, color: AppColors.statusWarning, background: AppColors.statusWarningSurface),
                  const SizedBox(height: 16),
                ],

                // Email / SĐT field
                const _FieldLabel('EMAIL HOẶC SỐ ĐIỆN THOẠI'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    hintText: 'Nhập email hoặc số điện thoại',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập email hoặc số điện thoại';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                const _FieldLabel('MẬT KHẨU'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => isSubmitting ? null : _handleSubmit(),
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                    return null;
                  },
                ),
                const SizedBox(height: 4),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
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
                ),

                // Error message
                if (error != null) ...[
                  const SizedBox(height: 8),
                  _Banner(text: error, color: AppColors.statusError, background: AppColors.statusErrorSurface),
                ],

                const SizedBox(height: 24),

                // Submit
                ElevatedButton(
                  onPressed: isSubmitting ? null : _handleSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Đăng nhập'),
                ),
                const SizedBox(height: 24),

                // Register link
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

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelSmall,
    );
  }
}
