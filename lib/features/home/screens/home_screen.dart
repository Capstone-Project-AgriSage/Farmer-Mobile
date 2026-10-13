import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/session_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../ai_doctor/data/diagnosis_models.dart';
import '../../ai_doctor/providers/diagnosis_providers.dart';
import '../../ai_doctor/widgets/diagnosis_widgets.dart';
import '../../debt/providers/debt_providers.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../orders/data/order_models.dart';
import '../../orders/widgets/order_widgets.dart';
import '../providers/home_providers.dart';
import '../../payment/widgets/pending_payment_banner.dart';

/// Trang chủ: lối tắt và tóm tắt DỮ LIỆU THẬT của chính nông dân (chẩn đoán gần
/// đây, đơn hàng, công nợ). Không có nội dung mẫu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(homeOrderStatsProvider)
      ..invalidate(latestDiagnosisProvider)
      ..invalidate(debtAccountProvider)
      ..invalidate(unreadCountProvider);
    await Future.wait([
      ref.read(homeOrderStatsProvider.future),
      ref.read(latestDiagnosisProvider.future),
      ref.read(debtAccountProvider.future),
    ]).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, user),
                const SizedBox(height: 12),
                Text('Hôm nay bạn cần hỗ trợ gì?',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                const PendingPaymentBanner(),
                _buildAiBanner(context),
                const SizedBox(height: 20),
                const _DiagnosisCard(),
                const SizedBox(height: 20),
                const _OrdersCard(),
                const _DebtCard(),
                const SizedBox(height: 80), // chừa chỗ cho thanh điều hướng dưới
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SessionUser? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B5E20),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(user?.initials ?? '',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TÀI KHOẢN NÔNG DÂN',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('Xin chào, ${user?.fullName ?? ''}',
                        key: const Key('home_greeting'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4.copyWith(color: const Color(0xFF1F2937))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const NotificationBell(route: '${AppRoutes.home}/notifications'),
      ],
    );
  }

  Widget _buildAiBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          // Hình chìm trang trí (không tải từ mạng).
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(Icons.eco, size: 110, color: Colors.white.withValues(alpha: 0.07)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Chuyên gia hỗ trợ nhận diện',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 16),
              const Text('Kiểm tra bệnh trên cây lúa',
                  style: TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Chụp ảnh lá lúa gửi cho chuyên gia của cửa hàng để nhận kết luận và gợi ý sản phẩm phù hợp.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('home_capture'),
                      onPressed: () => context.push(AppRoutes.aiScan),
                      icon: const Icon(Icons.camera_alt_outlined,
                          color: Color(0xFF1B5E20), size: 20),
                      label: const FittedBox(
                        child: Text('Chụp ảnh',
                            style: TextStyle(
                                color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('home_history'),
                      onPressed: () => context.push(AppRoutes.diagnoseHistory),
                      icon: const Icon(Icons.history, color: Colors.white, size: 20),
                      label: const FittedBox(
                        child: Text('Xem lịch sử',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3D15),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Khung trắng của một thẻ trên Trang chủ.
class _HomeCard extends StatelessWidget {
  const _HomeCard({
    super.key,
    required this.title,
    required this.child,
    this.actionText,
    this.onAction,
    this.actionKey,
  });

  final String title;
  final Widget child;
  final String? actionText;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
              ),
              if (actionText != null)
                GestureDetector(
                  key: actionKey,
                  onTap: onAction,
                  child: Text('$actionText >',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 56,
        child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
}

class _CardError extends StatelessWidget {
  const _CardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      );
}

// ── Chẩn đoán gần đây ───────────────────────────────────────────────

class _DiagnosisCard extends ConsumerWidget {
  const _DiagnosisCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestDiagnosisProvider);
    return _HomeCard(
      key: const Key('home_diag_card'),
      title: 'CHẨN ĐOÁN GẦN ĐÂY',
      actionText: 'Lịch sử',
      actionKey: const Key('home_diag_history'),
      onAction: () => context.push(AppRoutes.diagnoseHistory),
      child: latest.when(
        loading: () => const _CardLoading(),
        error: (_, __) => _CardError(
            message: 'Chưa tải được chẩn đoán gần đây.',
            onRetry: () => ref.invalidate(latestDiagnosisProvider)),
        data: (c) => c == null ? const _NoDiagnosis() : _DiagnosisBody(summary: c),
      ),
    );
  }
}

class _NoDiagnosis extends StatelessWidget {
  const _NoDiagnosis();

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('home_diag_none'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn chưa gửi ảnh lá lúa nào để chuyên gia xem.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('home_diag_start'),
            onPressed: () => context.push(AppRoutes.imageCapture),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Chụp ảnh lá lúa'),
          ),
        ],
      );
}

class _DiagnosisBody extends ConsumerWidget {
  const _DiagnosisBody({required this.summary});

  final DiagnosisSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final verified = s.status == DiagnosisStatus.verified;
    final hint = switch (s.status) {
      DiagnosisStatus.verified => 'Chuyên gia đã có kết luận cho ảnh của bạn.',
      DiagnosisStatus.inconclusive => 'Ảnh chưa đủ rõ. Hãy chụp lại và gửi ảnh mới.',
      DiagnosisStatus.cancelled => 'Bạn đã huỷ ca này.',
      _ => 'Chuyên gia đang xem ảnh của bạn. Kết quả sẽ hiện ở đây khi có.',
    };

    // Sản phẩm chuyên gia gợi ý (chỉ khi đã có kết luận); lỗi thì bỏ qua phần này.
    final products = verified
        ? ref.watch(diagnosisDetailProvider(s.id)).valueOrNull?.result?.products ??
            const <RecommendedProduct>[]
        : const <RecommendedProduct>[];

    return InkWell(
      key: const Key('home_diag_latest'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/ai-scan/case/${s.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.caseNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ),
              const SizedBox(width: 8),
              DiagnosisStatusBadge(s.status),
            ],
          ),
          const SizedBox(height: 8),
          if (verified && s.diseaseDisplay != null)
            Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.diseaseDisplay!,
                      key: const Key('home_diag_disease'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          if (verified && s.diseaseDisplay != null) const SizedBox(height: 4),
          Text(hint, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('SẢN PHẨM CHUYÊN GIA GỢI Ý',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            for (final p in products.take(2))
              InkWell(
                key: Key('home_diag_product_${p.storeProductId}'),
                onTap: () => context.push('/products/${p.storeProductId}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      Text('Xem >',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
          // Chỉ ca đã có kết luận mới "do chuyên gia xác nhận" (ca đang chờ/huỷ/chụp lại thì không).
          if (verified) ...[
            const SizedBox(height: 10),
            Row(
              key: const Key('home_diag_verified_note'),
              children: [
                const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Kết luận do chuyên gia của cửa hàng xác nhận',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Đơn hàng ────────────────────────────────────────────────────────

class _OrdersCard extends ConsumerWidget {
  const _OrdersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeOrderStatsProvider);
    return _HomeCard(
      key: const Key('home_orders_card'),
      title: 'ĐƠN HÀNG CỦA BẠN',
      actionText: 'Xem tất cả',
      actionKey: const Key('home_orders_all'),
      onAction: () => context.push(AppRoutes.orderList),
      child: stats.when(
        loading: () => const _CardLoading(),
        error: (_, __) => _CardError(
            message: 'Chưa tải được đơn hàng của bạn.',
            onRetry: () => ref.invalidate(homeOrderStatsProvider)),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: _StatBox(
                        valueKey: const Key('home_stat_pending'),
                        title: 'Chờ xác nhận',
                        count: s.pending,
                        highlight: s.pending > 0)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatBox(
                        valueKey: const Key('home_stat_progress'),
                        title: 'Đang xử lý',
                        count: s.inProgress,
                        highlight: s.inProgress > 0)),
                const SizedBox(width: 8),
                Expanded(
                    child: _StatBox(
                        valueKey: const Key('home_stat_done'),
                        title: 'Hoàn thành',
                        count: s.done)),
              ],
            ),
            const SizedBox(height: 16),
            if (s.latest == null) const _NoOrders() else _LatestOrder(order: s.latest!),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(
      {required this.title,
      required this.count,
      required this.valueKey,
      this.highlight = false});

  final Key valueKey;
  final String title;
  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: highlight ? Colors.orange.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? Colors.orange.shade200 : AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title,
                maxLines: 1,
                style: AppTextStyles.caption.copyWith(
                    color: highlight ? Colors.orange.shade800 : AppColors.textSecondary,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w500)),
          ),
          const SizedBox(height: 4),
          Text('$count',
              key: valueKey,
              style: AppTextStyles.h4.copyWith(
                  color: highlight ? Colors.orange.shade800 : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _NoOrders extends StatelessWidget {
  const _NoOrders();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('home_orders_none'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn chưa có đơn hàng nào.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('home_shop_now'),
              onPressed: () => context.go(AppRoutes.products),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Mua sắm ngay'),
            ),
          ],
        ),
      );
}

class _LatestOrder extends StatelessWidget {
  const _LatestOrder({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('home_latest_order'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(order.orderNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      OrderStatusBadge(order.status),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatVnd(order.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('Đặt lúc ${formatDateTime(order.createdAt)}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                Text('${order.itemCount} sản phẩm',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Chi tiết >',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Công nợ ─────────────────────────────────────────────────────────

/// Chỉ hiện khi nông dân đang có nợ (không có nợ thì không chiếm chỗ).
class _DebtCard extends ConsumerWidget {
  const _DebtCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(debtAccountProvider).valueOrNull;
    if (account == null || !account.hasDebt) return const SizedBox.shrink();
    final overdue = account.hasOverdue;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: _HomeCard(
        key: const Key('home_debt_card'),
        title: 'CÔNG NỢ',
        actionText: 'Xem chi tiết',
        actionKey: const Key('home_debt_open'),
        onAction: () => context.go(AppRoutes.debt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đang nợ',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                Text(formatVnd(account.currentBalance),
                    key: const Key('home_debt_balance'),
                    style: AppTextStyles.h4),
              ],
            ),
            if (overdue) ...[
              const SizedBox(height: 10),
              Container(
                key: const Key('home_debt_overdue'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusErrorSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.debtOverdue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${formatVnd(account.overdueAmount)} đã quá hạn',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.debtOverdue)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
