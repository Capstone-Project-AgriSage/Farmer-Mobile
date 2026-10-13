import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../orders/data/order_models.dart';
import '../../orders/providers/order_providers.dart';
import '../../orders/widgets/order_widgets.dart';
import '../data/return_models.dart';
import '../data/return_repository.dart';
import '../providers/return_providers.dart';
import '../widgets/return_widgets.dart';

class ReturnDetailScreen extends ConsumerStatefulWidget {
  const ReturnDetailScreen({super.key, required this.returnId});

  final String returnId;

  @override
  ConsumerState<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends ConsumerState<ReturnDetailScreen> {
  bool _cancelling = false;

  Future<void> _refresh() async {
    ref.invalidate(returnDetailProvider(widget.returnId));
    ref.invalidate(myReturnsProvider);
    await ref
        .read(returnDetailProvider(widget.returnId).future)
        .then((_) {}, onError: (_) {});
  }

  Future<void> _cancel(ReturnDetail d) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(returnNumber: d.returnNumber),
    );
    if (reason == null || !mounted) return;
    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(returnRepositoryProvider).cancel(d.id, reason);
      if (!mounted) return;
      await _refresh();
      ref.invalidate(returnableProvider(d.orderId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã huỷ yêu cầu trả hàng.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      await _refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(returnDetailProvider(widget.returnId));
    final d = detail.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.returnList),
        ),
        title: const Text('Chi tiết trả hàng'),
      ),
      body: detail.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryWidget(
            error: e, onRetry: () => ref.invalidate(returnDetailProvider(widget.returnId))),
        data: (r) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _Header(detail: r),
              const SizedBox(height: 12),
              SectionCard(
                icon: Icons.timeline,
                title: 'TIẾN TRÌNH',
                child: ReturnTimeline(detail: r),
              ),
              const SizedBox(height: 12),
              _ItemsSection(detail: r),
              // Yêu cầu bị từ chối/huỷ thì không có tiền hoàn: ẩn cả mục để khỏi gây hiểu nhầm.
              if (!ReturnStatus.isFailed(r.status)) ...[
                const SizedBox(height: 12),
                _MoneySection(detail: r),
              ],
              if (r.refunds.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RefundsSection(refunds: r.refunds),
              ],
              if (_hasNotes(r)) ...[
                const SizedBox(height: 12),
                SectionCard(
                  icon: Icons.notes,
                  title: 'GHI CHÚ',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.note != null && r.note!.isNotEmpty)
                        Text(r.note!, style: AppTextStyles.bodySmall),
                      if (r.cancelReason != null && r.cancelReason!.isNotEmpty)
                        Text('Lý do huỷ: ${r.cancelReason}', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: d != null && d.canCancel
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('return_cancel'),
                    onPressed: _cancelling ? null : () => _cancel(d),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusError,
                      side: const BorderSide(color: AppColors.statusError),
                    ),
                    child: _cancelling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Huỷ yêu cầu trả hàng'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  bool _hasNotes(ReturnDetail r) =>
      (r.note?.isNotEmpty ?? false) || (r.cancelReason?.isNotEmpty ?? false);
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final ReturnDetail detail;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = ReturnStatus.colors(detail.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.returnNumber,
              style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(ReturnStatus.label(detail.status),
              key: const Key('return_status'),
              style: AppTextStyles.h3.copyWith(color: fg)),
          const SizedBox(height: 6),
          Text(ReturnStatus.hint(detail.status),
              style: AppTextStyles.bodySmall.copyWith(color: fg)),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('return_open_order'),
            onTap: () => context.push('/orders/${detail.orderId}'),
            child: Text('Đơn hàng ${detail.orderNumber} ›',
                style: AppTextStyles.bodySmall
                    .copyWith(color: fg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ItemsSection extends ConsumerWidget {
  const _ItemsSection({required this.detail});

  final ReturnDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tên sản phẩm lấy từ đơn hàng (yêu cầu trả hàng chỉ có mã dòng đơn).
    final lines = ref.watch(orderDetailProvider(detail.orderId)).valueOrNull?.items
            ?? const <OrderLine>[];
    OrderLine? line(String id) {
      for (final l in lines) {
        if (l.id == id) return l;
      }
      return null;
    }

    return SectionCard(
      icon: Icons.inventory_2_outlined,
      title: 'HÀNG TRẢ',
      child: Column(
        children: [
          for (var i = 0; i < detail.items.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.borderSubtle),
            _ItemRow(item: detail.items[i], line: line(detail.items[i].orderItemId)),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.line});

  final ReturnItem item;
  final OrderLine? line;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(line?.productName ?? 'Sản phẩm',
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(formatVnd(item.value),
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
            'Số lượng: ${formatReturnQty(item.baseQuantity, item.conversion, line?.packagingName)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        Text('Lý do: ${ReturnReason.label(item.reasonCode)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        if (item.inspected) ...[
          const SizedBox(height: 4),
          Text('Kết quả kiểm tra: ${conditionLabel(item.condition)}',
              key: Key('item_condition_${item.id}'),
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
          if (item.inspectionNote != null && item.inspectionNote!.isNotEmpty)
            Text('"${item.inspectionNote}"',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}

class _MoneySection extends StatelessWidget {
  const _MoneySection({required this.detail});

  final ReturnDetail detail;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.payments_outlined,
      title: 'TIỀN HOÀN LẠI',
      child: Column(
        children: [
          InfoRow('Giá trị hàng trả', formatVnd(detail.totalReturnAmount),
              valueKey: const Key('return_total')),
          if (detail.totalDebtAdjustment > 0)
            InfoRow('Trừ vào công nợ', formatVnd(detail.totalDebtAdjustment),
                valueKey: const Key('return_debt')),
          InfoRow('Cửa hàng hoàn lại cho bạn', formatVnd(detail.totalRefundAmount),
              bold: true, valueKey: const Key('return_refund')),
          if (detail.status != ReturnStatus.completed &&
              !ReturnStatus.isFailed(detail.status))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Số tiền hoàn chính thức được tính sau khi cửa hàng kiểm tra hàng. Nếu bạn còn nợ, cửa hàng trừ vào công nợ trước, phần còn lại hoàn bằng tiền.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _RefundsSection extends StatelessWidget {
  const _RefundsSection({required this.refunds});

  final List<ReturnRefund> refunds;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'CÁC LẦN HOÀN TIỀN',
      child: Column(
        children: [
          for (final r in refunds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${refundMethodLabel(r.method)} · ${refundStatusLabel(r.status)}',
                            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                            r.completedAt != null
                                ? formatDateTime(r.completedAt!)
                                : formatDateTime(r.requestedAt),
                            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        if (r.reference != null && r.reference!.isNotEmpty)
                          Text('Mã tham chiếu: ${r.reference}',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatVnd(r.amount),
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Hỏi lý do huỷ. Controller thuộc về dialog để không bị dispose sớm.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.returnNumber});

  final String returnNumber;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
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
      title: const Text('Huỷ yêu cầu trả hàng'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn muốn huỷ yêu cầu ${widget.returnNumber}?',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('return_cancel_reason'),
            controller: _controller,
            maxLines: 3,
            maxLength: ReturnRepository.maxTextLength,
            decoration: InputDecoration(
              hintText: 'Lý do huỷ',
              counterText: '',
              errorMaxLines: 2,
              errorText: _showError ? 'Vui lòng nhập lý do huỷ' : null,
            ),
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('return_cancel_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Không huỷ'),
        ),
        ElevatedButton(
          key: const Key('return_cancel_submit'),
          onPressed: _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('Huỷ yêu cầu'),
        ),
      ],
    );
  }
}
