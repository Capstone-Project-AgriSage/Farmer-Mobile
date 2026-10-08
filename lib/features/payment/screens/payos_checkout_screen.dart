import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../router/app_router.dart';
import '../data/intent_uri.dart';
import '../data/payos_url_matcher.dart';
import '../data/payment_repository.dart';
import '../data/pending_payment.dart';
import '../providers/payment_providers.dart';

/// The payOS pay page inside the app.
///
/// The WebView never loads the page payOS sends the buyer back to: that address is recognised (by path), the page is
/// not opened, and the result screen takes over and asks the server what happened. Links to banking apps (`intent://`,
/// `momo://`...) are handed to the system.
class PayosCheckoutScreen extends ConsumerStatefulWidget {
  const PayosCheckoutScreen({super.key, required this.payment});

  final PendingPayment payment;

  @override
  ConsumerState<PayosCheckoutScreen> createState() => _PayosCheckoutScreenState();
}

class _PayosCheckoutScreenState extends ConsumerState<PayosCheckoutScreen> with WidgetsBindingObserver {
  final _matcher = PayosUrlMatcher.fromEnv();
  WebViewController? _controller;
  bool _loading = true;
  AppException? _loadError;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final uri = Uri.tryParse(widget.payment.checkoutUrl);
    final first = uri == null ? null : _matcher.decide(uri);
    if (first is ReturnNavigation) {
      // The test gateway's link *is* the return page, and a WebView reports no navigation for its first address:
      // go straight to the result.
      WidgetsBinding.instance.addPostFrameCallback((_) => _openResult(first));
    } else if (uri != null) {
      _controller = _buildController(uri);
    } else {
      _loadError = const AppException(kind: AppErrorKind.unknown, message: 'Không mở được trang thanh toán.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  WebViewController _buildController(Uri start) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _loadError = const AppException.offline();
                });
              }
            }
          },
        ),
      )
      ..loadRequest(start);
    return controller;
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    final decision = _matcher.decide(uri);
    switch (decision) {
      case AllowNavigation():
        return NavigationDecision.navigate;
      case ReturnNavigation():
        if (request.isMainFrame) _openResult(decision);
        return NavigationDecision.prevent;
      case ExternalNavigation():
        _openExternal(request.url, uri);
        return NavigationDecision.prevent;
    }
  }

  void _openResult(ReturnNavigation navigation) {
    if (_finished || !mounted) return;
    _finished = true;
    context.pushReplacement(
      AppRoutes.paymentResult,
      extra: PaymentResultArgs(
        widget.payment,
        navigation.cancelled ? PaymentHint.cancelled : PaymentHint.returned,
        simulated: navigation.params.simulated,
      ),
    );
  }

  void _openCheck() {
    if (_finished || !mounted) return;
    _finished = true;
    context.pushReplacement(AppRoutes.paymentResult, extra: PaymentResultArgs(widget.payment, PaymentHint.check));
  }

  void _openCancel() {
    if (_finished || !mounted) return;
    _finished = true;
    context.pushReplacement(AppRoutes.paymentResult, extra: PaymentResultArgs(widget.payment, PaymentHint.cancelled));
  }

  Future<void> _openExternal(String raw, Uri uri) async {
    var opened = false;
    Uri? fallback;

    final intent = parseIntentUri(raw);
    final target = intent?.launchUri ?? uri;
    fallback = intent?.fallbackUrl;
    try {
      opened = await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (opened || !mounted) return;
    if (fallback != null) {
      await _controller?.loadRequest(fallback);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Không mở được ứng dụng ngân hàng. Bác cài ứng dụng đó hoặc quét mã QR bằng ứng dụng khác.'),
        ),
      );
  }

  /// Back from the banking app: if the money already arrived, go to the result without making the farmer press anything.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _finished) return;
    _checkQuietly();
  }

  Future<void> _checkQuietly() async {
    try {
      final info = await ref.read(paymentRepositoryProvider).payment(widget.payment.paymentId);
      if (info.isPaid) _openCheck();
    } on AppException {
      // No answer now; the farmer stays on the payOS page and can still press "Tôi đã chuyển khoản".
    }
  }

  Future<void> _confirmLeave() async {
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời trang thanh toán?'),
        content: const Text(
          'Nếu Bác đã chuyển khoản, hãy chọn "Tôi đã chuyển khoản" để kiểm tra. '
          'Chọn "Hủy giao dịch" nếu Bác không muốn thanh toán nữa.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, _LeaveChoice.stay), child: const Text('Tiếp tục thanh toán')),
          TextButton(onPressed: () => Navigator.pop(ctx, _LeaveChoice.check), child: const Text('Tôi đã chuyển khoản')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LeaveChoice.cancel),
            child: const Text('Hủy giao dịch', style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    switch (choice) {
      case _LeaveChoice.check:
        _openCheck();
      case _LeaveChoice.cancel:
        _openCancel();
      case _LeaveChoice.stay:
      case null:
        break;
    }
  }

  Future<void> _onBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    if (mounted) await _confirmLeave();
  }

  void _reload() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _loadError = null;
      _loading = true;
    });
    controller.loadRequest(Uri.parse(widget.payment.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thanh toán payOS', style: AppTextStyles.h4),
              Text(formatVnd(widget.payment.amount), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Đóng', onPressed: _confirmLeave),
          bottom: _loading && controller != null
              ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
              : null,
        ),
        body: _loadError != null
            ? ErrorRetryView(error: _loadError!, onRetry: controller == null ? null : _reload)
            : controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: controller),
      ),
    );
  }
}

enum _LeaveChoice { stay, check, cancel }
