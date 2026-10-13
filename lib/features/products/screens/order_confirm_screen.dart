import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/address.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../orders/data/order_models.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/providers/order_providers.dart';
import '../../orders/widgets/order_widgets.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/catalog_models.dart';
import '../providers/catalog_providers.dart';
import '../widgets/product_widgets.dart';
import '../../home/providers/home_providers.dart';
import '../../payment/providers/payment_providers.dart';
import '../../payment/widgets/payment_actions.dart';

/// Xác nhận đặt hàng (checkout) từ giỏ hàng hiện tại.
class OrderConfirmScreen extends ConsumerStatefulWidget {
  const OrderConfirmScreen({super.key});

  @override
  ConsumerState<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends ConsumerState<OrderConfirmScreen> {
  String _fulfillment = FulfillmentType.delivery;
  String _settlement = SettlementType.full;

  /// null = dùng địa chỉ mặc định.
  String? _addressId;
  final _noteCtrl = TextEditingController();
  bool _agreed = false;
  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Giá có thể đổi từ lúc xem giỏ: lấy giỏ mới nhất trước khi đặt (một lần).
    Future.microtask(() => ref.read(cartProvider.notifier).refresh());
    // Snackbar của màn trước (vd. "Đã thêm vào giỏ") không được che ô tick/nút đặt hàng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Address? _selectedAddress(List<Address> list) {
    if (list.isEmpty) return null;
    if (_addressId != null) {
      for (final a in list) {
        if (a.id == _addressId) return a;
      }
    }
    // Danh sách backend trả mặc định đứng đầu; không có mặc định thì chưa chọn.
    return list.first.isDefault ? list.first : null;
  }

  /// Lý do không mua ghi nợ được (null = được).
  String? _creditBlocker(AsyncValue<CreditSummary?> credit, double total) {
    if (credit.isLoading) return 'Đang kiểm tra hạn mức...';
    if (credit.hasError) return 'Không kiểm tra được hạn mức. Kéo xuống để thử lại.';
    final c = credit.valueOrNull;
    if (c == null) return 'Bạn chưa được cửa hàng cấp hạn mức mua ghi nợ.';
    if (!c.isActive) return 'Hạn mức mua ghi nợ của bạn đang tạm khoá.';
    if (c.availableCredit < total) {
      return 'Hạn mức còn lại ${formatVnd(c.availableCredit)} không đủ cho đơn này.';
    }
    return null;
  }

