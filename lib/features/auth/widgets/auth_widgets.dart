import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Khung báo lỗi/thông báo dùng chung cho các form xác thực.
class AuthBanner extends StatelessWidget {
  const AuthBanner(this.message, {super.key, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.statusError : AppColors.statusSuccess;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.statusErrorSurface
            : AppColors.statusSuccessSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút chính có trạng thái đang xử lý (khoá bấm đúp).
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

/// Ô mật khẩu có nút ẩn/hiện.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.validator,
    this.label,
    this.hint,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? label;
  final String? hint;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final Iterable<String>? autofillHints;
  final Key? fieldKey;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: !_show,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: IconButton(
          tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
          icon: Icon(
            _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _show = !_show),
        ),
      ),
      validator: widget.validator,
    );
  }
}
