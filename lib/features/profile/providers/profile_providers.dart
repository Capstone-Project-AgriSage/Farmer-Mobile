import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../../data/models/address.dart';
import '../data/profile_repository.dart';

/// Hồ sơ của người đang đăng nhập. Đổi tài khoản thì tự tải lại (không lẫn
/// dữ liệu của người trước).
final profileProvider = FutureProvider<FarmerProfile>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  return ref.watch(profileRepositoryProvider).getProfile();
});

/// Sổ địa chỉ. Mọi thao tác ghi đều tải lại cả danh sách vì cờ mặc định có thể
/// đổi ở địa chỉ khác.
class AddressesNotifier extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() {
    ref.watch(sessionProvider.select((s) => s.user?.id));
    return ref.read(profileRepositoryProvider).listAddresses();
  }

  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  Future<void> _reload() async {
    state = AsyncData(await _repo.listAddresses());
  }

  /// Kéo để làm mới / thử lại sau lỗi.
  Future<void> refresh() async {
    state = const AsyncLoading<List<Address>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_repo.listAddresses);
  }

  Future<void> create(AddressInput input) async {
    await _repo.createAddress(input);
    await _reload();
  }

  Future<void> edit(String id, AddressInput input) async {
    await _repo.updateAddress(id, input);
    await _reload();
  }

  Future<void> delete(String id) async {
    await _repo.deleteAddress(id);
    await _reload();
  }

  Future<void> setDefault(String id) async {
    await _repo.setDefaultAddress(id);
    await _reload();
  }
}

final addressesProvider =
    AsyncNotifierProvider<AddressesNotifier, List<Address>>(
        AddressesNotifier.new);
