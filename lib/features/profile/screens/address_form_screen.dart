import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../data/address_models.dart';
import '../providers/address_providers.dart';
import '../widgets/address_form.dart';

/// Thêm hoặc sửa một địa chỉ giao hàng (sửa khi có [addressId]).
class AddressFormScreen extends ConsumerWidget {
  const AddressFormScreen({super.key, this.addressId});

  final String? addressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editing = addressId != null;
    final addresses = ref.watch(addressBookProvider);
    final user = ref.watch(sessionUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(editing ? 'Sửa địa chỉ' : 'Thêm địa chỉ')),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorRetryView(error: error, onRetry: () => ref.invalidate(addressBookProvider)),
        data: (list) {
          Address? initial;
          if (editing) {
            for (final a in list) {
              if (a.id == addressId) initial = a;
            }
            if (initial == null) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Không tìm thấy địa chỉ này.')));
            }
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AddressForm(
              initial: initial,
              initialName: user?.fullName ?? '',
              initialPhone: user?.phoneNumber ?? '',
              defaultChecked: list.isEmpty,
              submitLabel: editing ? 'Lưu thay đổi' : 'Lưu địa chỉ',
              onSubmit: (input) async {
                final controller = ref.read(addressBookProvider.notifier);
                if (editing) {
                  await controller.edit(addressId!, input);
                } else {
                  await controller.create(input);
                }
                if (context.mounted && context.canPop()) context.pop();
              },
            ),
          );
        },
      ),
    );
  }
}
