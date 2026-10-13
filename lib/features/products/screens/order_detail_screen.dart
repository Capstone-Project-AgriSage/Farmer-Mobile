import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../orders/data/order_models.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/providers/order_providers.dart';
import '../../orders/widgets/order_widgets.dart';
import '../../home/providers/home_providers.dart';
import '../../payment/providers/payment_providers.dart';
import '../../payment/widgets/payment_actions.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _cancelling = false;

  String get _id => widget.orderId;

  Future<void> _refreshAll() async {
    ref.invalidate(orderPaymentsProvider(_id));
    ref.invalidate(orderDeliveriesProvider(_id));
    ref.invalidate(orderDetailProvider(_id));
    try {
      await ref.read(orderDetailProvider(_id).future);
    } on Object {
      // Lỗi đã hiện ở màn hình (ErrorRetryWidget); ở đây chỉ chờ tải xong.
    }
  }

  Future<void> _cancel(OrderDetail order, OrderPayments? payments) async {
    // Hộp thoại tự quản controller (dispose sau khi hiệu ứng đóng kết thúc).
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(
          orderNumber: order.orderNumber, paidAmount: payments?.paidAmount ?? 0),
    );
    final ok = reason != null;
    if (!ok || !mounted) return;

    setState(() => _cancelling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orderRepositoryProvider).cancel(_id, reason: reason);
      invalidateOrders(ref);
      await _refreshAll();
      final refunded = (payments?.paidAmount ?? 0) > 0;
      messenger.showSnackBar(SnackBar(
        content: Text(refunded
            ? 'Đã huỷ đơn. Cửa hàng sẽ liên hệ hoàn tiền.'
            : 'Đã huỷ đơn hàng.'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      await _refreshAll();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(orderDetailProvider(_id));
    final payments = ref.watch(orderPaymentsProvider(_id));
    final order = detail.valueOrNull;
    final pay = payments.valueOrNull;

    final canPay = order != null &&
        !order.isCredit &&
        OrderStatus.canPay(order.status) &&
        pay != null &&
        !pay.isFullyPaid;
    final canCancel = order != null && OrderStatus.canCancel(order.status);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.orderList),
        ),
        title: const Text('Chi tiết đơn hàng'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: detail.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryWidget(
            error: e, onRetry: () => ref.invalidate(orderDetailProvider(_id))),
        data: (o) => RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _Header(order: o, payments: pay),
              const SizedBox(height: 12),
              _InfoSection(order: o),
              const SizedBox(height: 12),
              _ItemsSection(order: o),
              const SizedBox(height: 12),
              _PaymentSection(order: o, payments: payments),
              if (o.isDelivery) ...[
                const SizedBox(height: 12),
                _DeliverySection(orderId: _id),
              ],
              if (OrderStatus.canReturn(o.status)) ...[
                const SizedBox(height: 12),
                _ReturnSection(orderId: _id),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: (!canPay && !canCancel)
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -6)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (canCancel)
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          key: const Key('order_cancel'),
                          onPressed: _cancelling ? null : () => _cancel(order, pay),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.statusError,
                            side: const BorderSide(color: AppColors.statusError),
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _cancelling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const FittedBox(
                                  fit: BoxFit.scaleDown, child: Text('Huỷ đơn', maxLines: 1)),
                        ),
                      ),
                    if (canCancel && canPay) const SizedBox(width: 12),
                    if (canPay)
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          key: const Key('order_pay'),
                          onPressed: _cancelling
                              ? null
                              : () async {
                                  await openPayosPayment(
                                    router: GoRouter.of(context),
                                    messenger: ScaffoldMessenger.of(context),
                                    start: () => ref
                                        .read(paymentLauncherProvider)
                                        .startOrderPayment(order.id),
                                  );
                                  if (mounted) _refreshAll();
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Thanh toán ${formatVnd(pay.remainingToPay)}'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Lối vào trả hàng: chỉ hiện khi đơn đã có hàng giao/nhận.
class _ReturnSection extends StatelessWidget {
  const _ReturnSection({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.assignment_return_outlined,
      title: 'Trả hàng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hàng nhận được có vấn đề? Bạn có thể gửi yêu cầu trả hàng cho cửa hàng.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('order_return'),
              onPressed: () => context.push('/orders/$orderId/return'),
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Yêu cầu trả hàng'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('order_return_list'),
              onPressed: () => context.push('/returns'),
              child: const Text('Xem các yêu cầu đã gửi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.payments});

  final OrderDetail order;
  final OrderPayments? payments;

  @override
  Widget build(BuildContext context) {
    String? hint;
    Color hintColor = AppColors.textSecondary;
    final unpaid = payments != null && !payments!.isFullyPaid;
    if (order.status == OrderStatus.pending) {
      if (!order.isCredit && unpaid && order.isDelivery) {
        hint = 'Đơn đang chờ thanh toán. Cửa hàng chỉ xác nhận đơn khi đã nhận đủ tiền.';
        hintColor = AppColors.statusWarning;
      } else if (!order.isCredit && unpaid) {
        hint = 'Bạn có thể thanh toán online ngay, hoặc trả tiền mặt khi nhận hàng tại cửa hàng.';
      } else {
        hint = 'Đơn đang chờ cửa hàng xác nhận.';
      }
    } else if (order.status == OrderStatus.cancelled) {
      final reason = order.cancelReason?.trim();
      hint = (reason == null || reason.isEmpty)
          ? 'Đơn đã bị huỷ.'
          : 'Đơn đã bị huỷ: ${OrderStatus.cancelReasonLabel(reason)}';
      hintColor = AppColors.statusError;
    }

    final (statusFg, statusBg) = OrderStatus.colors(order.status);
    final cancelled = order.status == OrderStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                    order.isDelivery
                        ? Icons.local_shipping_outlined
                        : Icons.storefront_outlined,
                    color: statusFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber,
                        key: const Key('order_number'),
                        style: AppTextStyles.h4),
                    Text('Đặt lúc ${formatDateTime(order.createdAt)}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    OrderStatusBadge(order.status),
                  ],
                ),
              ),
            ],
          ),
          // Đơn đã huỷ không có tiến trình: chỉ hiện khung đỏ (ở lời nhắc bên dưới).
          if (!cancelled) ...[
            const SizedBox(height: 18),
            _StatusTimeline(order: order),
          ],
          if (hint != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hintColor == AppColors.textSecondary
                    ? AppColors.surfaceSubtle
                    : hintColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(cancelled ? Icons.cancel_outlined : Icons.info_outline_rounded,
                      size: 18,
                      color: hintColor == AppColors.textSecondary
                          ? AppColors.textMuted
                          : hintColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(hint,
                        key: const Key('order_hint'),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: hintColor, fontSize: 13)),
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

/// Tiến trình đơn: Đặt hàng → Xác nhận → Chuẩn bị → Giao/nhận → Hoàn thành.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});

  final OrderDetail order;

  /// Bước cuối cùng ĐÃ đạt (0..4).
  static int reached(String status) => switch (status) {
        OrderStatus.pending => 0,
        OrderStatus.confirmed => 1,
        OrderStatus.preparing => 2,
        OrderStatus.ready || OrderStatus.partiallyFulfilled => 3,
        _ => 4, // hoàn thành, huỷ phần còn lại
      };

  @override
  Widget build(BuildContext context) {
    final s = order.status;
    final done = reached(s);
    final labels = [
      'Đặt hàng',
      'Xác nhận',
      'Chuẩn bị',
      s == OrderStatus.partiallyFulfilled
          ? 'Giao một phần'
          : order.isDelivery
              ? 'Giao hàng'
              : 'Sẵn sàng nhận',
      s == OrderStatus.partiallyCancelled ? 'Huỷ phần còn lại' : 'Hoàn thành',
    ];
    // Bước cuối của đơn "huỷ phần còn lại" tô cam để không nhầm với hoàn thành trọn vẹn.
    final endColor =
        s == OrderStatus.partiallyCancelled ? AppColors.statusWarning : AppColors.primary;

    return Semantics(
      label: 'Tiến trình đơn: ${labels[done]}',
      excludeSemantics: true,
      child: Row(
        key: const Key('order_timeline'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= done ? AppColors.primary : AppColors.borderSubtle),
                        ),
                      ),
                      _dot(i, done, i == labels.length - 1 ? endColor : AppColors.primary),
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == labels.length - 1
                              ? Colors.transparent
                              : (i < done ? AppColors.primary : AppColors.borderSubtle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Chừa lề 2px mỗi bên để nhãn các bước không dính nhau trên màn hẹp.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            height: 1.3,
                            color: i <= done ? AppColors.textPrimary : AppColors.textMuted,
                            fontWeight: i == done ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(int i, int done, Color color) {
    final passed = i < done;
    final current = i == done;
    // Khung cố định 22px để nhãn các bước luôn thẳng hàng dù chấm hiện tại to hơn.
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(child: _dotCircle(passed, current, color)),
    );
  }

  Widget _dotCircle(bool passed, bool current, Color color) {
    return Container(
      width: current ? 22 : 18,
      height: current ? 22 : 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: passed || current ? color : AppColors.surface,
        border: Border.all(
            color: passed || current ? color : AppColors.borderStrong, width: 2),
        boxShadow: current
            ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
            : null,
      ),
      child: passed || current
          ? Icon(Icons.check_rounded, size: current ? 14 : 12, color: Colors.white)
          : null,
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final a = order.address;
    return SectionCard(
      icon: order.isDelivery
          ? Icons.local_shipping_outlined
          : Icons.storefront_outlined,
      title: 'Thông tin đơn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoRow('Nhận hàng', FulfillmentType.label(order.fulfillmentType)),
          InfoRow(
              'Thanh toán',
              order.isCredit && order.creditTermDays != null
                  ? '${SettlementType.label(order.settlementType)} · ${order.creditTermDays} ngày'
                  : SettlementType.label(order.settlementType)),
          if (order.confirmedAt != null)
            InfoRow('Xác nhận lúc', formatDateTime(order.confirmedAt!)),
          if (order.completedAt != null)
            InfoRow('Hoàn thành lúc', formatDateTime(order.completedAt!)),
          if (a != null) ...[
            const Divider(height: 20, color: AppColors.borderSubtle),
            Text('${a.recipientName} · ${a.recipientPhone}',
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(a.fullAddress,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
          if (order.note != null && order.note!.trim().isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.borderSubtle),
            Text('Ghi chú: ${order.note}',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Sản phẩm (${order.items.length})',
      child: Column(
        children: [
          for (final l in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.productName,
                            style: AppTextStyles.bodySmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text('${l.packagingName} × ${l.quantity} · ${formatVnd(l.unitPrice)}',
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
          const Divider(height: 20, color: AppColors.borderSubtle),
          InfoRow('Tổng tiền', formatVnd(order.totalAmount),
              bold: true,
              valueColor: AppColors.primaryDark,
              valueKey: const Key('order_total')),
        ],
      ),
    );
  }
}

class _PaymentSection extends ConsumerWidget {
  const _PaymentSection({required this.order, required this.payments});

  final OrderDetail order;
  final AsyncValue<OrderPayments> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelled = order.status == OrderStatus.cancelled;
    return SectionCard(
      icon: Icons.payments_outlined,
      title: 'Thanh toán',
      child: payments.when(
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        error: (e, _) => Row(
          children: [
            Expanded(
                child: Text(ApiException.from(e).message,
                    style: AppTextStyles.bodySmall)),
            TextButton(
              onPressed: () => ref.invalidate(orderPaymentsProvider(order.id)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.isCredit)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Đơn mua ghi nợ: khoản nợ được ghi khi cửa hàng giao hàng; bạn trả nợ ở mục Công nợ.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            if (!order.isCredit && p.orderTotal > 0 && !cancelled) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  key: const Key('pay_progress'),
                  value: (p.paidAmount / p.orderTotal).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceSecondary,
                  color: p.isFullyPaid ? AppColors.statusSuccess : AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
            ],
            InfoRow('Đã thanh toán', formatVnd(p.paidAmount),
                valueKey: const Key('pay_paid')),
            // Đơn đã huỷ không còn nợ gì, dù bảng tính thanh toán của server vẫn ra số còn lại.
            if (cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Đơn đã huỷ, bạn không cần thanh toán thêm.',
                    key: const Key('pay_cancelled_note'),
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              )
            else
              InfoRow('Còn phải trả', formatVnd(p.remainingToPay),
                  valueKey: const Key('pay_remaining'),
                  valueColor: p.isFullyPaid
                      ? AppColors.statusSuccess
                      : AppColors.statusWarning),
            if (p.payments.isNotEmpty) ...[
              const Divider(height: 20, color: AppColors.borderSubtle),
              for (final item in p.payments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${PaymentMethod.label(item.method)} · ${formatVnd(item.amount)}',
                                style: AppTextStyles.bodySmall
                                    .copyWith(fontWeight: FontWeight.w600)),
                            Text(
                                '${item.paymentNumber} · ${formatDateTime(item.confirmedAt ?? item.initiatedAt)}',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      _PaymentStatusChip(item.status),
                    ],
                  ),
                ),
            ],
            if (p.refundCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Có ${p.refundCount} khoản hoàn tiền. Cửa hàng sẽ liên hệ để hoàn tiền cho bạn.',
                  key: const Key('pay_refund_note'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  const _PaymentStatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      PaymentStatus.paid => (AppColors.statusSuccess, AppColors.statusSuccessSurface),
      PaymentStatus.pending => (AppColors.statusWarning, AppColors.statusWarningSurface),
      _ => (AppColors.textMuted, AppColors.surfaceSecondary),
    };
    return StatusChip(text: PaymentStatus.label(status), fg: fg, bg: bg);
  }
}

class _DeliverySection extends ConsumerWidget {
  const _DeliverySection({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(orderDeliveriesProvider(orderId));
    return SectionCard(
      icon: Icons.route_outlined,
      title: 'Theo dõi giao hàng',
      child: deliveries.when(
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        error: (e, _) => Row(
          children: [
            Expanded(
                child: Text(ApiException.from(e).message,
                    style: AppTextStyles.bodySmall)),
            TextButton(
              onPressed: () => ref.invalidate(orderDeliveriesProvider(orderId)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (list) => list.isEmpty
            ? Text('Cửa hàng chưa lập phiếu giao cho đơn này.',
                key: const Key('delivery_empty'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))
            : Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 24, color: AppColors.borderSubtle),
                    _DeliveryView(list[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class _DeliveryView extends StatelessWidget {
  const _DeliveryView(this.d);

  final Delivery d;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (d.status) {
      'DELIVERED' => (AppColors.statusSuccess, AppColors.statusSuccessSurface),
      'CANCELLED' => (AppColors.statusError, AppColors.statusErrorSurface),
      'RETRY_PENDING' => (AppColors.statusWarning, AppColors.statusWarningSurface),
      _ => (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
    };
    return Column(
      key: Key('delivery_${d.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(d.deliveryNumber,
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
            ),
            StatusChip(text: DeliveryStatus.label(d.status), fg: fg, bg: bg),
          ],
        ),
        if (d.scheduledAt != null)
          InfoRow('Hẹn giao', formatDateTime(d.scheduledAt!)),
        if (d.dispatchedAt != null)
          InfoRow('Xuất phát', formatDateTime(d.dispatchedAt!)),
        if (d.completedAt != null)
          InfoRow('Hoàn tất', formatDateTime(d.completedAt!)),
        if (d.driverName != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tài xế: ${d.driverName}${d.driverPhone == null ? '' : ' · ${d.driverPhone}'}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                if (d.driverPhone != null)
                  IconButton(
                    key: Key('call_${d.id}'),
                    tooltip: 'Gọi tài xế',
                    icon: const Icon(Icons.call, color: AppColors.primary),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: d.driverPhone)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        for (final l in d.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '• ${l.productName} (${l.packagingName}): đã giao ${l.delivered}/${l.planned}'
              '${l.remaining > 0 ? ' · còn ${l.remaining}' : ''}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        for (final a in d.attempts)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lần ${a.number}: ${DeliveryStatus.attemptLabel(a.status)}',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(formatDateTime(a.completedAt ?? a.startedAt),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textMuted)),
                      if (a.failureReasonCode != null)
                        Text('Lý do: ${DeliveryStatus.failureLabel(a.failureReasonCode!)}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.statusWarning)),
                      if (a.receiverName != null)
                        Text('Người nhận: ${a.receiverName}',
                            style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (a.proofImageUrl != null)
                  GestureDetector(
                    key: Key('proof_${d.id}_${a.number}'),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: CachedNetworkImage(imageUrl: a.proofImageUrl!),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: a.proofImageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Hộp thoại xác nhận huỷ đơn. Trả về lý do (có thể rỗng); null = không huỷ.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.orderNumber, required this.paidAmount});

  final String orderNumber;
  final double paidAmount;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Huỷ đơn hàng'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bạn có chắc muốn huỷ đơn ${widget.orderNumber}?'),
          if (widget.paidAmount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Đơn đã thanh toán ${formatVnd(widget.paidAmount)}. Cửa hàng sẽ liên hệ để hoàn tiền.',
              style: AppTextStyles.caption.copyWith(color: AppColors.statusWarning),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('cancel_reason'),
            controller: _ctrl,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Lý do (không bắt buộc)'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Không')),
        TextButton(
          key: const Key('cancel_confirm'),
          onPressed: () => Navigator.of(context).pop(_ctrl.text),
          child: const Text('Huỷ đơn', style: TextStyle(color: AppColors.statusError)),
        ),
      ],
    );
  }
}
