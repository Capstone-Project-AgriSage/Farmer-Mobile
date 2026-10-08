import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/labels/order_labels.dart';
import '../../../core/labels/status_label.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vn_time.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../router/app_router.dart';
import '../../orders/data/delivery_models.dart';
import '../../orders/data/order_models.dart';
import '../../orders/providers/order_providers.dart';
import '../../payment/data/payment_models.dart';
import '../../payment/providers/payment_providers.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancel(Order order) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _CancelDialog());
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(orderActionsProvider).cancel(order.id, reason: reason);
      if (mounted) _say('Đã hủy đơn hàng ${order.orderNumber}.');
    } on AppException catch (error) {
      if (mounted) _say(error.message);
      // The order may have moved on (the store confirmed it a moment ago): show how it really is.
      ref.invalidate(orderDetailProvider(widget.orderId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(Order order) async {
    setState(() => _busy = true);
    try {
      final pending = await ref.read(paymentLauncherProvider).startOrderPayment(order.id);
      if (mounted) await context.push(AppRoutes.payosCheckout, extra: pending);
    } on AppException catch (error) {
      if (mounted) _say(error.message);
      // A 409 means a payment was just confirmed: reload so the farmer sees the current state.
      if (error.kind == AppErrorKind.conflict) ref.invalidate(orderDetailProvider(widget.orderId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) _say('Không mở được ứng dụng gọi điện.');
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.orderList);
            }
          },
        ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId))),
        data: _buildOrder,
      ),
    );
  }

  Widget _buildOrder(OrderDetail detail) {
    final order = detail.order;
    final closed = OrderStatus.isClosed(order.status);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(orderDetailProvider(widget.orderId));
        try {
          await ref.read(orderDetailProvider(widget.orderId).future);
        } catch (_) {
          // The screen shows its own error.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _Card(child: _header(detail)),
          const SizedBox(height: 16),
          if (!closed) ...[
            _Card(child: _tracking(detail)),
            const SizedBox(height: 16),
          ],
          _Card(child: _address(order)),
          const SizedBox(height: 16),
          _Card(child: _payment(detail)),
          const SizedBox(height: 16),
          _Card(child: _items(order)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _header(OrderDetail detail) {
    final order = detail.order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text('Mã đơn: ${order.orderNumber}', style: AppTextStyles.labelLarge)),
            const SizedBox(width: 8),
            StatusBadge(labelOf(orderStatusLabels, order.status)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Đặt lúc ${formatVnDateTime(order.createdAt)}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
        if (order.cancelReason != null) ...[
          const SizedBox(height: 8),
          Text('Lý do hủy: ${order.cancelReason}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
        ],
        if (detail.canCancel) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _cancel(order),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Hủy đơn hàng'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.statusError,
              side: BorderSide(color: AppColors.statusError.withValues(alpha: 0.4)),
              minimumSize: const Size(0, 44),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tracking ────────────────────────────────────────────────────────────
  static const _stepLabels = ['Chờ duyệt', 'Đóng gói', 'Đang giao', 'Hoàn thành'];

  static int _stepIndex(String status) => switch (status) {
        OrderStatus.pendingConfirmation || OrderStatus.confirmed => 0,
        OrderStatus.preparing => 1,
        OrderStatus.readyForFulfillment || OrderStatus.partiallyFulfilled => 2,
        OrderStatus.completed => 3,
        _ => -1,
      };

  Widget _tracking(OrderDetail detail) {
    final current = _stepIndex(detail.order.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.local_shipping_outlined, title: 'Trạng thái giao hàng'),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _stepLabels.length; i++)
              Expanded(child: _Step(label: _stepLabels[i], index: i, current: current, last: _stepLabels.length - 1)),
          ],
        ),
        const SizedBox(height: 16),
        if (detail.deliveriesFailed)
          Text('Chưa tải được thông tin giao hàng. Bác kéo xuống để tải lại.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted))
        else if (detail.deliveries.isNotEmpty)
          for (final delivery in detail.deliveries) ...[
            _DeliveryCard(delivery: delivery, onCall: _call),
            const SizedBox(height: 12),
          ]
        else if (const [OrderStatus.readyForFulfillment, OrderStatus.partiallyFulfilled].contains(detail.order.status))
          Text('Đơn hàng đang được chuẩn bị giao.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
        else
          Text('Cửa hàng sẽ cập nhật khi đơn được xác nhận và giao.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
      ],
    );
  }

  // ── Address ─────────────────────────────────────────────────────────────
  Widget _address(Order order) {
    final address = order.deliveryAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.location_on_outlined, title: 'Địa chỉ nhận hàng'),
        const SizedBox(height: 12),
        if (address == null)
          Text('Nhận tại cửa hàng', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))
        else ...[
          Text('${address.recipientName} | ${address.recipientPhone}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(address.fullAddress, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4)),
        ],
        if (order.note != null) ...[
          const SizedBox(height: 8),
          Text('Ghi chú: ${order.note}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  // ── Payment ─────────────────────────────────────────────────────────────
  Widget _payment(OrderDetail detail) {
    final order = detail.order;
    final summary = detail.payments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.payments_outlined, title: 'Thanh toán'),
        const SizedBox(height: 12),
        if (order.isCredit)
          Text(
            'Đơn mua ghi nợ: số tiền được ghi vào Sổ nợ sau khi cửa hàng giao hàng thành công.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          )
        else if (summary == null)
          Text('Không tải được thông tin thanh toán.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted))
        else
          Row(
            children: [
              Expanded(child: _Amount(label: 'Tổng đơn', value: formatVnd(summary.orderTotal))),
              Expanded(child: _Amount(label: 'Đã thanh toán', value: formatVnd(summary.paidAmount), color: AppColors.primary)),
              Expanded(
                // A cancelled order owes nothing, whatever the payment summary still computes.
                child: OrderStatus.isClosed(order.status)
                    ? const _Amount(label: 'Còn phải trả', value: '—')
                    : _Amount(
                        label: 'Còn phải trả',
                        value: formatVnd(summary.remainingToPay),
                        color: summary.remainingToPay > 0 ? const Color(0xFF92400E) : AppColors.textPrimary,
                      ),
              ),
            ],
          ),
        if (summary != null && summary.visiblePayments.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final payment in summary.visiblePayments) _PaymentRow(payment: payment),
        ],
        if (summary != null && summary.refunds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hoàn tiền', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                for (final refund in summary.refunds)
                  Text(
                    '${refund.refundNumber}: ${formatVnd(refund.amount)} — '
                    '${refund.isCompleted ? 'đã hoàn' : 'cửa hàng sẽ liên hệ hoàn tiền'}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
        if (detail.canPay) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : () => _pay(order),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.qr_code_2, size: 20),
            label: Text('Thanh toán ${formatVnd(summary!.remainingToPay)} qua payOS'),
          ),
        ],
      ],
    );
  }

  // ── Items ───────────────────────────────────────────────────────────────
  Widget _items(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.shopping_bag_outlined, title: 'Danh sách sản phẩm'),
        const SizedBox(height: 16),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${item.packagingName} • SL: ${item.quantity}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                      Text(formatVnd(item.unitPrice), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatVnd(item.lineTotalAmount), style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        const Divider(height: 1, color: AppColors.borderSubtle),
        const SizedBox(height: 12),
        _TotalRow('Tạm tính', formatVnd(order.subtotalAmount)),
        const SizedBox(height: 8),
        _TotalRow('Thành tiền', formatVnd(order.totalAmount), bold: true),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.labelLarge),
        ],
      );
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary)),
        ],
      );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold) : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          Text(value, style: bold ? AppTextStyles.h4.copyWith(color: AppColors.primary) : AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.index, required this.current, required this.last});

  final String label;
  final int index;
  final int current;
  final int last;

  @override
  Widget build(BuildContext context) {
    final passed = index < current;
    final isCurrent = index == current;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Container(height: 2, color: index == 0 ? Colors.transparent : ((passed || isCurrent) ? AppColors.primary : AppColors.borderSubtle))),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: passed ? AppColors.primary : (isCurrent ? AppColors.textPrimary : AppColors.surfaceSubtle),
                border: (!passed && !isCurrent) ? Border.all(color: AppColors.borderStrong, width: 2) : null,
              ),
              child: passed ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            Expanded(child: Container(height: 2, color: index == last ? Colors.transparent : (passed ? AppColors.primary : AppColors.borderSubtle))),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            fontWeight: (passed || isCurrent) ? FontWeight.w700 : FontWeight.w500,
            color: (passed || isCurrent) ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final PaymentListItem payment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.paymentNumber, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${paymentMethodLabel(payment.paymentMethod)} · ${formatVnDateTime(payment.when)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatVnd(payment.amount), style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              StatusBadge(labelOf(paymentStatusLabels, payment.status)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, required this.onCall});

  final MyDelivery delivery;
  final Future<void> Function(String phone) onCall;

  @override
  Widget build(BuildContext context) {
    final staff = delivery.assignedTo;
    final phone = staff?.phoneNumber;
    final failure = delivery.lastFailureReason;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: delivery.isRetryPending ? AppColors.statusErrorSurface.withValues(alpha: 0.5) : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: delivery.isRetryPending ? AppColors.statusError.withValues(alpha: 0.2) : AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(delivery.deliveryNumber, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              StatusBadge(labelOf(deliveryStatusLabels, delivery.status)),
            ],
          ),
          if (delivery.displayDate != null) ...[
            const SizedBox(height: 4),
            Text('Ngày: ${formatVnDate(delivery.displayDate)}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
          if (delivery.isRetryPending && failure != null) ...[
            const SizedBox(height: 8),
            Text(
              'Lần giao trước không thành công: ${failureReasonLabel(failure)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.statusError, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  staff == null ? 'Nhân viên giao: đang cập nhật' : 'Nhân viên giao: ${staff.fullName}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
              if (phone != null)
                TextButton.icon(
                  onPressed: () => onCall(phone),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text(phone),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
                ),
            ],
          ),
          const Divider(height: 20, color: AppColors.borderSubtle),
          Text('Sản phẩm đợt này', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final item in delivery.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('${item.productName} (${item.packagingName})', style: AppTextStyles.bodySmall)),
                  const SizedBox(width: 8),
                  Text(
                    item.deliveredQuantity > 0 ? '${item.deliveredQuantity}/${item.plannedQuantity}' : 'x${item.plannedQuantity}',
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          if (delivery.attempts.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.borderSubtle),
            Text('Các lần giao', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final attempt in delivery.attempts) _AttemptRow(attempt: attempt),
          ],
        ],
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt});
  final DeliveryAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final status = labelOf(attemptStatusLabels, attempt.status);
    final proof = attempt.proofImageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Lần ${attempt.attemptNumber}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    StatusBadge(status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formatVnDateTime(attempt.completedAt ?? attempt.startedAt),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                ),
                if (attempt.receiverName != null)
                  Text('Người nhận: ${attempt.receiverName}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                if (attempt.failureReasonCode != null)
                  Text('Lý do: ${failureReasonLabel(attempt.failureReasonCode)}', style: AppTextStyles.caption.copyWith(color: AppColors.statusError)),
              ],
            ),
          ),
          if (proof != null)
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  child: InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: proof,
                      placeholder: (_, __) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) => const SizedBox(height: 200, child: Center(child: Text('Không tải được ảnh'))),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CachedNetworkImage(
                    imageUrl: proof,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(color: AppColors.surfaceSubtle),
                    errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surfaceSubtle, child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Asks why, in words, and answers null if the farmer backs out. An empty reason is allowed.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hủy đơn hàng?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bác chắc chắn muốn hủy đơn này? Việc này không hoàn tác được.'),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLines: 2,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Lý do (không bắt buộc)', counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Giữ đơn')),
        TextButton(
          onPressed: () => Navigator.pop(context, _reason.text),
          child: const Text('Hủy đơn', style: TextStyle(color: AppColors.statusError)),
        ),
      ],
    );
  }
}
