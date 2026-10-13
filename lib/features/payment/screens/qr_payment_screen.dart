import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../debt/providers/debt_providers.dart';
import '../../orders/data/order_models.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/providers/order_providers.dart';
import '../../home/providers/home_providers.dart';

/// Thanh toán qua payOS (VietQR): trả tiền đơn hàng ([orderId]) hoặc trả nợ
/// ([debtAmount], nguyên đồng).
///
/// Tiền chỉ được coi là đã trả khi server báo PAID (`GET /api/me/payments/{id}`),
/// không dựa vào trang trả về của payOS. Màn hình tự hỏi lại định kỳ, hỏi ngay
/// khi người dùng quay lại app (sau khi chuyển khoản ở app ngân hàng), và nhờ
/// server hỏi thẳng payOS (sync) nếu chờ lâu.
class QRPaymentScreen extends ConsumerStatefulWidget {
  const QRPaymentScreen({
    super.key,
    this.orderId,
    this.debtAmount,
    @visibleForTesting this.pollInterval = const Duration(seconds: 3),
    @visibleForTesting this.syncAfter = const Duration(seconds: 60),
    @visibleForTesting this.showDevTools = kDebugMode,
  }) : assert((orderId == null) != (debtAmount == null),
            'Truyền đúng một trong orderId hoặc debtAmount');

  final String? orderId;
  final int? debtAmount;
  final Duration pollInterval;

  /// Chờ lâu hơn mốc này mà vẫn PENDING thì gọi sync (webhook có thể chậm).
  final Duration syncAfter;
  final bool showDevTools;

  @override
  ConsumerState<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

enum _Phase { creating, waiting, expired, unavailable, failed }

class _QRPaymentScreenState extends ConsumerState<QRPaymentScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.creating;
  PayOsLink? _link;
  String _error = '';
  Timer? _poll;
  Timer? _ticker;
  /// Thời gian đã chờ, cộng dồn theo mỗi nhịp hỏi.
  Duration _waited = Duration.zero;
  bool _synced = false;
  bool _checking = false;
  bool _cancelling = false;
  bool _finished = false;
  bool _offline = false;

  PaymentRepository get _repo => ref.read(paymentRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại từ app ngân hàng: kiểm tra ngay.
    if (state == AppLifecycleState.resumed && _phase == _Phase.waiting) {
      _check();
    }
  }

