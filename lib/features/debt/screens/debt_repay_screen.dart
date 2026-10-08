import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../router/app_router.dart';
import '../../payment/providers/payment_providers.dart';
import '../data/debt_models.dart';
import '../providers/debt_providers.dart';

/// Trả nợ qua payOS: nhập số tiền (nguyên đồng, từ 1 đến cả dư nợ), xem khoản nào sẽ được trừ (hạn cũ nhất trước),
/// rồi sang cổng payOS. Cửa hàng ghi nhận khi payOS báo đã nhận tiền.
class DebtRepayScreen extends ConsumerStatefulWidget {
  const DebtRepayScreen({super.key});

  @override
  ConsumerState<DebtRepayScreen> createState() => _DebtRepayScreenState();
}

class _DebtRepayScreenState extends ConsumerState<DebtRepayScreen> {
  static const _previewDelay = Duration(milliseconds: 400);

  final _amount = TextEditingController();
  Timer? _debounce;
  int? _previewFor;
  bool _seeded = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    super.dispose();
  }

  void _onChanged(String text, int max) {
    _debounce?.cancel();
    final read = readRepayAmount(text, max);
    setState(() {
      _error = null;
      if (!read.isValid) _previewFor = null;
    });
    if (read.isValid) {
      // Ask which debts this amount would settle only after a short pause in typing.
      _debounce = Timer(_previewDelay, () {
        if (mounted) setState(() => _previewFor = read.value);
      });
    }
  }

  Future<void> _pay(int amount) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pending = await ref.read(paymentLauncherProvider).startDebtRepayment(amount);
      if (mounted) await context.push(AppRoutes.payosCheckout, extra: pending);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(debtSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Trả nợ')),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(debtSummaryProvider)),
        data: _buildForm,
      ),
    );
  }

  Widget _buildForm(DebtSummary summary) {
    final max = summary.maxRepayable;
    if (!summary.hasDebtBook || max <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text('Bác không còn khoản nợ nào cần trả', style: AppTextStyles.h4, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go(AppRoutes.debt), child: const Text('Về Sổ nợ')),
            ],
          ),
        ),
      );
    }

    if (!_seeded) {
      _seeded = true;
      _amount.text = '$max';
      _previewFor = max;
    }

    final read = readRepayAmount(_amount.text, max);
    final preview = _previewFor == null ? null : ref.watch(allocationPreviewProvider(_previewFor!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng dư nợ hiện tại', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
              Text(formatVnd(summary.balance), style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Số tiền muốn trả (₫)', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () {
                _amount.text = '$max';
                _onChanged(_amount.text, max);
              },
              child: const Text('Trả hết'),
            ),
          ],
        ),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (text) => _onChanged(text, max),
          decoration: InputDecoration(
            hintText: 'Nhập số tiền',
            errorText: (_amount.text.isNotEmpty && !read.isValid) ? read.error : null,
          ),
        ),
        const SizedBox(height: 16),
        if (preview != null)
          preview.when(
            loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(), // the preview is a courtesy; paying does not depend on it
            data: (p) => p.allocations.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khoản trả này sẽ trừ vào các khoản nợ theo hạn trả cũ nhất trước:',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        for (final a in p.allocations)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('${a.entryNumber} · hạn ${formatVnDate(a.dueDate)}', style: AppTextStyles.caption),
                                ),
                                Text('− ${formatVnd(a.allocatedAmount)}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.qr_code_2, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bác sẽ sang cổng payOS để quét mã VietQR. Muốn trả tiền mặt, Bác đến quầy của cửa hàng để nhân viên ghi nhận.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: (read.isValid && !_busy) ? () => _pay(read.value!) : null,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Thanh toán qua payOS'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
