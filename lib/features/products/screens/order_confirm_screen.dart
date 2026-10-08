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
import '../../credit/data/credit_models.dart';
import '../../credit/providers/credit_providers.dart';
import '../../orders/data/order_models.dart';
import '../../orders/providers/checkout_providers.dart';
import '../../profile/data/address_models.dart';
import '../../profile/providers/address_providers.dart';
import '../../profile/widgets/address_form.dart';

/// Thanh toán: địa chỉ giao hàng, phương thức (payOS hoặc ghi nợ), ghi chú, rồi đặt hàng.
class OrderConfirmScreen extends ConsumerStatefulWidget {
  const OrderConfirmScreen({super.key});
  @override
  ConsumerState<OrderConfirmScreen> createState() => _OrderConfirmScreenState();
}

class _OrderConfirmScreenState extends ConsumerState<OrderConfirmScreen> {
  String? _addressId;
  bool _creditSelected = false;
  bool _isChecked = false;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Address? _selected(List<Address> addresses) {
    for (final a in addresses) {
      if (a.id == _addressId) return a;
    }
    return addresses.firstOrNull; // the list is sorted default-first
  }

  Future<void> _chooseAddress(List<Address> addresses, Address? current) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _AddressPicker(addresses: addresses, selectedId: current?.id),
    );
    if (!mounted || choice == null) return;
    if (choice == _AddressPicker.addNew) {
      await _addAddress(makeDefault: addresses.isEmpty);
    } else if (choice is Address) {
      setState(() => _addressId = choice.id);
    }
  }

  Future<void> _addAddress({required bool makeDefault}) async {
    final created = await showNewAddressSheet(context, makeDefault: makeDefault);
    if (created != null && mounted) setState(() => _addressId = created.id);
  }

  Future<void> _submit({required Address address, required bool useCredit}) async {
    final order = await ref.read(checkoutProvider.notifier).place(
          CheckoutInput(
            settlementType: useCredit ? SettlementType.credit : SettlementType.fullPayment,
            addressId: address.id,
            note: _noteCtrl.text,
          ),
        );
    if (!mounted) return;
    if (order != null) {
      context.go(AppRoutes.orderSuccess, extra: order);
      return;
    }

    final error = ref.read(checkoutProvider).error;
    if (error is! AppException) return;
    if (error.outcomeUnknown) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Chưa nhận được phản hồi'),
          content: const Text(
            'Đơn hàng có thể đã được tạo. Bác hãy vào mục Đơn hàng để kiểm tra trước khi đặt lại, '
            'tránh tạo đơn trùng.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(AppRoutes.orderList);
              },
              child: const Text('Xem đơn hàng'),
            ),
          ],
        ),
      );
      return;
    }

    if (useCredit) {
      // The server refused credit for a reason the app could not know in advance: go back to payOS.
      setState(() => _creditSelected = false);
      ref.invalidate(myCreditProvider);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.message)));
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final addressesAsync = ref.watch(addressBookProvider);
    final creditAsync = ref.watch(myCreditProvider);
    final submitting = ref.watch(checkoutProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Thanh toán'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
              child: Text('Bảo mật', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: cartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(cartProvider)),
        data: (state) {
          final cart = state.cart;
          if (cart.isEmpty) return const _NothingToPay();

          final addresses = addressesAsync.valueOrNull ?? const <Address>[];
          final address = _selected(addresses);
          final credit = creditAsync.valueOrNull;
          final creditLoaded = creditAsync.hasValue;
          final choice = creditLoaded ? creditChoiceFor(credit, cart.subtotalAmount) : null;
          final useCredit = _creditSelected && choice == CreditChoice.available;
          final canOrder = cart.canCheckout && address != null && _isChecked && !submitting;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        icon: Icons.location_on_outlined,
                        title: 'THÔNG TIN NHẬN HÀNG',
                        actionText: (address != null) ? 'Thay đổi' : null,
                        onAction: address == null ? null : () => _chooseAddress(addresses, address),
                      ),
                      const SizedBox(height: 12),
                      _buildAddressCard(addressesAsync, address),
                      const SizedBox(height: 24),
                      const _SectionHeader(icon: Icons.edit_note, title: 'GHI CHÚ CHO CỬA HÀNG (không bắt buộc)'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            // The theme gives inputs their own border and fill; this one sits inside a bordered card.
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            counterText: '',
                            hintText: 'Ví dụ: Giao buổi sáng, gọi trước khi đến...',
                            hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionHeader(icon: Icons.receipt_long_outlined, title: 'ĐƠN HÀNG'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              '${cart.lineCount} sản phẩm',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildItems(cart),
                      const SizedBox(height: 24),
                      const _SectionHeader(icon: Icons.payments_outlined, title: 'PHƯƠNG THỨC THANH TOÁN'),
                      const SizedBox(height: 12),
                      _buildPaymentMethods(
                        creditChecked: creditLoaded || creditAsync.hasError,
                        choice: creditAsync.hasError ? CreditChoice.noProfile : choice,
                        credit: credit,
                        creditUnknown: creditAsync.hasError,
                        useCredit: useCredit,
                      ),
                      const SizedBox(height: 24),
                      // Checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isChecked,
                              onChanged: (val) => setState(() => _isChecked = val ?? false),
                              activeColor: const Color(0xFF1B5E20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tôi đã kiểm tra thông tin đơn hàng và đồng ý tiếp tục.',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Bottom Bar
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
                          Text('Tổng thanh toán', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                          Text(formatVnd(cart.subtotalAmount), style: AppTextStyles.h3.copyWith(color: const Color(0xFF1B5E20))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: canOrder ? () => _submit(address: address, useCredit: useCredit) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20), // Dark green
                        disabledBackgroundColor: Colors.grey.shade300,
                        // The app theme makes buttons full width; in a Row that would be an infinite width.
                        minimumSize: const Size(0, 50),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              children: [
                                Text('Đặt hàng', style: TextStyle(color: canOrder ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward, color: canOrder ? Colors.white : Colors.grey.shade500, size: 18),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddressCard(AsyncValue<List<Address>> addressesAsync, Address? address) {
    return addressesAsync.when(
      loading: () => const _CardBox(child: Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))),
      error: (error, _) => _CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(messageOf(error), style: AppTextStyles.bodySmall.copyWith(color: AppColors.statusError)),
            TextButton(onPressed: () => ref.invalidate(addressBookProvider), child: const Text('Thử lại')),
          ],
        ),
      ),
      data: (addresses) {
        if (address == null) {
          return _CardBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bác chưa có địa chỉ giao hàng.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _addAddress(makeDefault: true),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Thêm địa chỉ giao hàng'),
                ),
              ],
            ),
          );
        }
        return _CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(address.recipientName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(address.recipientPhone, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(address.fullAddress, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _Tag(text: AddressType.label(address.addressType)),
                  if (address.isDefault) const _Tag(text: 'Mặc định', highlighted: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItems(Cart cart) {
    return _CardBox(
      child: Column(
        children: [
          for (final line in cart.items) ...[
            _OrderLine(line: line),
            const SizedBox(height: 16),
          ],
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 16),
          _SummaryRow('Tạm tính', formatVnd(cart.subtotalAmount)),
          const SizedBox(height: 12),
          _SummaryRow('Tổng thanh toán', formatVnd(cart.subtotalAmount), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods({
    required bool creditChecked,
    required CreditChoice? choice,
    required MyCredit? credit,
    required bool creditUnknown,
    required bool useCredit,
  }) {
    final creditEnabled = choice == CreditChoice.available;
    final creditNote = switch (choice) {
      CreditChoice.available => 'Cửa hàng giao trước, khoản nợ ghi vào Sổ nợ của Bác sau khi giao thành công. '
          'Hạn mức còn lại: ${formatVnd(credit?.availableCredit ?? 0)}.',
      CreditChoice.noProfile => creditUnknown
          ? 'Chưa kiểm tra được hạn mức ghi nợ. Bác thử lại sau hoặc chọn payOS.'
          : 'Bác chưa có hạn mức mua ghi nợ ở cửa hàng.',
      CreditChoice.notActive => 'Hạn mức ghi nợ của Bác đang tạm khóa.',
      CreditChoice.notEnough =>
        'Hạn mức còn lại ${formatVnd(credit?.availableCredit ?? 0)}, chưa đủ cho đơn này.',
      null => 'Đang kiểm tra hạn mức...',
    };

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderSubtle)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _PaymentOption(
            selected: !useCredit,
            enabled: true,
            title: 'Thanh toán qua payOS',
            subtitle: 'Trả ngay bằng quét mã VietQR trong app ngân hàng. Cửa hàng xác nhận đơn sau khi nhận được tiền.',
            badge: 'Khuyên dùng',
            onTap: () => setState(() => _creditSelected = false),
          ),
          const SizedBox(height: 12),
          _PaymentOption(
            selected: useCredit,
            enabled: creditEnabled,
            title: 'Mua hàng ghi nợ',
            subtitle: creditNote,
            badge: creditEnabled ? 'Trả sau' : null,
            onTap: creditEnabled ? () => setState(() => _creditSelected = true) : null,
          ),
        ],
      ),
    );
  }
}

class _NothingToPay extends StatelessWidget {
  const _NothingToPay();

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
            ElevatedButton(onPressed: () => context.go(AppRoutes.products), child: const Text('Tiếp tục mua vật tư')),
          ],
        ),
      ),
    );
  }
}

