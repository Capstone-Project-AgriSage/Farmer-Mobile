import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../router/app_router.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/providers/cart_providers.dart';
import '../../catalog/widgets/product_image.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  /// Runs a cart change and reports a failure as a snack bar; the cart on screen stays as the server last said.
  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tất cả sản phẩm?'),
        content: const Text('Giỏ hàng sẽ được làm trống.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Giữ lại')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa tất cả')),
        ],
      ),
    );
    if (confirmed == true) await _run(() => ref.read(cartProvider.notifier).clear());
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = cartState.valueOrNull?.cart;
    final busy = cartState.valueOrNull?.busy ?? false;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        actions: [
          if (cart != null && !cart.isEmpty) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  '${cart.lineCount} sản phẩm',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Xóa tất cả',
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
              onPressed: busy ? null : _confirmClear,
            ),
          ],
          const SizedBox(width: 4),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: cartState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(cartProvider)),
        data: (state) => state.cart.isEmpty ? const _EmptyCart() : _buildCart(state),
      ),
    );
  }

  Widget _buildCart(CartState state) {
    final cart = state.cart;
    return Column(
      children: [
        // Banner: the app only places delivery orders.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFF0FDF4),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đơn đặt trên ứng dụng được giao tận nơi',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (cart.hasUnavailableItem)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusErrorSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppColors.statusError, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Một số sản phẩm không mua được lúc này. Bác hãy xóa chúng khỏi giỏ để tiếp tục thanh toán.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _run(() => ref.read(cartProvider.notifier).reload()),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                for (final line in cart.items) ...[
                  _CartLineTile(
                    line: line,
                    busy: state.busy,
                    onMinus: () => _run(() => ref.read(cartProvider.notifier).setQuantity(line.id, line.quantity - 1)),
                    onPlus: () => _run(() => ref.read(cartProvider.notifier).setQuantity(line.id, line.quantity + 1)),
                    onRemove: () => _run(() => ref.read(cartProvider.notifier).remove(line.id)),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tạm tính (${cart.lineCount} sản phẩm)',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            formatVnd(cart.subtotalAmount),
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Giá theo bảng giá hiện hành của cửa hàng, được tính lại khi Bác đặt hàng.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tạm tính', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    Text(
                      formatVnd(cart.subtotalAmount),
                      style: AppTextStyles.h3.copyWith(color: const Color(0xFF1B5E20)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: cart.canCheckout && !state.busy ? () => context.push(AppRoutes.orderConfirm) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20), // Dark green
                  disabledBackgroundColor: AppColors.borderStrong,
                  // The app theme makes buttons full width; in a Row that would be an infinite width.
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  children: [
                    Text('Tiếp tục thanh toán', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_basket_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Giỏ hàng đang trống', style: AppTextStyles.h4),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.products),
              child: const Text('Tiếp tục mua vật tư'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.busy,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  final CartLine line;
  final bool busy;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line.isAvailable ? AppColors.borderSubtle : AppColors.statusError.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64,
              height: 64,
              color: AppColors.surfaceSubtle,
              child: ProductImage(url: line.imageUrl, iconSize: 28),
            ),
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
                      child: Text(
                        line.productName,
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    InkWell(
                      onTap: busy ? null : onRemove,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(line.packagingName, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                if (!line.isAvailable)
                  Text(
                    unavailableReasonLabel(line.unavailableReason),
                    style: AppTextStyles.caption.copyWith(color: AppColors.statusError, fontWeight: FontWeight.w600),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatVnd(line.lineTotalAmount ?? 0),
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
                            ),
                            if (line.unitPrice != null)
                              Text(
                                '${formatVnd(line.unitPrice!)} / ${line.packagingName}',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Quantity control
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            _QuantityButton(
                              icon: Icons.remove,
                              onTap: (busy || line.quantity <= 1) ? null : onMinus,
                            ),
                            Container(
                              width: 32,
                              alignment: Alignment.center,
                              child: Text('${line.quantity}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                            ),
                            _QuantityButton(icon: Icons.add, onTap: busy ? null : onPlus),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.borderStrong : AppColors.textSecondary),
      ),
    );
  }
}
