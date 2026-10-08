import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/debt_labels.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../router/app_router.dart';
import '../data/debt_models.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_entry_card.dart';

/// Sổ nợ: hạn mức, dư nợ, cảnh báo quá hạn / sắp đến hạn, rồi danh sách các khoản nợ (lọc theo trạng thái).
class DebtOverviewScreen extends ConsumerStatefulWidget {
  const DebtOverviewScreen({super.key});
  @override
  ConsumerState<DebtOverviewScreen> createState() => _DebtOverviewScreenState();
}

class _DebtOverviewScreenState extends ConsumerState<DebtOverviewScreen> {
  final _scroll = ScrollController();
  String? _status;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
        ref.read(debtEntriesProvider(_status).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(debtActionsProvider).refreshDebt();
    try {
      await ref.read(debtSummaryProvider.future);
    } catch (_) {
      // The screen shows its own error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(debtSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text('Công nợ', style: AppTextStyles.h3),
        actions: [
          IconButton(
            tooltip: 'Lịch sử trả nợ',
            icon: const Icon(Icons.history_outlined, color: AppColors.textPrimary),
            onPressed: () => context.push(AppRoutes.debtHistory),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(debtSummaryProvider)),
        data: (data) => data.hasDebtBook ? _buildBook(data) : const _NoDebtBook(),
      ),
    );
  }

  Widget _buildBook(DebtSummary summary) {
    final entries = ref.watch(debtEntriesProvider(_status));
    final days = summary.daysToDue();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _CreditCard(summary: summary),
          if (summary.overdueAmount > 0 || summary.dueSoon()) ...[
            const SizedBox(height: 16),
            _AlertBanner(summary: summary, daysToDue: days, onRepay: () => context.push(AppRoutes.debtRepay)),
          ],
          const SizedBox(height: 16),
          _StatGrid(summary: summary),
          if (summary.maxRepayable > 0) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.debtRepay),
              icon: const Icon(Icons.payments_outlined, size: 20),
              label: const Text('Trả nợ qua payOS'),
            ),
          ],
          const SizedBox(height: 20),
          Text('Danh sách khoản nợ', style: AppTextStyles.labelLarge),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: debtEntryFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (label, status) = debtEntryFilters[i];
                final isActive = _status == status;
                return GestureDetector(
                  onTap: () => setState(() => _status = status),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1B5E20) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? const Color(0xFF1B5E20) : AppColors.borderSubtle),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isActive ? Colors.white : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ...entries.when(
            loading: () => const [Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))],
            error: (error, _) => [
              SizedBox(
                height: 200,
                child: ErrorRetryView(error: error, onRetry: () => ref.invalidate(debtEntriesProvider(_status))),
              ),
            ],
            data: (state) {
              if (state.items.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text('Không có khoản nợ nào trong mục này.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ];
              }
              return [
                for (final entry in state.items) ...[
                  DebtEntryCard(entry: entry, onTap: () => context.push('${AppRoutes.debt}/entries/${entry.id}')),
                  const SizedBox(height: 16),
                ],
                if (state.loadingMore)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                else if (state.moreError != null)
                  Column(
                    children: [
                      Text(state.moreError!.message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError), textAlign: TextAlign.center),
                      TextButton(onPressed: () => ref.read(debtEntriesProvider(_status).notifier).loadMore(), child: const Text('Thử lại')),
                    ],
                  ),
                const SizedBox(height: 60),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _NoDebtBook extends StatelessWidget {
  const _NoDebtBook();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Bác chưa có Sổ nợ', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              'Cửa hàng chưa cấp hạn mức mua chịu cho Bác. Bác liên hệ cửa hàng để được mở Sổ nợ; '
              'trong lúc đó Bác vẫn mua và trả tiền ngay như bình thường.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => context.go(AppRoutes.products), child: const Text('Mua sắm ngay')),
          ],
        ),
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.summary});

  final DebtSummary summary;

  @override
  Widget build(BuildContext context) {
    final credit = summary.credit;
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: const Text('Hạn mức mua chịu', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 16),
          Text(
            credit == null ? 'Chưa có hạn mức' : formatVnd(credit.creditLimit),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          if (credit != null && !credit.isActive) ...[
            const SizedBox(height: 6),
            Text('Hạn mức đang tạm khóa', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _Figure(label: 'Đang nợ', value: formatVnd(summary.balance))),
              Container(width: 1, height: 30, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(child: _Figure(label: 'Còn lại', value: credit == null ? '—' : formatVnd(credit.availableCredit))),
              if (credit != null && credit.reservedCredit > 0) ...[
                Container(width: 1, height: 30, color: Colors.white24),
                const SizedBox(width: 16),
                Expanded(child: _Figure(label: 'Đang giữ', value: formatVnd(credit.reservedCredit))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      );
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.summary, required this.daysToDue, required this.onRepay});

  final DebtSummary summary;
  final int? daysToDue;
  final VoidCallback onRepay;

  @override
  Widget build(BuildContext context) {
    final overdue = summary.overdueAmount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: overdue ? AppColors.statusErrorSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: overdue ? AppColors.statusError.withValues(alpha: 0.3) : AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notification_important_outlined, color: overdue ? AppColors.statusError : AppColors.statusWarning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  overdue ? 'Bác có khoản nợ đã quá hạn' : 'Sắp đến hạn trả nợ',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: overdue ? AppColors.statusError : AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            overdue
                ? 'Số tiền quá hạn ${formatVnd(summary.overdueAmount)}. Bác nên thanh toán sớm để không bị chặn mua chịu thêm.'
                : 'Khoản nợ gần nhất đến hạn ngày ${formatVnDate(summary.account?.oldestDueDate)}'
                    '${daysToDue != null && daysToDue! >= 0 ? ' (còn $daysToDue ngày)' : ''}.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRepay,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('Trả nợ ngay'),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final DebtSummary summary;

  @override
  Widget build(BuildContext context) {
    final account = summary.account;
    final tiles = [
      _Tile(label: 'Khoản nợ đang mở', value: '${account?.openEntryCount ?? 0}'),
      _Tile(
        label: 'Quá hạn',
        value: formatVnd(summary.overdueAmount),
        color: summary.overdueAmount > 0 ? AppColors.statusError : AppColors.textPrimary,
      ),
      _Tile(
        label: 'Hạn trả gần nhất',
        value: (account?.oldestDueDate != null && summary.balance > 0) ? formatVnDate(account!.oldestDueDate) : '—',
      ),
      _Tile(label: 'Đã trả gần đây', value: formatVnd(summary.totalRepaid), color: AppColors.primary),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
