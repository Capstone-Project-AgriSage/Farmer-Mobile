import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../../orders/providers/order_providers.dart';
import '../data/return_models.dart';
import '../data/return_repository.dart';
import '../providers/return_providers.dart';

/// Chọn hàng, số lượng và lý do để gửi yêu cầu trả hàng cho một đơn.
class ReturnRequestScreen extends ConsumerStatefulWidget {
  const ReturnRequestScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends ConsumerState<ReturnRequestScreen> {
  final _note = TextEditingController();
  final Map<String, int> _units = {};
  final Map<String, String?> _reasons = {};
  bool _submitting = false;
  bool _showReasonErrors = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<ReturnSelection> _selections(Returnable r) => [
        for (final i in r.available)
          if ((_units[i.orderItemId] ?? 0) > 0)
            ReturnSelection(i, _units[i.orderItemId]!, _reasons[i.orderItemId] ?? ''),
      ];

  Future<void> _submit(Returnable r) async {
    final picked = _selections(r);
    if (picked.isEmpty) return;
    if (picked.any((s) => s.reasonCode.isEmpty)) {
      setState(() {
        _showReasonErrors = true;
        _error = null;
      });
      return;
    }
    final lines = <ReturnLineRequest>[];
    for (final s in picked) {
      final part = ReturnLineRequest.allocate(s);
      if (part.isEmpty) {
        setState(() => _error =
            'Số lượng trả của "${s.item.productName}" không còn khả dụng. Vui lòng tải lại.');
        return;
      }
      lines.addAll(part);
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(returnRepositoryProvider)
          .create(orderId: widget.orderId, lines: lines, note: _note.text);
      if (!mounted) return;
      ref
        ..invalidate(returnableProvider(widget.orderId))
        ..invalidate(myReturnsProvider)
        ..invalidate(orderDetailProvider(widget.orderId));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu trả hàng cho cửa hàng.')));
      context.pushReplacement('/returns/${created.id}');
    } catch (error) {
      // Cả lỗi ngoài dự kiến (dữ liệu sai dạng...) cũng phải mở lại nút gửi.
      final e = ApiException.from(error);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      // Số liệu có thể đã đổi (vừa có yêu cầu khác): tải lại.
      if (e.statusCode == 422) ref.invalidate(returnableProvider(widget.orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final returnable = ref.watch(returnableProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Yêu cầu trả hàng')),
      body: returnable.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerLoadingWidget(height: 110, borderRadius: 18),
            SizedBox(height: 12),
            ShimmerLoadingWidget(height: 200, borderRadius: 18),
            SizedBox(height: 12),
            ShimmerLoadingWidget(height: 120, borderRadius: 18),
          ],
        ),
        error: (e, _) => ErrorRetryWidget(
            error: e, onRetry: () => ref.invalidate(returnableProvider(widget.orderId))),
        data: (r) => _content(r),
      ),
    );
  }

  Widget _content(Returnable r) {
    final items = r.available;
    if (items.isEmpty) {
      return const EmptyDataWidget(
        message:
            'Đơn hàng này chưa có hàng nào có thể trả.\nChỉ trả được hàng đã giao hoặc đã nhận, và chưa trả hết.',
        fallbackIcon: Icons.assignment_return_outlined,
      );
    }
    final names = ref.watch(orderDetailProvider(widget.orderId)).valueOrNull;
    String? packaging(String itemId) {
      for (final l in names?.items ?? const []) {
        if (l.id == itemId) return l.packagingName;
      }
      return null;
    }

    final picked = _selections(r);
    final total = picked.fold<double>(0, (a, s) => a + s.value);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Đơn ${r.orderNumber}. Chọn hàng muốn trả. Yêu cầu cần cửa hàng duyệt; sau khi duyệt, bạn mang hàng về cửa hàng để được kiểm tra và hoàn lại.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 16),
              for (final i in items) ...[
                _ItemCard(
                  item: i,
                  packaging: packaging(i.orderItemId),
                  units: _units[i.orderItemId] ?? 0,
                  reason: _reasons[i.orderItemId],
                  showReasonError: _showReasonErrors,
                  onUnits: (v) => setState(() {
                    _units[i.orderItemId] = v;
                    _error = null;
                  }),
                  onReason: (v) => setState(() => _reasons[i.orderItemId] = v),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              TextField(
                key: const Key('ret_note'),
                controller: _note,
                maxLines: 3,
                maxLength: ReturnRepository.maxTextLength,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú cho cửa hàng (tuỳ chọn)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('ret_error'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusErrorSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_error!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (picked.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Giá trị hàng trả (ước tính)',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                        ),
                        Text(formatVnd(total),
                            key: const Key('ret_total'),
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('ret_submit'),
                    onPressed: picked.isEmpty || _submitting ? null : () => _submit(r),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Gửi yêu cầu trả hàng'),
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

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.packaging,
    required this.units,
    required this.reason,
    required this.showReasonError,
    required this.onUnits,
    required this.onReason,
  });

  final ReturnableItem item;
  final String? packaging;
  final int units;
  final String? reason;
  final bool showReasonError;
  final ValueChanged<int> onUnits;
  final ValueChanged<String?> onReason;

  @override
  Widget build(BuildContext context) {
    final id = item.orderItemId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: units > 0 ? Border.all(color: AppColors.primary, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.productName,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Đã nhận ${formatReturnQty(item.fulfilled, item.conversion, packaging)} · '
            'có thể trả ${formatReturnQty(item.returnable, item.conversion, packaging)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          Text('Đơn giá ${formatVnd(item.unitPrice)}${packaging != null ? ' / $packaging' : ''}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          if (item.onlyFraction)
            Text(
              'Chỉ còn phần lẻ, không đủ một ${packaging ?? 'đơn vị bán'}. Vui lòng liên hệ cửa hàng để trả.',
              key: Key('ret_fraction_$id'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusWarning),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text('Số lượng trả',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                ),
                IconButton.outlined(
                  key: Key('ret_minus_$id'),
                  tooltip: 'Giảm',
                  onPressed: units > 0 ? () => onUnits(units - 1) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 44,
                  child: Text('$units',
                      key: Key('ret_qty_$id'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                ),
                IconButton.outlined(
                  key: Key('ret_plus_$id'),
                  tooltip: 'Tăng',
                  onPressed: units < item.maxUnits ? () => onUnits(units + 1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (units > 0) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: Key('ret_reason_$id'),
                initialValue: reason,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Lý do trả',
                  errorText: showReasonError && (reason == null || reason!.isEmpty)
                      ? 'Vui lòng chọn lý do'
                      : null,
                ),
                items: [
                  for (final c in ReturnReason.all)
                    DropdownMenuItem(value: c, child: Text(ReturnReason.label(c))),
                ],
                onChanged: onReason,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