  Future<void> _create() async {
    _poll?.cancel();
    _ticker?.cancel();
    setState(() {
      _phase = _Phase.creating;
      _error = '';
      _link = null;
      _synced = false;
      _waited = Duration.zero;
    });
    try {
      final order = widget.orderId;
      final link = order != null
          ? await _repo.createForOrder(order)
          : await _repo.createForDebt(widget.debtAmount!.toDouble());
      if (!mounted) return;
      setState(() {
        _link = link;
        _phase = _Phase.waiting;
      });
      _poll = Timer.periodic(widget.pollInterval, (_) {
        _waited += widget.pollInterval;
        _check();
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final exp = _link?.expiresAt;
        if (exp != null && DateTime.now().isAfter(exp) && _phase == _Phase.waiting) {
          _onExpired();
        } else {
          setState(() {}); // đếm ngược
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = e.kind == ApiErrorKind.unavailable ? _Phase.unavailable : _Phase.failed;
      });
    }
  }

  /// Hỏi server trạng thái thật. [forceSync] = nhờ server hỏi thẳng payOS.
  Future<void> _check({bool forceSync = false}) async {
    final link = _link;
    if (link == null || _checking || _finished) return;
    _checking = true;
    try {
      final waitedLong = _waited >= widget.syncAfter;
      final useSync = forceSync || (waitedLong && !_synced);
      if (useSync) _synced = true;
      final p = useSync ? await _repo.sync(link.paymentId) : await _repo.get(link.paymentId);
      if (!mounted) return;
      if (_offline) setState(() => _offline = false);
      _apply(p);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Lỗi tạm thời khi hỏi trạng thái: giữ màn hình, thử lại ở lần sau.
      setState(() => _offline = e.isConnectivity);
    } finally {
      _checking = false;
    }
  }

  void _apply(Payment p) {
    if (p.isPaid) {
      _finish(success: true);
    } else if (p.status == PaymentStatus.failed || p.status == PaymentStatus.cancelled) {
      _poll?.cancel();
      _ticker?.cancel();
      setState(() {
        _phase = _Phase.expired;
        _error = p.status == PaymentStatus.cancelled
            ? 'Phiên thanh toán đã bị huỷ.'
            : 'Mã thanh toán đã hết hạn hoặc không thành công.';
      });
    }
  }

  Future<void> _onExpired() async {
    _poll?.cancel();
    _ticker?.cancel();
    // Hỏi lần cuối: có thể tiền đã về sát giờ hết hạn.
    await _check(forceSync: true);
    if (!mounted || _finished) return;
    setState(() {
      _phase = _Phase.expired;
      _error = 'Mã thanh toán đã hết hạn.';
    });
  }

  void _finish({required bool success}) {
    if (_finished) return;
    _finished = true;
    _poll?.cancel();
    _ticker?.cancel();
    final order = widget.orderId;
    if (order != null) {
      ref.invalidate(orderPaymentsProvider(order));
      ref.invalidate(orderDetailProvider(order));
      invalidateOrders(ref);
      context.pushReplacement(
          '${AppRoutes.paymentResult}?success=$success&orderId=$order');
    } else {
      invalidateDebt(ref);
      ref.invalidate(myCreditProvider);
      context.pushReplacement('${AppRoutes.paymentResult}?success=$success&kind=debt');
    }
  }

  /// Rời màn thanh toán: về lại màn trước, nếu không có thì về đơn hàng / công nợ.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      final order = widget.orderId;
      context.go(order != null ? '/orders/$order' : AppRoutes.debt);
    }
  }

  Future<void> _cancelPayment() async {
    final link = _link;
    if (link == null || _cancelling) return;
    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final p = await _repo.cancel(link.paymentId);
      if (!mounted) return;
      if (p.isPaid) {
        // payOS báo đã trả ngay trước khi huỷ: coi như thành công.
        _finish(success: true);
        return;
      }
      _poll?.cancel();
      _ticker?.cancel();
      final order = widget.orderId;
      if (order != null) ref.invalidate(orderPaymentsProvider(order));
      messenger.showSnackBar(const SnackBar(content: Text('Đã huỷ phiên thanh toán.')));
      _leave();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _simulatePaid() async {
    final link = _link;
    if (link == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      _apply(await _repo.simulatePaid(link.paymentId));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text('Đã sao chép $label'), duration: const Duration(seconds: 1)));
  }

  String _remaining() {
    final exp = _link?.expiresAt;
    if (exp == null) return '';
    final d = exp.difference(DateTime.now());
    if (d.isNegative) return '00:00';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Thanh toán VietQR')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.creating:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tạo mã thanh toán...'),
            ],
          ),
        );
      case _Phase.unavailable:
      case _Phase.failed:
      case _Phase.expired:
        return _ProblemView(
          phase: _phase,
          message: _error,
          onRetry: _create,
          onBack: _leave,
          isDebt: widget.orderId == null,
        );
      case _Phase.waiting:
        return _waiting(_link!);
    }
  }

  Widget _waiting(PayOsLink link) {
    final content = link.paymentNumber.replaceAll('-', '');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Text('SỐ TIỀN CẦN THANH TOÁN',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(formatVnd(link.amount),
                  key: const Key('pay_amount'),
                  style: AppTextStyles.h2.copyWith(color: AppColors.primaryDark)),
              const SizedBox(height: 16),
              if (link.qrCode != null && link.qrCode!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderSubtle),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    key: const Key('pay_qr'),
                    data: link.qrCode!,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                )
              else
                Text('Không có mã QR. Hãy mở trang thanh toán payOS bên dưới.',
                    textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
              Text('Mở app ngân hàng → Quét mã QR → Xác nhận chuyển khoản',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              if (link.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text('Mã hết hạn sau ${_remaining()}',
                    key: const Key('pay_countdown'),
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.statusWarning, fontWeight: FontWeight.w600)),
              ],
              const Divider(height: 28, color: AppColors.borderSubtle),
              _CopyRow(
                  label: 'Số tiền',
                  value: link.amount.round().toString(),
                  display: formatVnd(link.amount),
                  onCopy: _copy),
              _CopyRow(label: 'Nội dung', value: content, onCopy: _copy),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('pay_waiting'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.statusWarningSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.statusWarning)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _offline
                      ? 'Mất kết nối, đang thử lại... Tiền đã chuyển sẽ không bị mất.'
                      : 'Đang chờ xác nhận thanh toán. Màn hình sẽ tự chuyển khi nhận được tiền.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusWarning),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          key: const Key('pay_check'),
          onPressed: _checking ? null : () => _check(forceSync: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Tôi đã chuyển khoản'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('pay_open_payos'),
          onPressed: () => launchUrl(Uri.parse(link.checkoutUrl),
              mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Mở trang thanh toán payOS'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('pay_cancel'),
          onPressed: _cancelling ? null : _cancelPayment,
          style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
          child: Text(_cancelling ? 'Đang huỷ...' : 'Huỷ thanh toán'),
        ),
        if (widget.showDevTools) ...[
          const Divider(height: 24),
          TextButton(
            key: const Key('pay_simulate'),
            onPressed: _simulatePaid,
            child: const Text('[DEV] Giả lập đã thanh toán'),
          ),
        ],
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.display,
  });

  final String label;
  final String value;
  final String? display;
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label:',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(display ?? value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          tooltip: 'Sao chép $label',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => onCopy(label.toLowerCase(), value),
        ),
      ],
    );
  }
}

class _ProblemView extends StatelessWidget {
  const _ProblemView({
    required this.phase,
    required this.message,
    required this.onRetry,
    required this.onBack,
    required this.isDebt,
  });

  final bool isDebt;
  final _Phase phase;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final expired = phase == _Phase.expired;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expired ? Icons.timer_off_outlined : Icons.cloud_off_outlined,
              size: 64,
              color: AppColors.borderStrong,
            ),
            const SizedBox(height: 16),
            AuthBanner(message),
            const SizedBox(height: 20),
            if (phase != _Phase.failed)
              ElevatedButton(
                key: const Key('pay_retry'),
                onPressed: onRetry,
                child: Text(expired ? 'Tạo mã mới' : 'Thử lại'),
              ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('pay_back'),
              onPressed: onBack,
              child: Text(isDebt ? 'Về công nợ' : 'Về đơn hàng'),
            ),
          ],
        ),
      ),
    );
  }
}