class _AddressPicker extends StatelessWidget {
  const _AddressPicker({required this.addresses, required this.selectedId});

  /// The sheet pops this when the farmer wants a new address.
  static const addNew = 'add-new';

  final List<Address> addresses;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final full = addresses.length >= Address.maxPerFarmer;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Chọn địa chỉ giao hàng', style: AppTextStyles.h4),
            const SizedBox(height: 12),
            for (final a in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, a),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: a.id == selectedId ? AppColors.primary : AppColors.borderSubtle,
                        width: a.id == selectedId ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          a.id == selectedId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: a.id == selectedId ? AppColors.primary : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${a.recipientName} | ${a.recipientPhone}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(a.fullAddress, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: [
                                  _Tag(text: AddressType.label(a.addressType)),
                                  if (a.isDefault) const _Tag(text: 'Mặc định', highlighted: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: full ? null : () => Navigator.pop(context, addNew),
              icon: const Icon(Icons.add),
              label: Text(full ? 'Đã đủ ${Address.maxPerFarmer} địa chỉ' : 'Thêm địa chỉ mới'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.actionText, this.onAction});

  final IconData icon;
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4B5563)),
        const SizedBox(width: 8),
        Flexible(child: Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)))),
      ],
    );
    if (actionText == null) return header;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: header),
        InkWell(
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(actionText!, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF1B5E20), fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.highlighted = false});
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryLight : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: highlighted ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(width: 32, height: 32, color: AppColors.surfaceSubtle, child: ProductImage(url: line.imageUrl, iconSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.productName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              Text('${line.packagingName} • SL: ${line.quantity}', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatVnd(line.lineTotalAmount ?? 0),
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.isTotal = false});
  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isTotal ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold) : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        Text(value, style: isTotal ? AppTextStyles.h4.copyWith(color: const Color(0xFF1B5E20)) : AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.selected,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: active ? const Color(0xFF1B5E20) : AppColors.borderSubtle, width: active ? 1.5 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: active ? const Color(0xFF1B5E20) : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(4)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
