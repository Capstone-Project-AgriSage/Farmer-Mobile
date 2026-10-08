import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/network/dio_provider.dart';
import '../../router/app_router.dart';
import '../payment/data/payment_models.dart';
import '../payment/data/pending_payment.dart';

/// Developer tools on the account screen. Only built when `SHOW_DEV_TOOLS=true` (see `env/*.json`), so a release build
/// never shows it.
class DevToolsSection extends ConsumerWidget {
  const DevToolsSection({super.key});

  /// The local test page of `tool/payos_webview_test`, served on port 8099 of the machine the API runs on.
  static Uri testPageUrl() => Uri.parse(Env.apiBaseUrl).replace(port: 8099, path: '/start.html', query: '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.showDevTools) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'CÔNG CỤ PHÁT TRIỂN',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: ListTile(
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
