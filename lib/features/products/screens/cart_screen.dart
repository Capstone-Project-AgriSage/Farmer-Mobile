import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../data/catalog_models.dart';
import '../data/catalog_repository.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_widgets.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  /// Dòng đang gửi lên server: khoá nút của dòng đó để khỏi bấm dồn.
  final Set<String> _busy = {};
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    // Giá có thể đã đổi từ lần xem trước: luôn lấy giỏ mới khi mở màn.
    Future.microtask(() => ref.read(cartProvider.notifier).refresh());
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _lineAction(String lineId, Future<void> Function() action) async {
    if (_busy.contains(lineId)) return;
    setState(() => _busy.add(lineId));
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(lineId));
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá toàn bộ giỏ hàng'),
        content: const Text('Bạn có chắc muốn xoá tất cả sản phẩm trong giỏ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ')),
          TextButton(
            key: const Key('cart_clear_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá tất cả',
                style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await ref.read(cartProvider.notifier).clear();
      if (mounted) _toast('Đã xoá toàn bộ giỏ hàng.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final cart = cartAsync.valueOrNull;
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        actions: [
          if (cart != null && !cart.isEmpty)
            TextButton(
              key: const Key('cart_clear'),
              onPressed: (_clearing || _busy.isNotEmpty) ? null : _confirmClear,
              style: TextButton.styleFrom(foregroundColor: AppColors.statusError),
              child: const Text('Xoá tất cả'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: cartAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerListWidget(itemCount: 3, itemHeight: 100),
        ),
        error: (e, _) => ErrorRetryWidget(error: e, onRetry: notifier.refresh),
        data: (cart) => cart.isEmpty
            ? EmptyDataWidget(
                message: 'Giỏ hàng của bạn đang trống.',
                fallbackIcon: Icons.shopping_cart_outlined,
                actionText: 'Xem sản phẩm',
                onActionPressed: () => context.go(AppRoutes.products),
              )
            : RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (cart.hasUnavailable)
                      Container(
                        key: const Key('cart_unavailable_banner'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusWarningSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.statusWarning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Có sản phẩm không thể đặt mua. Hãy xoá các sản phẩm này để tiếp tục.',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.statusWarning),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final line in cart.lines) ...[
                      _CartLineTile(
                        line: line,
                        busy: _busy.contains(line.id) || _clearing,
                        onQuantity: (q) => _lineAction(
                            line.id, () => notifier.setQuantity(line.id, q)),
                        onRemove: () =>
                            _lineAction(line.id, () => notifier.remove(line.id)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'Giá được tính theo bảng giá hiện hành mỗi khi bạn xem giỏ. '
                      'Giỏ hàng không giữ hàng; cửa hàng xác nhận còn hàng khi duyệt đơn.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: (cart == null || cart.isEmpty)
          ? null
          : _CheckoutBar(cart: cart, busy: _busy.isNotEmpty || _clearing),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.busy,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartLine line;
  final bool busy;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final available = line.isAvailable;
    return Opacity(
      opacity: available ? 1 : 0.75,
      child: Container(
        key: Key('cart_line_${line.id}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: available ? AppColors.borderSubtle : AppColors.statusWarning),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ProductImage(
                  url: line.imageUrl,
                  iconSize: 28,
                  borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(line.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ),
                      IconButton(
                        key: Key('cart_remove_${line.id}'),
                        tooltip: 'Xoá khỏi giỏ',
                        onPressed: busy ? null : onRemove,
                        icon: Icon(Icons.delete_outline,
                            size: 20,
                            color: available
                                ? AppColors.textMuted
                                : AppColors.statusError),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    available && line.unitPrice != null
                        ? '${line.packagingName} · ${formatVnd(line.unitPrice!)}'
                        : line.packagingName,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                  if (!available) ...[
                    const SizedBox(height: 4),
                    Text(CartUnavailableReason.label(line.unavailableReason),
                        key: Key('cart_reason_${line.id}'),
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.statusWarning,
                            fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      QuantityStepper(
                        key: Key('cart_qty_${line.id}'),
                        value: line.quantity,
                        max: CartRepository.maxQuantity,
                        enabled: available && !busy,
                        compact: true,
                        onChanged: onQuantity,
                      ),
                      if (busy)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Thành tiền trên một dòng riêng: số lớn trên màn hẹp vẫn đủ chỗ.
                  Row(
                    children: [
                      Text('Thành tiền',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            line.lineTotal == null
                                ? '—'
                                : formatVnd(line.lineTotal!),
                            key: Key('cart_total_${line.id}'),
                            maxLines: 1,
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart, required this.busy});

  final Cart cart;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tạm tính (${cart.lines.length} sản phẩm)',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  Text(formatVnd(cart.subtotal),
                      key: const Key('cart_subtotal'),
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.primaryDark)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              key: const Key('cart_checkout'),
              onPressed: (cart.canCheckout && !busy)
                  ? () => context.push(AppRoutes.orderConfirm)
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Đặt hàng'),
            ),
          ],
        ),
      ),
    );
  }
}
