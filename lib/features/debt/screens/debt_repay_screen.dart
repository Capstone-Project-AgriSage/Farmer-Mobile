import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/debt_models.dart';
import '../providers/debt_providers.dart';

/// Trả nợ qua payOS: nhập số tiền, xem tiền sẽ trừ vào khoản nào, rồi sang
/// màn quét QR. Backend luôn trừ vào khoản đến hạn sớm nhất trước (không chọn
/// được từng khoản) nên màn này cho xem trước thay vì cho chọn.
class DebtRepayScreen extends ConsumerStatefulWidget {
  const DebtRepayScreen({
    super.key,
    this.initialAmount,
    @visibleForTesting this.previewDelay = const Duration(milliseconds: 500),
  });

  /// Số tiền gợi ý ban đầu (ví dụ số còn nợ của khoản đang xem).
  final int? initialAmount;
  final Duration previewDelay;

  @override
  ConsumerState<DebtRepayScreen> createState() => _DebtRepayScreenState();
}

class _DebtRepayScreenState extends ConsumerState<DebtRepayScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;
  int? _previewAmount;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount;
    _controller = TextEditingController(
        text: initial != null && initial > 0 ? '$initial' : '');
    _previewAmount = initial != null && initial > 0 ? initial : null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_controller.text);

  void _onChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(widget.previewDelay, () {
      if (!mounted) return;
      final a = _amount;
      setState(() => _previewAmount = a != null && a > 0 ? a : null);
    });
  }

  void _setAmount(int value) {
    _debounce?.cancel();
    _controller.text = '$value';
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() => _previewAmount = value);
  }

  String? _validate(int? amount, double balance) {
    if (_controller.text.isEmpty) return null;
    if (amount == null || amount <= 0) return 'Vui lòng nhập số tiền hợp lệ';
    if (amount > balance.floor()) {
      return 'Số tiền vượt quá tổng nợ (${formatVnd(balance)})';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(debtAccountProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Trả nợ')),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryWidget(
            error: e, onRetry: () => ref.invalidate(debtAccountProvider)),
        data: (a) {
          if (a == null || !a.hasDebt) {
            return const EmptyDataWidget(
              message: 'Bạn không còn khoản nợ nào cần thanh toán.',
              fallbackIcon: Icons.check_circle_outline,
            );
          }
          return _form(a);
        },
      ),
    );
  }

  Widget _form(DebtAccount account) {
    final balance = account.currentBalance;
    final amount = _amount;
    final error = _validate(amount, balance);
    final valid = amount != null && amount > 0 && error == null;
    final fullAmount = balance.floor();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SectionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'TỔNG NỢ HIỆN TẠI',
                child: Column(
                  children: [
                    InfoRow('Còn phải trả', formatVnd(balance),
                        bold: true, valueKey: const Key('repay_balance')),
                    if (account.hasOverdue)
                      InfoRow('Trong đó quá hạn', formatVnd(account.overdueAmount),
                          valueColor: AppColors.debtOverdue),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Số tiền muốn trả',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('repay_amount'),
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      onChanged: _onChanged,
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: 'đ',
                        errorMaxLines: 2,
                        errorText: error,
                      ),
                    ),
                    if (valid)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(formatVnd(amount),
                            key: const Key('repay_amount_text'),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          key: const Key('repay_full'),
                          label: const Text('Trả hết nợ'),
                          onPressed: () => _setAmount(fullAmount),
                        ),
                        if (account.hasOverdue && account.overdueAmount.floor() > 0)
                          ActionChip(
                            key: const Key('repay_overdue'),
                            label: const Text('Trả khoản quá hạn'),
                            onPressed: () => _setAmount(account.overdueAmount.floor()),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (valid && _previewAmount == amount)
                _Preview(amount: amount)
              else if (valid)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (_controller.text.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Nhập số tiền để xem khoản nợ nào sẽ được trừ. Tiền luôn trừ vào khoản đến hạn sớm nhất trước.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4))
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('repay_submit'),
                onPressed: valid
                    ? () => context.push('${AppRoutes.qrPayment}?debtAmount=$amount')
                    : null,
                icon: const Icon(Icons.qr_code_2),
                label: FittedBox(
                  child: Text(valid
                      ? 'Thanh toán ${formatVnd(amount)} qua VietQR'
                      : 'Thanh toán qua VietQR'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(allocationPreviewProvider(amount));
    return preview.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Container(
        key: const Key('repay_preview_error'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Text(ApiException.from(e).message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(allocationPreviewProvider(amount)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (p) => SectionCard(
        icon: Icons.list_alt,
        title: 'TIỀN SẼ ĐƯỢC TRỪ VÀO',
        child: Column(
          key: const Key('repay_preview'),
          children: [
            for (final a in p.allocations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.entryNumber,
                              style: AppTextStyles.bodySmall
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text(
                              'Hạn ${formatDate(a.dueDate)} · nợ ${formatVnd(a.outstandingAmount)}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('−${formatVnd(a.allocatedAmount)}',
                            style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w700, color: AppColors.statusSuccess)),
                        Text(a.clearsEntry ? 'Trả hết' : 'Trả một phần',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            if (p.unallocatedAmount > 0) ...[
              const Divider(height: 20, color: AppColors.borderSubtle),
              Text(
                'Còn dư ${formatVnd(p.unallocatedAmount)} không có khoản nợ nào để trừ.',
                key: const Key('repay_unallocated'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusWarning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
