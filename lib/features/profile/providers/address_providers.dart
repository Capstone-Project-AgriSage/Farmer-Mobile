import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../data/address_models.dart';
import '../data/address_repository.dart';

/// The farmer's address book, default address first. Each change asks the server and then reloads the list, so the
/// "default" flag (which the server moves from one address to another) is always the server's.
class AddressBookController extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() async {
    // The address book belongs to one user: start again when someone else signs in.
    if (ref.watch(sessionUserIdProvider) == null) return const [];
    return _sorted(await ref.watch(addressRepositoryProvider).list());
  }

  Future<Address> create(AddressInput input) async {
    final created = await ref.read(addressRepositoryProvider).create(input);
    await _reload();
    return created;
  }

  Future<void> edit(String id, AddressInput input) async {
    await ref.read(addressRepositoryProvider).update(id, input);
    await _reload();
  }

  Future<void> remove(String id) async {
    await ref.read(addressRepositoryProvider).delete(id);
    await _reload();
  }

  Future<void> setDefault(String id) async {
    await ref.read(addressRepositoryProvider).setDefault(id);
    await _reload();
  }

  Future<void> _reload() async {
    final list = await ref.read(addressRepositoryProvider).list();
    state = AsyncData(_sorted(list));
  }

  /// The default address first; the rest keep the server's order.
  static List<Address> _sorted(List<Address> list) {
    final sorted = [...list];
    sorted.sort((a, b) => (b.isDefault ? 1 : 0).compareTo(a.isDefault ? 1 : 0));
    return sorted;
  }
}

final addressBookProvider = AsyncNotifierProvider<AddressBookController, List<Address>>(AddressBookController.new);
