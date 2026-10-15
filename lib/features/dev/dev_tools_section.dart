import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../router/app_router.dart';
import '../payment/data/pending_payment.dart';
import '../payment/providers/payment_providers.dart';

/// Công cụ phát triển ở màn Tài khoản. Chỉ dựng khi build với `SHOW_DEV_TOOLS=true` (xem `env/*.json`)
/// nên bản phát hành không bao giờ hiện.
///
/// (Công cụ của nhánh feature/mobile-diagnosis, chuyển sang kiến trúc hiện tại.)
class DevToolsSection extends ConsumerWidget {
  const DevToolsSection({super.key});

  /// Trang thử cục bộ của `tool/payos_webview_test`, phục vụ ở cổng 8099 của máy chạy API.
  static Uri testPageUrl() =>
      Uri.parse(AppConfig.apiBaseUrl).replace(port: 8099, path: '/start.html', query: '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConfig.showDevTools) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'CÔNG CỤ PHÁT TRIỂN',
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: ListTile(
              key: const Key('dev_webview_test'),
              leading: const Icon(Icons.science_outlined, color: AppColors.statusWarning),
              title: Text('Thử WebView payOS', style: AppTextStyles.bodyMedium),
              subtitle: Text(
                'Mở trang thử ${testPageUrl().authority} (xem tool/payos_webview_test)',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
              onTap: () {
                final userId = ref.read(sessionUserIdProvider);
                if (userId == null) return;
                context.push(
                  AppRoutes.payosCheckout,
                  extra: PendingPayment(
                    paymentId: 'dev-webview-test',
                    paymentNumber: 'DEV-TEST',
                    context: PaymentContext.orderPayment,
                    amount: 1000,
                    checkoutUrl: testPageUrl().toString(),
                    userId: userId,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
