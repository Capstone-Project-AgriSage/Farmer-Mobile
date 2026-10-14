import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../router/app_router.dart';
import '../providers/payment_providers.dart';

/// What happened to a payOS payment, as the **server** says it (never as the address payOS returned to says).
class PaymentResultScreen extends ConsumerStatefulWidget {
  const PaymentResultScreen({super.key, required this.args});

  final PaymentResultArgs args;

  @override
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  bool _startingAgain = false;

  Future<void> _payAgain() async {
    final payment = widget.args.payment;
    setState(() => _startingAgain = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launcher = ref.read(paymentLauncherProvider);
      final pending = payment.isDebtRepayment || payment.orderId == null
          ? await launcher.startDebtRepayment(payment.amount.round())
          : await launcher.startOrderPayment(payment.orderId!);
      if (mounted) context.pushReplacement(AppRoutes.payosCheckout, extra: pending);
    } on ApiException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _startingAgain = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.args.payment;
    final state = ref.watch(paymentResultProvider(widget.args));
    final controller = ref.read(paymentResultProvider(widget.args).notifier);

    if (state is ResultError) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Kết quả thanh toán')),
        body: ErrorRetryWidget(error: state.error, onRetry: controller.retry),
      );
    }

    final visual = _visualFor(state);
    final canPayAgain = state is ResultCancelled || state is ResultFailed;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: visual.background, shape: BoxShape.circle),
                    child: state is ResultChecking
                        ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(strokeWidth: 3))
                        : Icon(visual.icon, size: 56, color: visual.color),
                  ),
                  const SizedBox(height: 24),
                  Text(visual.title, style: AppTextStyles.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    visual.message(payment.isDebtRepayment),
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  if (state is ResultPaid) ...[
                    const SizedBox(height: 20),
                    Text('Mã thanh toán: ${state.payment.paymentNumber}', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text(formatVnd(state.payment.amount), style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                  ],
                  if (state is ResultSimulatedPending) ...[
                    const SizedBox(height: 20),
                    _SimulatedBox(
                      paying: state.paying,
                      error: state.error,
                      onPay: controller.simulatePay,
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (state is ResultStillPending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton(onPressed: controller.retry, child: const Text('Kiểm tra lại')),
                    ),
                  if (canPayAgain)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton(
                        onPressed: _startingAgain ? null : _payAgain,
                        child: _startingAgain
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Thanh toán lại'),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => payment.isDebtRepayment
                        ? context.go(AppRoutes.debt)
                        : context.go(payment.orderId == null ? AppRoutes.orderList : '${AppRoutes.orderList}/${payment.orderId}'),
                    style: canPayAgain
                        ? ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, elevation: 0, side: const BorderSide(color: AppColors.primary))
                        : null,
                    child: Text(
                      payment.isDebtRepayment
                          ? 'Quay lại Sổ nợ'
                          : payment.orderId == null
                              ? 'Xem đơn hàng của tôi'
                              : 'Xem chi tiết đơn hàng',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Về trang chủ')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Visual {
  const _Visual({required this.icon, required this.color, required this.background, required this.title, required this.message});

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String Function(bool isDebt) message;
}

_Visual _visualFor(PaymentResultState state) => switch (state) {
      ResultPaid() => _Visual(
          icon: Icons.check_circle,
          color: AppColors.statusSuccess,
          background: AppColors.statusSuccessSurface,
          title: 'Thanh toán thành công!',
          message: (isDebt) => isDebt
              ? 'Khoản trả nợ đã được ghi nhận vào Sổ nợ của bạn.'
              : 'Cửa hàng đã nhận được tiền và sẽ xác nhận đơn hàng của bạn.',
        ),
      ResultCancelled() => _Visual(
          icon: Icons.cancel,
          color: AppColors.textMuted,
          background: AppColors.surfaceSubtle,
          title: 'Bạn đã hủy thanh toán',
          message: (isDebt) => isDebt
              ? 'Chưa có khoản tiền nào được trừ.'
              : 'Đơn hàng vẫn còn đó. Bạn có thể thanh toán lại trong Chi tiết đơn hàng.',
        ),
      ResultFailed(:final message) => _Visual(
          icon: Icons.error,
          color: AppColors.statusError,
          background: AppColors.statusErrorSurface,
          title: 'Thanh toán không thành công',
          message: (_) => message,
        ),
      ResultStillPending() => _Visual(
          icon: Icons.schedule,
          color: AppColors.statusWarning,
          background: AppColors.statusWarningSurface,
          title: 'Đang chờ xác nhận',
          message: (isDebt) =>
              'Hệ thống chưa xác nhận được khoản thanh toán. Bạn kiểm tra lại trong ${isDebt ? 'Sổ nợ' : 'Đơn hàng của tôi'} sau vài phút.',
        ),
      ResultSimulatedPending() => _Visual(
          icon: Icons.science_outlined,
          color: AppColors.statusWarning,
          background: AppColors.statusWarningSurface,
          title: 'Thanh toán thử',
          message: (_) => 'Tiền chưa đi qua payOS.',
        ),
      _ => _Visual(
          icon: Icons.sync,
          color: AppColors.primary,
          background: AppColors.primaryLight,
          title: 'Đang xác nhận thanh toán...',
          message: (_) => state is ResultChecking && state.attempt > 0
              ? 'Đang chờ ngân hàng xác nhận (lần ${state.attempt}).'
              : 'Bạn chờ một chút nhé.',
        ),
    };

class _SimulatedBox extends StatelessWidget {
  const _SimulatedBox({required this.paying, required this.error, required this.onPay});

  final bool paying;
  final String? error;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusWarningSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            'Đây là môi trường thử: thanh toán không đi qua payOS và không có tiền thật. '
            'Bấm nút dưới để coi như bạn đã chuyển khoản.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusWarning),
            textAlign: TextAlign.center,
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: paying ? null : onPay,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusWarning),
            child: paying
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Thanh toán nhanh (môi trường thử)', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
