import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/debt_labels.dart';
import '../../../core/labels/status_label.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../router/app_router.dart';
import '../data/debt_models.dart';
import '../providers/debt_providers.dart';

/// Một khoản nợ: số tiền, hạn trả, các lần cửa hàng xử lý khiếu nại và sổ biến động.
class DebtDetailScreen extends ConsumerStatefulWidget {
  final String debtId;
  const DebtDetailScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  bool _busy = false;

  Future<void> _dispute(DebtEntryListItem entry) async {
    final reason = await showDialog<String>(context: context, builder: (_) => _DisputeDialog(title: entry.title));
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(debtActionsProvider).dispute(entry.id, reason);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Đã gửi khiếu nại khoản nợ ${entry.title}. Cửa hàng sẽ xem xét và phản hồi.')));
    } on AppException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(debtEntryProvider(widget.debtId));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết khoản nợ'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.debt);
            }
          },
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(debtEntryProvider(widget.debtId))),
        data: _buildEntry,
      ),
    );
  }

  Widget _buildEntry(DebtEntryDetail detail) {
    final entry = detail.entry;
    final overdue = entry.isOverdue && entry.outstandingAmount > 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(debtEntryProvider(widget.debtId));
        try {
          await ref.read(debtEntryProvider(widget.debtId).future);
        } catch (_) {
          // The screen shows its own error.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text('Khoản nợ ${entry.title}', style: AppTextStyles.labelLarge)),
                    const SizedBox(width: 8),
                    StatusBadge(labelOf(debtEntryStatusLabels, entry.status)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${debtSourceLabel(entry.sourceType)} · ${entry.entryNumber}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                _Row('Giá trị đơn đã giao', formatVnd(detail.fulfillmentValue)),
                if (detail.prepaymentAppliedAmount > 0) _Row('Đã trả trước, trừ vào đơn', formatVnd(detail.prepaymentAppliedAmount)),
                _Row('Số nợ ban đầu', formatVnd(entry.originalAmount)),
                _Row('Đã trả', formatVnd(entry.totalPaid), color: AppColors.primary),
                const Divider(height: 24, color: AppColors.borderSubtle),
                _Row('Còn nợ', formatVnd(entry.outstandingAmount), bold: true),
                const SizedBox(height: 4),
                _Row(
                  'Hạn trả',
                  formatVnDate(entry.dueDate),
                  color: overdue ? AppColors.statusError : null,
                ),
                if (overdue)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: StatusBadge(StatusLabel('Quá hạn ${entry.overdueDays} ngày', LabelTone.danger)),
                  ),
                if (canDisputeDebtEntry(entry.status)) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _dispute(entry),
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Khiếu nại khoản nợ này'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  ),
                ],
                if (entry.outstandingAmount >= 1) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.debtRepay),
                    icon: const Icon(Icons.payments_outlined, size: 20),
                    label: const Text('Trả nợ qua payOS'),
                  ),
                ],
              ],
            ),
          ),
          if (detail.actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xử lý khiếu nại', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 12),
                  for (final action in detail.actions) _ActionRow(action: action),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sổ biến động', style: AppTextStyles.labelLarge),
                const SizedBox(height: 12),
                if (detail.transactions.isEmpty)
                  Text('Chưa có biến động nào.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted))
                else
                  for (final tx in detail.transactions) _TransactionRow(tx: tx),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
        child: child,
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.color, this.bold = false});
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: bold ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700) : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? AppColors.textPrimary)),
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});
  final DebtAction action;

  @override
  Widget build(BuildContext context) {
    final extra = <String>[
      if (action.adjustmentAmount != null) 'Điều chỉnh ${formatVnd(action.adjustmentAmount!)}',
      if (action.newDueDate != null) 'Hạn mới ${formatVnDate(action.newDueDate)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(debtActionLabel(action.actionType), style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          Text(formatVnDateTime(action.createdAt), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          if (action.reason.isNotEmpty) Text(action.reason, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          if (extra.isNotEmpty) Text(extra.join(' · '), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});
  final DebtTransaction tx;

  @override
  Widget build(BuildContext context) {
    final grew = tx.amountDelta > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debtTransactionLabel(tx.transactionType), style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                Text(formatVnDateTime(tx.occurredAt), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                if (tx.note != null) Text(tx.note!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${grew ? '+' : '−'} ${formatVnd(tx.amountDelta.abs())}',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: grew ? AppColors.statusError : AppColors.primary),
              ),
              Text('Dư nợ ${formatVnd(tx.balanceAfter)}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for the reason (required, up to 1000 characters) and answers null if the farmer backs out.
class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog({required this.title});

  final String title;

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Khiếu nại ${widget.title}'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cửa hàng sẽ xem xét và giữ nguyên, điều chỉnh hoặc hủy khoản nợ này. Bác vẫn trả nợ được trong lúc chờ.'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Bác thấy chưa đúng ở điểm nào?'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập lý do khiếu nại' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        TextButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.pop(context, _reason.text.trim());
          },
          child: const Text('Gửi khiếu nại'),
        ),
      ],
    );
  }
}
