import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../router/app_router.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  const OtpVerifyScreen({super.key, required this.phone});
  @override State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isSubmitting = false;

  @override void dispose() { for (var c in _controllers) c.dispose(); for (var f in _focusNodes) f.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Xác minh OTP')),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nhập mã xác minh', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('Mã OTP đã được gửi đến\n${widget.phone}', style: AppTextStyles.bodySmall),
        const SizedBox(height: 32),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(6, (i) => SizedBox(width: 48, height: 56,
          child: TextFormField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [LengthLimitingTextInputFormatter(1), FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.h3,
            decoration: InputDecoration(counterText: '', contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderSubtle))),
            onChanged: (v) { if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus(); },
          )))),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: _isSubmitting ? null : () async {
          setState(() => _isSubmitting = true);
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) context.go(AppRoutes.home);
        }, child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Xác nhận')),
        const SizedBox(height: 16),
        Center(child: TextButton(onPressed: () {}, child: Text('Gửi lại mã (60s)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)))),
      ])),
    );
  }
}