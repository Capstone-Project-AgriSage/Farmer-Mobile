import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../data/address_models.dart';
import '../providers/address_providers.dart';

/// Sổ địa chỉ giao hàng: tối đa 10 địa chỉ, một địa chỉ mặc định.
class AddressListScreen extends ConsumerStatefulWidget {
  const AddressListScreen({super.key});

  @override
  ConsumerState<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends ConsumerState<AddressListScreen> {
  bool _busy = false;

  /// Runs a change to the address book and reports a failure; the list is the server's own either way.
  Future<void> _run(Future<void> Function() change, {String? done}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await change();
      if (done != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(done)));
      }
    } on AppException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa địa chỉ?'),
        content: Text(address.fullAddress),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Giữ lại')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => ref.read(addressBookProvider.notifier).remove(address.id), done: 'Đã xóa địa chỉ.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressBookProvider);
    final count = addresses.valueOrNull?.length ?? 0;
    final full = count >= Address.maxPerFarmer;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Địa chỉ giao hàng')),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(addressBookProvider)),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(addressBookProvider);
            try {
              await ref.read(addressBookProvider.future);
            } catch (_) {
              // The screen shows its own error.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Icon(Icons.location_off_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('Bác chưa có địa chỉ giao hàng nào.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              for (final address in list) ...[
                _AddressCard(
                  address: address,
                  busy: _busy,
                  onEdit: () => context.push('/profile/addresses/edit/${address.id}'),
                  onDelete: () => _confirmDelete(address),
                  onSetDefault: () => _run(() => ref.read(addressBookProvider.notifier).setDefault(address.id), done: 'Đã đặt làm địa chỉ mặc định.'),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: full ? null : () => context.push('/profile/addresses/add'),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(full ? 'Đã đủ ${Address.maxPerFarmer} địa chỉ' : 'Thêm địa chỉ mới'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final Address address;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: address.isDefault ? AppColors.primary : AppColors.borderSubtle, width: address.isDefault ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(address.recipientName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Text(address.recipientPhone, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(address.fullAddress, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              _Tag(text: AddressType.label(address.addressType)),
              if (address.isDefault) const _Tag(text: 'Mặc định', highlighted: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!address.isDefault)
                TextButton(onPressed: busy ? null : onSetDefault, child: const Text('Đặt mặc định')),
              const Spacer(),
              TextButton(onPressed: busy ? null : onEdit, child: const Text('Sửa')),
              TextButton(
                onPressed: busy ? null : onDelete,
                child: const Text('Xóa', style: TextStyle(color: AppColors.statusError)),
              ),
            ],
          ),
        ],
      ),
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
      decoration: BoxDecoration(color: highlighted ? AppColors.primaryLight : AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: highlighted ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
