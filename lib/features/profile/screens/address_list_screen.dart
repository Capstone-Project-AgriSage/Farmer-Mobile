import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/address.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/empty_data_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading_widget.dart';
import '../data/profile_repository.dart';
import '../providers/profile_providers.dart';

class AddressListScreen extends ConsumerStatefulWidget {
  const AddressListScreen({super.key});

  @override
  ConsumerState<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends ConsumerState<AddressListScreen> {
  /// Địa chỉ đang được xử lý (đặt mặc định/xoá): khoá nút để khỏi bấm đúp.
  String? _busyId;

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(String id, Future<void> Function() action, String ok) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await action();
      if (mounted) _toast(ok);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
      // Địa chỉ có thể đã bị xoá ở nơi khác: đồng bộ lại danh sách.
      if (e.statusCode == 404) ref.invalidate(addressesProvider);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmDelete(Address a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá địa chỉ'),
        content: Text(a.isDefault
            ? 'Đây là địa chỉ mặc định. Sau khi xoá bạn sẽ không còn địa chỉ mặc định.\n\n${a.fullAddress}'
            : 'Bạn có chắc muốn xoá địa chỉ này?\n\n${a.fullAddress}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ')),
          TextButton(
            key: const Key('address_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xoá',
                style: TextStyle(color: AppColors.statusError)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(a.id, () => ref.read(addressesProvider.notifier).delete(a.id),
        'Đã xoá địa chỉ.');
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final count = addresses.valueOrNull?.length ?? 0;
    final full = count >= ProfileRepository.maxAddresses;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Quản lý địa chỉ'), centerTitle: true),
      body: addresses.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerListWidget(itemCount: 3, itemHeight: 110),
        ),
        error: (e, _) => ErrorRetryWidget(
          error: e,
          onRetry: () => ref.read(addressesProvider.notifier).refresh(),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.read(addressesProvider.notifier).refresh(),
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: 420,
                      child: EmptyDataWidget(
                        message: 'Bạn chưa có địa chỉ nào.\nThêm địa chỉ để đặt hàng nhanh hơn.',
                        fallbackIcon: Icons.location_off_outlined,
                        actionText: 'Thêm địa chỉ',
                        onActionPressed: () =>
                            context.push('${AppRoutes.profile}/addresses/add'),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _AddressCard(
                    address: list[i],
                    busy: _busyId == list[i].id,
                    onSetDefault: () => _run(
                        list[i].id,
                        () => ref
                            .read(addressesProvider.notifier)
                            .setDefault(list[i].id),
                        'Đã đặt làm địa chỉ mặc định.'),
                    onDelete: () => _confirmDelete(list[i]),
                  ),
                ),
        ),
      ),
      bottomNavigationBar: addresses.hasValue && count > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      key: const Key('address_add'),
                      onPressed: full
                          ? null
                          : () =>
                              context.push('${AppRoutes.profile}/addresses/add'),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm địa chỉ mới'),
                    ),
                    if (full)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Đã đủ ${ProfileRepository.maxAddresses} địa chỉ. Hãy xoá bớt để thêm mới.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onSetDefault,
    required this.onDelete,
  });

  final Address address;
  final bool busy;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Container(
      key: Key('address_${a.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: a.isDefault ? Border.all(color: AppColors.primary, width: 1.5) : null,
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
              Flexible(
                child: Text(a.recipientName,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
              if (a.isDefault) ...[
                const SizedBox(width: 8),
                const _Badge('Mặc định', AppColors.primary, AppColors.primaryLight),
              ],
              const SizedBox(width: 8),
              _Badge(AddressType.label(a.addressType), AppColors.textSecondary,
                  AppColors.surfaceSecondary),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.recipientPhone,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(a.fullAddress,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              if (!a.isDefault)
                TextButton(
                  key: Key('address_default_${a.id}'),
                  onPressed: busy ? null : onSetDefault,
                  child: const Text('Đặt mặc định'),
                ),
              TextButton(
                key: Key('address_edit_${a.id}'),
                onPressed: busy
                    ? null
                    : () => context
                        .push('${AppRoutes.profile}/addresses/edit/${a.id}'),
                child: const Text('Sửa'),
              ),
              TextButton(
                key: Key('address_delete_${a.id}'),
                onPressed: busy ? null : onDelete,
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.statusError),
                child: const Text('Xoá'),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.fg, this.bg);

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style:
                TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold)),
      );
}
