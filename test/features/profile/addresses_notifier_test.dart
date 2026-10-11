import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/data/models/address.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:farmer_mobile/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/profile_fakes.dart';

AddressInput input({bool isDefault = false, String line = 'Số 9'}) => AddressInput(
      recipientName: 'A',
      recipientPhone: '0912345678',
      addressLine: line,
      province: 'Cần Thơ',
      addressType: AddressType.home,
      isDefault: isDefault,
    );

void main() {
  late FakeProfileRepository repo;
  late ProviderContainer c;

  setUp(() {
    repo = FakeProfileRepository();
    c = ProviderContainer(overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
  });

  Future<List<Address>> list() => c.read(addressesProvider.future);
  AddressesNotifier n() => c.read(addressesProvider.notifier);

  test('địa chỉ đầu tiên tự thành mặc định; địa chỉ sau thì không', () async {
    await list();

    await n().create(input(line: 'Một'));
    await n().create(input(line: 'Hai'));

    final l = await list();
    expect(l.map((a) => a.addressLine), ['Một', 'Hai']);
    expect(l.map((a) => a.isDefault), [true, false]);
  });

  test('tạo với isDefault chuyển cờ sang địa chỉ mới và đưa lên đầu', () async {
    repo.addresses = [makeAddress('a', isDefault: true), makeAddress('b')];
    await list();

    await n().create(input(isDefault: true, line: 'Mới'));

    final l = await list();
    expect(l.first.addressLine, 'Mới');
    expect(l.where((a) => a.isDefault), hasLength(1));
  });

  test('đặt mặc định: cờ đổi ở địa chỉ KHÁC cũng được cập nhật (tải lại cả danh sách)',
      () async {
    repo.addresses = [makeAddress('a', isDefault: true), makeAddress('b')];
    await list();

    await n().setDefault('b');

    final l = await list();
    expect(l.first.id, 'b');
    expect(l.firstWhere((a) => a.id == 'a').isDefault, isFalse);
    expect(repo.calls.where((x) => x == 'listAddresses').length, 2);
  });

  test('xoá địa chỉ mặc định: không còn địa chỉ mặc định', () async {
    repo.addresses = [makeAddress('a', isDefault: true), makeAddress('b')];
    await list();

    await n().delete('a');

    final l = await list();
    expect(l.map((a) => a.id), ['b']);
    expect(l.any((a) => a.isDefault), isFalse);
  });

  test('sửa không bỏ được cờ mặc định (isDefault=false bị bỏ qua)', () async {
    repo.addresses = [makeAddress('a', isDefault: true)];
    await list();

    await n().edit('a', input(isDefault: false, line: 'Đã sửa'));

    final l = await list();
    expect(l.single.addressLine, 'Đã sửa');
    expect(l.single.isDefault, isTrue);
  });

  test('thao tác lỗi: ném ApiException và GIỮ danh sách cũ', () async {
    repo.addresses = [makeAddress('a', isDefault: true)];
    await list();
    repo.writeError = const ApiException(
        kind: ApiErrorKind.network, message: 'mạng');

    await expectLater(n().create(input()), throwsA(isA<ApiException>()));

    expect(c.read(addressesProvider).value, hasLength(1));
    expect(c.read(addressesProvider).hasError, isFalse);
  });

  test('tạo quá 10 địa chỉ → 422', () async {
    repo.addresses = [for (var i = 0; i < 10; i++) makeAddress('a$i', isDefault: i == 0)];
    await list();

    await expectLater(
        n().create(input()),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 422)));
  });

  test('tải danh sách lỗi → AsyncError; refresh() thử lại thành công', () async {
    repo.listError = const ApiException(kind: ApiErrorKind.network, message: 'mạng');
    await expectLater(list(), throwsA(isA<ApiException>()));
    expect(c.read(addressesProvider).hasError, isTrue);

    repo.listError = null;
    repo.addresses = [makeAddress('a', isDefault: true)];
    await n().refresh();

    expect(c.read(addressesProvider).value, hasLength(1));
  });

  test('đổi tài khoản thì danh sách tự tải lại (không lộ dữ liệu người trước)',
      () async {
    c.read(sessionProvider.notifier)
        .setAuthenticated(SessionUser.fromJson(meJson()));
    repo.addresses = [makeAddress('cua-nguoi-1', isDefault: true)];
    expect((await list()).single.id, 'cua-nguoi-1');

    // Người khác đăng nhập trên cùng máy.
    repo.addresses = [makeAddress('cua-nguoi-2', isDefault: true)];
    c.read(sessionProvider.notifier).setAuthenticated(
        SessionUser.fromJson({...meJson(), 'id': 'u2'}));

    expect((await list()).single.id, 'cua-nguoi-2');
  });

  test('profileProvider tải hồ sơ và tải lại khi đổi tài khoản', () async {
    c.read(sessionProvider.notifier)
        .setAuthenticated(SessionUser.fromJson(meJson()));
    expect((await c.read(profileProvider.future)).fullName, 'Trần Văn Hải');

    repo.profile = FarmerProfile.fromJson(profileJson(name: 'Người Khác'));
    c.read(sessionProvider.notifier).setAuthenticated(
        SessionUser.fromJson({...meJson(), 'id': 'u2'}));

    expect((await c.read(profileProvider.future)).fullName, 'Người Khác');
  });
}
