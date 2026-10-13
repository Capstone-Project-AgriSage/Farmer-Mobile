import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
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
      return const Center(child: CircularProgressIndicator());
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
    return Container(
      key: const Key('credit_card'),
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill('Hạn mức tín dụng'),
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
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _figure('Đang nợ', owing, const Key('credit_owing'))),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                  child: _figure('Còn khả dụng',
                      credit.isActive ? credit.availableCredit : 0, const Key('credit_available'))),
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
    );
  }

  Widget _pill(String text, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: warn ? const Color(0xFFFFB74D) : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: warn ? Colors.black87 : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
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
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 20, color: AppColors.debtOverdue),
                  const SizedBox(width: 8),
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
            Expanded(child: Text('Khoản nợ cần trả', style: AppTextStyles.h3)),
            TextButton(
              key: const Key('debt_view_all'),
              onPressed: () => context.push('/debt/list'),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        upcoming.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text('Bạn không có khoản nợ nào cần trả.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
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
