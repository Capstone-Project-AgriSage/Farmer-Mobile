import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/auth_repository.dart';

/// Đổi mật khẩu. Sai mật khẩu hiện tại chỉ báo lỗi ngay trên form, không đăng xuất.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _currentError;
  String? _formError;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _currentError = null;
      _formError = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
      if (context.canPop()) context.pop();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        // A 401 here is "the current password is wrong": say it under that field. The session is untouched.
        if (error.kind == AppErrorKind.unauthorized) {
          _currentError = error.message;
        } else {
          _formError = error.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, {String? error}) => InputDecoration(
        labelText: label,
        errorText: error,
        suffixIcon: IconButton(
          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppColors.textMuted),
          onPressed: () => setState(() => _show = !_show),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _current,
              obscureText: !_show,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Mật khẩu hiện tại', error: _currentError),
              validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu hiện tại' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _new,
              obscureText: !_show,
              textInputAction: TextInputAction.next,
              decoration: _decoration('Mật khẩu mới'),
              validator: (v) {
                final basic = validateNewPassword(v);
                if (basic != null) return basic;
                if (v == _current.text) return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: !_show,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _busy ? null : _submit(),
              decoration: _decoration('Nhập lại mật khẩu mới'),
              validator: (v) => v != _new.text ? 'Hai mật khẩu chưa khớp' : null,
            ),
            const SizedBox(height: 8),
            Text('Mật khẩu từ 8 đến 128 ký tự.', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            if (_formError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.statusErrorSurface, borderRadius: BorderRadius.circular(8)),
                child: Text(_formError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }
}
