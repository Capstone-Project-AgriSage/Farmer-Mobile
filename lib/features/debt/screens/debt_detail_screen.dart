import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/debt_models.dart';
import '../data/debt_repository.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_widgets.dart';

class DebtDetailScreen extends ConsumerStatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final String debtId;

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  bool _disputing = false;

  Future<void> _dispute() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DisputeDialog(),
    );
    if (reason == null || !mounted) return;
    setState(() => _disputing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(debtRepositoryProvider).dispute(widget.debtId, reason);
      if (!mounted) return;
      ref.invalidate(debtEntryProvider(widget.debtId));
      invalidateDebt(ref);
      messenger.showSnackBar(const SnackBar(
          content: Text('Đã gửi khiếu nại. Cửa hàng sẽ xem xét và phản hồi.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _disputing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(debtEntryProvider(widget.debtId));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết công nợ'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: entry.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => ErrorRetryWidget(
            error: e, onRetry: () => ref.invalidate(debtEntryProvider(widget.debtId))),
        data: (d) => _content(d),
      ),
    );
  }

  Widget _content(DebtEntryDetail d) {
    final overdue = d.isOverdue && !d.isClosed;
    final (statusFg, statusBg) = overdue
        ? (AppColors.debtOverdue, AppColors.statusErrorSurface)
        : DebtStatus.colors(d.status);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(debtEntryProvider(widget.debtId));
              await ref.read(debtEntryProvider(widget.debtId).future).catchError((_) => d);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  key: const Key('debt_status_banner'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Icon(
                          d.isClosed
                              ? Icons.check_circle_rounded
                              : (overdue ||
                                      d.status == DebtStatus.disputed ||
                                      d.status == DebtStatus.open)
                                  ? Icons.warning_amber_rounded
                                  : Icons.timelapse_rounded,
                          color: statusFg,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trạng thái',
                                style: AppTextStyles.caption.copyWith(color: statusFg)),
                            Text(
                              overdue
                                  ? '${DebtStatus.label(d.status)} · quá hạn ${d.overdueDays} ngày'
                                  : DebtStatus.label(d.status),
                              style: AppTextStyles.labelLarge
                                  .copyWith(color: statusFg, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.045),
                          blurRadius: 14,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(d.isClosed ? 'Giá trị khoản nợ' : 'Còn phải trả',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatVnd(d.isClosed ? d.originalAmount : d.outstandingAmount),
                          key: const Key('debt_amount'),
                          style: AppTextStyles.h1.copyWith(
                              color: d.isClosed ? AppColors.textPrimary : AppColors.statusError),
                        ),
                      ),
                      if (!d.isClosed && d.totalPaid > 0 && d.originalAmount > 0) ...[
                        const SizedBox(height: 14),
                        DebtProgressBar(
                          key: const Key('debt_progress'),
                          value: d.totalPaid / d.originalAmount,
                          color: AppColors.statusSuccess,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      const SizedBox(height: 12),
                      InfoRow('Mã khoản nợ', d.entryNumber),
                      if (d.orderNumber != null) InfoRow('Đơn hàng', d.orderNumber!),
                      InfoRow('Nguồn', DebtEntryDetail.sourceLabel(d.sourceType)),
                      InfoRow('Ngày lập', formatDate(d.createdAt)),
                      InfoRow('Hạn thanh toán', formatDate(d.dueDate),
                          valueColor: overdue ? AppColors.statusError : null,
                          bold: overdue),
                      InfoRow('Giá trị ghi nợ', formatVnd(d.originalAmount)),
                      InfoRow('Đã trả', formatVnd(d.totalPaid),
                          valueColor: d.totalPaid > 0 ? AppColors.statusSuccess : null),
                    ],
                  ),
                ),
                if (d.orderLines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Vật tư của đơn hàng',
                    child: Column(
                      children: [
                        for (final l in d.orderLines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l.productName,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(fontWeight: FontWeight.w500)),
                                      Text('${l.packagingName} × ${l.quantity}',
                                          style: AppTextStyles.caption
                                              .copyWith(color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(formatVnd(l.lineTotal),
                                    style: AppTextStyles.bodySmall
                                        .copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (d.transactions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    icon: Icons.swap_vert,
                    title: 'Biến động công nợ',
                    child: Column(
                      children: [for (final t in d.transactions) _TransactionRow(t)],
                    ),
                  ),
                ],
                if (d.actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    icon: Icons.forum_outlined,
                    title: 'Khiếu nại và xử lý',
                    child: Column(
                      children: [for (final a in d.actions) _ActionRow(a)],
                    ),
                  ),
                ],
                if (d.status == DebtStatus.disputed) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('debt_disputed_note'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.statusWarningSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 20, color: AppColors.statusWarning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Khoản nợ đang chờ cửa hàng xem xét. Trong lúc chờ, khoản nợ vẫn còn hiệu lực và vẫn có thể thanh toán.',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.statusWarning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (!d.isClosed)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6))
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (d.canDispute) ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        key: const Key('debt_dispute'),
                        onPressed: _disputing ? null : _dispute,
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: _disputing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const FittedBox(child: Text('Khiếu nại')),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      key: const Key('debt_pay'),
                      onPressed: () => context
                          .push('/debt/repay?amount=${d.outstandingAmount.floor()}'),
                      icon: const Icon(Icons.payments_outlined, size: 20),
                      label: const FittedBox(child: Text('Trả nợ')),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.t);

  final DebtTransaction t;

  @override
  Widget build(BuildContext context) {
    final up = t.amountDelta > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: up ? AppColors.statusErrorSurface : AppColors.statusSuccessSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 18, color: up ? AppColors.statusError : AppColors.statusSuccess),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DebtTransaction.label(t.type),
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                Text(formatDateTime(t.occurredAt),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                if (t.note != null && t.note!.isNotEmpty)
                  Text(t.note!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${up ? '+' : '−'}${formatVnd(t.amountDelta.abs())}',
              style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: up ? AppColors.statusError : AppColors.statusSuccess)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(this.a);

  final DebtAction a;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DebtAction.label(a.type),
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          if (a.type == 'CHANGE_DUE_DATE' && a.newDueDate != null)
            Text('Hạn mới: ${formatDate(a.newDueDate!)}', style: AppTextStyles.caption),
          if (a.reason.isNotEmpty)
            Text('"${a.reason}"',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          Text(formatDateTime(a.createdAt),
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Hỏi lý do khiếu nại. Controller thuộc về dialog để không bị dispose sớm.
class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog();

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khiếu nại khoản nợ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cho cửa hàng biết khoản nợ này sai ở đâu. Khiếu nại không làm thay đổi số tiền cho đến khi cửa hàng xử lý.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('dispute_reason'),
            controller: _controller,
            maxLines: 4,
            maxLength: DebtRepository.maxReasonLength,
            decoration: InputDecoration(
              hintText: 'Ví dụ: Tôi chưa nhận đủ hàng',
              counterText: '',
              errorMaxLines: 2,
              errorText: _showError ? 'Vui lòng nhập lý do khiếu nại' : null,
            ),
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('dispute_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          key: const Key('dispute_submit'),
          onPressed: _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('Gửi khiếu nại'),
        ),
      ],
    );
  }
}

/// Khung chờ của màn chi tiết: biểu ngữ trạng thái, thẻ số tiền, một thẻ nội dung.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          ShimmerLoadingWidget(height: 72, borderRadius: 18),
          SizedBox(height: 16),
          ShimmerLoadingWidget(height: 300, borderRadius: 20),
          SizedBox(height: 16),
          ShimmerLoadingWidget(height: 140, borderRadius: 18),
        ],
      );
}
