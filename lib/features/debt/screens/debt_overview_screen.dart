import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/data/order_models.dart';
import '../../orders/providers/order_providers.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/debt_models.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_widgets.dart';

class DebtOverviewScreen extends ConsumerWidget {
  const DebtOverviewScreen({super.key});

  Future<void> _reload(WidgetRef ref) async {
    ref
      ..invalidate(myCreditProvider)
      ..invalidate(debtAccountProvider)
      ..invalidate(upcomingDebtsProvider);
    await Future.wait([
      ref.read(myCreditProvider.future),
      ref.read(debtAccountProvider.future),
    ]).catchError((_) => <Object?>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credit = ref.watch(myCreditProvider);
    final account = ref.watch(debtAccountProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text('Công nợ', style: AppTextStyles.h3),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            key: const Key('debt_history'),
            tooltip: 'Lịch sử trả nợ',
            icon: const Icon(Icons.history_outlined, color: AppColors.textPrimary),
            onPressed: () => context.push('/debt/history'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _body(context, ref, credit, account),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, AsyncValue<CreditSummary?> credit,
      AsyncValue<DebtAccount?> account) {
    final error = credit.error ?? account.error;
    if (error != null) {
      return ErrorRetryWidget(error: error, onRetry: () => _reload(ref));
    }
    if (credit.isLoading || account.isLoading) {
      return const _OverviewSkeleton();
    }
    final c = credit.value;
    final a = account.value;
    if (c == null && a == null) {
      return const EmptyDataWidget(
        message:
            'Bạn chưa có hạn mức mua ghi nợ.\nLiên hệ cửa hàng để được cấp hạn mức và mua chịu vật tư.',
        fallbackIcon: Icons.account_balance_wallet_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _reload(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (c != null) _CreditCard(credit: c, debt: a),
          if (c != null) const SizedBox(height: 16),
          if (a != null) _DebtSummaryCard(account: a),
          if (a != null && a.hasDebt) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('debt_repay'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => context.push('/debt/repay'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Trả nợ'),
            ),
          ],
          const SizedBox(height: 20),
          const _UpcomingSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.credit, required this.debt});

  final CreditSummary credit;
  final DebtAccount? debt;

  @override
  Widget build(BuildContext context) {
    // Dư nợ lấy từ sổ nợ nếu có (chính xác hơn), không thì từ hồ sơ tín dụng.
    final owing = debt?.currentBalance ?? credit.outstanding;
    final used = credit.creditLimit > 0 ? owing / credit.creditLimit : 0.0;
    return Container(
      key: const Key('credit_card'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Vòng tròn trang trí góc phải.
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill('Hạn mức tín dụng', icon: Icons.account_balance_wallet_outlined),
                      if (credit.paymentTermDays != null)
                        _pill('Kỳ hạn ${credit.paymentTermDays} ngày'),
                      if (!credit.isActive) _pill('Hạn mức đang tạm khoá', warn: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(formatVnd(credit.creditLimit),
                        key: const Key('credit_limit'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 14),
                  DebtProgressBar(
                    key: const Key('credit_usage'),
                    value: used,
                    color: used >= 0.9 ? const Color(0xFFFFB74D) : Colors.white,
                    track: Colors.white.withValues(alpha: 0.22),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _figure('Đang nợ', owing, const Key('credit_owing'))),
                      Container(width: 1, height: 34, color: Colors.white24),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _figure(
                              'Còn khả dụng',
                              credit.isActive ? credit.availableCredit : 0,
                              const Key('credit_available'))),
                    ],
                  ),
                  if (!credit.isActive) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Hạn mức chưa được kích hoạt nên chưa mua ghi nợ được. Vui lòng liên hệ cửa hàng.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, {bool warn = false, IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: warn ? const Color(0xFFFFB74D) : Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(text,
                  style: TextStyle(
                      color: warn ? Colors.black87 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _figure(String label, double value, Key key) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatVnd(value),
                key: key,
                style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ],
      );
}

class _DebtSummaryCard extends StatelessWidget {
  const _DebtSummaryCard({required this.account});

  final DebtAccount account;

  @override
  Widget build(BuildContext context) {
    final overdue = account.hasOverdue;
    return SectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Tổng quan công nợ',
      child: Column(
        children: [
          InfoRow('Tổng nợ hiện tại', formatVnd(account.currentBalance),
              bold: true, valueKey: const Key('debt_balance')),
          InfoRow('Số khoản đang nợ', '${account.openEntryCount}'),
          if (account.oldestDueDate != null && account.hasDebt)
            InfoRow('Hạn trả gần nhất', formatDate(account.oldestDueDate!)),
          if (overdue) ...[
            const Divider(height: 20, color: AppColors.borderSubtle),
            Container(
              key: const Key('debt_overdue_banner'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusErrorSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 22, color: AppColors.debtOverdue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bạn có ${formatVnd(account.overdueAmount)} đã quá hạn. '
                      'Vui lòng thanh toán sớm để tránh ảnh hưởng việc mua ghi nợ.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.debtOverdue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingDebtsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Khoản nợ cần trả', style: AppTextStyles.h4)),
            TextButton(
              key: const Key('debt_view_all'),
              onPressed: () => context.push('/debt/list'),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        upcoming.when(
          loading: () => const Column(
            children: [
              ShimmerLoadingWidget(height: 150, borderRadius: 18),
              SizedBox(height: 12),
              ShimmerLoadingWidget(height: 150, borderRadius: 18),
            ],
          ),
          error: (e, _) => SizedBox(
            height: 200,
            child: ErrorRetryWidget(
                error: e, onRetry: () => ref.invalidate(upcomingDebtsProvider)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Container(
                key: const Key('debt_none'),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 14,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                          color: AppColors.primaryLight, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text('Bạn không có khoản nợ nào cần trả.',
                        textAlign: TextAlign.center,
                        style:
                            AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final e in items) ...[
                  DebtEntryCard(
                    entry: e,
                    onTap: () => context.push('/debt/${e.id}'),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Khung chờ của màn tổng quan: thẻ hạn mức, thẻ tổng quan, khoản nợ.
class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          ShimmerLoadingWidget(height: 190, borderRadius: 24),
          SizedBox(height: 16),
          ShimmerLoadingWidget(height: 130, borderRadius: 18),
          SizedBox(height: 20),
          ShimmerLoadingWidget(height: 150, borderRadius: 18),
        ],
      );
}