  Future<void> _pickAddress(List<Address> list) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddressPicker(
        addresses: list,
        selectedId: _selectedAddress(list)?.id,
      ),
    );
    if (!mounted || picked == null) return;
    if (picked == _AddressPicker.addNew) {
      await context.push('${AppRoutes.profile}/addresses/add');
      return;
    }
    setState(() => _addressId = picked);
  }

  /// Hình thức thanh toán thực tế: đang chọn ghi nợ mà hạn mức không còn đủ
  /// thì quay về "Trả ngay".
  String _resolveSettlement(AsyncValue<CreditSummary?> credit, double total) =>
      (_settlement == SettlementType.credit &&
              _creditBlocker(credit, total) != null)
          ? SettlementType.full
          : _settlement;

  Future<void> _submit(Cart cart, Address? address) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Sau `router.go` màn này bị huỷ nên không dùng `ref` được nữa: lấy sẵn.
    final launcher = ref.read(paymentLauncherProvider);
    try {
      final order = await ref.read(orderRepositoryProvider).checkout(
            settlementType:
                _resolveSettlement(ref.read(myCreditProvider), cart.subtotal),
            fulfillmentType: _fulfillment,
            addressId: address?.id,
            note: _noteCtrl.text,
          );
      // Giỏ đã chuyển thành đơn: tải lại (rỗng) và làm mới danh sách đơn.
      ref.read(cartProvider.notifier).refresh();
      invalidateOrders(ref);
      messenger.showSnackBar(
          SnackBar(content: Text('Đặt hàng thành công: ${order.orderNumber}')));
      router.go('/orders/${order.id}');
      // Đơn trả ngay giao tận nơi: cửa hàng chỉ xác nhận khi đã nhận đủ tiền.
      if (order.settlementType == SettlementType.full &&
          order.fulfillmentType == FulfillmentType.delivery) {
        await openPayosPayment(
          router: router,
          messenger: messenger,
          start: () => launcher.startOrderPayment(order.id),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Giỏ có thể đã thay đổi (dòng ngừng bán, giá...), hoặc đã thành đơn nếu chỉ mất phản hồi: đồng bộ lại.
      ref.read(cartProvider.notifier).refresh();
      if (e.kind == ApiErrorKind.timeout) {
        // Request đã đi nhưng mất câu trả lời: server có thể đã tạo đơn. KHÔNG mời đặt lại ngay
        // (dễ trùng đơn), chỉ sang mục Đơn hàng để kiểm tra. (Cách xử lý của nhánh feature/mobile-diagnosis.)
        invalidateOrders(ref);
        setState(() {
          _error = '';
          _submitting = false;
        });
        await _warnMaybeCreated(router);
        return;
      }
      setState(() => _error = e.message);
      if (e.statusCode == 404) ref.invalidate(addressesProvider);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _warnMaybeCreated(GoRouter router) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chưa nhận được phản hồi'),
          content: const Text(
            'Đơn hàng có thể đã được tạo. Bạn hãy vào mục Đơn hàng để kiểm tra trước khi đặt lại, '
            'tránh tạo đơn trùng.',
          ),
          actions: [
            TextButton(
              key: const Key('maybe_created_close'),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            TextButton(
              key: const Key('maybe_created_orders'),
              onPressed: () {
                Navigator.pop(ctx);
                router.go(AppRoutes.orderList);
              },
              child: const Text('Xem đơn hàng'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final addresses = ref.watch(addressesProvider);
    final credit = ref.watch(myCreditProvider);
    final cart = cartAsync.valueOrNull;

    final isDelivery = _fulfillment == FulfillmentType.delivery;
    final address = _selectedAddress(addresses.valueOrNull ?? const []);
    final total = cart?.subtotal ?? 0;
    final creditBlocker = _creditBlocker(credit, total);
    final settlement = _resolveSettlement(credit, total);
    final canSubmit = cart != null &&
        cart.canCheckout &&
        (!isDelivery || address != null) &&
        _agreed &&
        !_submitting;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Xác nhận đặt hàng'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(44),
          child: _CheckoutSteps(current: 1),
        ),
      ),
      body: cartAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryWidget(
            error: e, onRetry: () => ref.read(cartProvider.notifier).refresh()),
        data: (cart) => cart.isEmpty
            ? EmptyDataWidget(
                message: 'Giỏ hàng đang trống, chưa có gì để đặt.',
                fallbackIcon: Icons.shopping_cart_outlined,
                actionText: 'Xem sản phẩm',
                onActionPressed: () => context.go(AppRoutes.products),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myCreditProvider);
                  ref.invalidate(addressesProvider);
                  await ref.read(cartProvider.notifier).refresh();
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    SectionCard(
                      icon: Icons.local_shipping_outlined,
                      title: 'Hình thức nhận hàng',
                      child: Column(
                        children: [
                          _OptionTile(
                            key: const Key('opt_delivery'),
                            icon: Icons.local_shipping_outlined,
                            selected: isDelivery,
                            title: FulfillmentType.label(FulfillmentType.delivery),
                            subtitle: 'Cửa hàng giao đến địa chỉ của bạn.',
                            onTap: () => setState(
                                () => _fulfillment = FulfillmentType.delivery),
                          ),
                          const SizedBox(height: 8),
                          _OptionTile(
                            key: const Key('opt_pickup'),
                            icon: Icons.storefront_outlined,
                            selected: !isDelivery,
                            title: FulfillmentType.label(FulfillmentType.pickup),
                            subtitle: 'Bạn tự đến cửa hàng lấy hàng.',
                            onTap: () => setState(
                                () => _fulfillment = FulfillmentType.pickup),
                          ),
                        ],
                      ),
                    ),
                    if (isDelivery) ...[
                      const SizedBox(height: 12),
                      SectionCard(
                        icon: Icons.location_on_outlined,
                        title: 'Địa chỉ nhận hàng',
                        trailing: (addresses.valueOrNull?.isNotEmpty ?? false)
                            ? TextButton(
                                style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                key: const Key('address_change'),
                                onPressed: () =>
                                    _pickAddress(addresses.valueOrNull!),
                                child: Text(address == null ? 'Chọn' : 'Thay đổi'),
                              )
                            : null,
                        child: addresses.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))),
                          ),
                          error: (e, _) => Row(
                            children: [
                              Expanded(
                                  child: Text(ApiException.from(e).message,
                                      style: AppTextStyles.bodySmall)),
                              TextButton(
                                onPressed: () => ref.invalidate(addressesProvider),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                          data: (list) => list.isEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Bạn chưa có địa chỉ nhận hàng.',
                                        style: AppTextStyles.bodySmall),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      key: const Key('address_add_first'),
                                      onPressed: () => context
                                          .push('${AppRoutes.profile}/addresses/add'),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Thêm địa chỉ'),
                                    ),
                                  ],
                                )
                              : address == null
                                  ? Text('Chưa chọn địa chỉ. Bấm "Chọn" để chọn địa chỉ nhận hàng.',
                                      key: const Key('address_none'),
                                      style: AppTextStyles.bodySmall
                                          .copyWith(color: AppColors.statusWarning))
                                  : _AddressView(address),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SectionCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Sản phẩm (${cart.lines.length})',
                      child: Column(
                        children: [
                          for (final l in cart.lines) _CartLineSummary(l),
                          if (cart.hasUnavailable)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: AuthBanner(
                                        'Có sản phẩm không còn đặt được. Hãy xoá trong giỏ hàng.'),
                                  ),
                                  TextButton(
                                    onPressed: () => context.pop(),
                                    child: const Text('Về giỏ'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      icon: Icons.payments_outlined,
                      title: 'Thanh toán',
                      child: Column(
                        children: [
                          _OptionTile(
                            key: const Key('opt_full'),
                            icon: Icons.qr_code_2_rounded,
                            selected: settlement == SettlementType.full,
                            title: 'Trả ngay',
                            subtitle: isDelivery
                                ? 'Thanh toán online qua payOS (VietQR) ngay sau khi đặt. Cửa hàng xác nhận đơn khi đã nhận đủ tiền.'
                                : 'Thanh toán online qua payOS, hoặc trả tiền mặt khi nhận hàng tại cửa hàng.',
                            onTap: () => setState(
                                () => _settlement = SettlementType.full),
                          ),
                          const SizedBox(height: 8),
                          _OptionTile(
                            key: const Key('opt_credit'),
                            icon: Icons.account_balance_wallet_outlined,
                            selected: settlement == SettlementType.credit,
                            enabled: creditBlocker == null,
                            title: 'Mua ghi nợ',
                            subtitle: creditBlocker ??
                                'Hạn mức còn lại ${formatVnd(credit.valueOrNull!.availableCredit)}'
                                    '${credit.valueOrNull!.paymentTermDays == null ? '' : ' · trả trong ${credit.valueOrNull!.paymentTermDays} ngày'}.',
                            onTap: () => setState(
                                () => _settlement = SettlementType.credit),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      icon: Icons.edit_note,
                      title: 'Ghi chú cho cửa hàng (tuỳ chọn)',
                      child: TextField(
                        key: const Key('order_note'),
                        controller: _noteCtrl,
                        maxLines: 3,
                        minLines: 2,
                        maxLength: OrderRepository.maxNoteLength,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: Giao buổi sáng, gọi trước 15 phút...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: _agreed ? AppColors.primaryLight : AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color: _agreed ? AppColors.primary : AppColors.borderSubtle),
                      ),
                      child: InkWell(
                        key: const Key('order_agree'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _agreed,
                                onChanged: (v) => setState(() => _agreed = v ?? false),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Tôi đã kiểm tra thông tin đơn hàng. Giỏ hàng không giữ hàng; '
                                    'cửa hàng sẽ xác nhận còn hàng khi duyệt đơn.',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AuthBanner(_error),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: (cart == null || cart.isEmpty)
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tổng tiền',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(formatVnd(total),
                                key: const Key('checkout_total'),
                                style: AppTextStyles.h2
                                    .copyWith(color: AppColors.primaryDark)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      key: const Key('checkout_submit'),
                      onPressed:
                          canSubmit ? () => _submit(cart, address) : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Đặt hàng'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    super.key,
    required this.icon,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: active ? AppColors.primaryLight : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: active ? AppColors.primary : AppColors.borderSubtle,
            width: active ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: active ? AppColors.surface : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      size: 22, color: active ? AppColors.primary : AppColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.labelLarge.copyWith(
                              color: active ? AppColors.primaryDark : AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: enabled
                                  ? AppColors.textSecondary
                                  : AppColors.statusWarning)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  active ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 22,
                  color: active ? AppColors.primary : AppColors.borderStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressView extends StatelessWidget {
  const _AddressView(this.address);

  final Address address;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('address_selected'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${address.recipientName} · ${address.recipientPhone}',
              style: AppTextStyles.labelLarge),
          const SizedBox(height: 4),
          Text(address.fullAddress,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _CartLineSummary extends StatelessWidget {
  const _CartLineSummary(this.line);

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: ProductImage(
                url: line.imageUrl, iconSize: 20, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text('${line.packagingName} × ${line.quantity}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            line.lineTotal == null
                ? CartUnavailableReason.label(line.unavailableReason)
                : formatVnd(line.lineTotal!),
            style: AppTextStyles.labelLarge.copyWith(
                fontSize: 13,
                color: line.isAvailable ? AppColors.textPrimary : AppColors.statusWarning),
          ),
        ],
      ),
    );
  }
}

/// Thanh bước đơn giản dưới tiêu đề: Giỏ hàng → Xác nhận → Thanh toán.
class _CheckoutSteps extends StatelessWidget {
  const _CheckoutSteps({required this.current});

  /// 0 = giỏ hàng, 1 = xác nhận, 2 = thanh toán.
  final int current;

  static const _labels = ['Giỏ hàng', 'Xác nhận', 'Thanh toán'];

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) {
      final done = i < current;
      final active = i == current;
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done || active ? AppColors.primary : AppColors.surface,
          border: Border.all(
              color: done || active ? AppColors.primary : AppColors.borderStrong, width: 1.5),
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Text('${i + 1}',
                style: AppTextStyles.caption.copyWith(
                    color: active ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w700)),
      );
    }

    // Màn hẹp: chỉ ghi chữ cho bước hiện tại để vạch nối không bị dồn thành chấm.
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i <= current ? AppColors.primary : AppColors.borderSubtle,
                ),
              ),
            Semantics(
              label: '${_labels[i]}${i == current ? ' (bước hiện tại)' : ''}',
              child: dot(i),
            ),
            if (!narrow || i == current) ...[
              const SizedBox(width: 6),
              Text(_labels[i],
                  maxLines: 1,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: i <= current ? AppColors.primaryDark : AppColors.textMuted,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500)),
            ],
          ],
        ],
      ),
    );
  }
}

/// Bảng chọn địa chỉ. Trả về id địa chỉ, hoặc [addNew].
class _AddressPicker extends StatelessWidget {
  const _AddressPicker({required this.addresses, required this.selectedId});

  static const addNew = '__add_new__';

  final List<Address> addresses;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Chọn địa chỉ nhận hàng', style: AppTextStyles.h4),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final a in addresses)
                    ListTile(
                      key: Key('pick_${a.id}'),
                      leading: Icon(
                        a.id == selectedId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: a.id == selectedId
                            ? AppColors.primaryDark
                            : AppColors.textMuted,
                      ),
                      title: Text(
                          '${a.recipientName} · ${a.recipientPhone}${a.isDefault ? '  (Mặc định)' : ''}',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text(a.fullAddress,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary)),
                      onTap: () => Navigator.of(context).pop(a.id),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('pick_add_new'),
              leading: const Icon(Icons.add_location_alt_outlined,
                  color: AppColors.primary),
              title: const Text('Thêm địa chỉ mới'),
              onTap: () => Navigator.of(context).pop(addNew),
            ),
          ],
        ),
      ),
    );
  }
}
