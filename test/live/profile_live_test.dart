// Test tích hợp hồ sơ + sổ địa chỉ với backend THẬT. Mặc định bị bỏ qua.
//
//   LIVE_API=1 flutter test test/live/profile_live_test.dart
//
// Mỗi lần chạy TẠO HAI tài khoản nông dân mới ("TEST Mobile Profile <mã>" và
// "... B") trên DB dev dùng chung; backend chưa có API xoá tài khoản.
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/auth/session_provider.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/data/models/address.dart';
import 'package:farmer_mobile/features/auth/providers/auth_controller.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:farmer_mobile/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/live_support.dart';

const _password = 'Test@12345678';

AddressInput _addr(
  String line, {
  bool isDefault = false,
  String type = AddressType.home,
  String? ward = 'Tân Phú',
  String? district = 'Cái Răng',
  String phone = '0912345678',
}) =>
    AddressInput(
      recipientName: 'Nguyễn Văn Test',
      recipientPhone: phone,
      addressLine: line,
      province: 'Cần Thơ',
      district: district,
      ward: ward,
      addressType: type,
      isDefault: isDefault,
    );

/// Nhận một HÀM (gọi lười): nếu tạo sẵn nhiều Future rồi mới await lần lượt,
/// lỗi của các Future sau sẽ đến khi chưa có ai bắt.
Future<ApiException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on ApiException catch (e) {
    return e;
  }
  fail('Cần ApiException nhưng không có lỗi');
}

void main() {
  late ProviderContainer a;
  late ProviderContainer b;
  late ProfileRepository repo;
  late ProfileRepository repoB;
  late String phone;
  late String name;

  Future<ProviderContainer> signUp(String fullName, String phoneNumber) async {
    final storage = MemoryTokenStorage();
    final c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWith((ref) => createApiDio(
            baseUrl: liveBaseUrl,
            storage: storage,
            onSessionExpired: () async =>
                ref.read(sessionProvider.notifier).markUnauthenticated(),
            adapter: liveAdapter,
          )),
    ]);
    addTearDown(c.dispose);
    await c.read(authControllerProvider).register(
        fullName: fullName, phoneNumber: phoneNumber, password: _password);
    return c;
  }

  setUpAll(() async {
    if (!liveEnabled) return;
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    name = 'TEST Mobile Profile $code';
    phone = randomPhone();
    a = await signUp(name, phone);
    b = await signUp('$name B', randomPhone());
    repo = a.read(profileRepositoryProvider);
    repoB = b.read(profileRepositoryProvider);
  });

  Dio dioA() => a.read(dioProvider);

  group('hồ sơ + địa chỉ với backend thật',
      skip: !liveEnabled ? 'đặt LIVE_API=1 để chạy' : false, () {
    test('hồ sơ mới: có tên, SĐT; chưa có ngày sinh/giới tính', () async {
      final p = await repo.getProfile();

      expect(p.fullName, name);
      expect(p.phoneNumber, phone);
      expect(p.dateOfBirth, isNull);
      expect(p.gender, isNull);
    });

    test('cập nhật hồ sơ: tên (trim), ngày sinh, giới tính; đọc lại khớp', () async {
      final updated = await repo.updateProfile(
          fullName: '  $name (đã sửa)  ',
          dateOfBirth: DateTime(1980, 5, 1),
          gender: Genders.female);

      expect(updated.fullName, '$name (đã sửa)');
      expect(updated.dateOfBirth, DateTime(1980, 5, 1)); // không lệch múi giờ
      expect(updated.gender, 'FEMALE');

      final again = await repo.getProfile();
      expect(again.fullName, '$name (đã sửa)');
      expect(again.dateOfBirth, DateTime(1980, 5, 1));
      // SĐT không đổi qua hồ sơ.
      expect(again.phoneNumber, phone);
    });

    test('tên mới cũng phản ánh ở /api/auth/me', () async {
      final me = await dioA().get<Map<String, dynamic>>('/api/auth/me');
      expect(me.data!['fullName'], '$name (đã sửa)');
    });

    test('xoá ngày sinh và giới tính bằng null', () async {
      final p = await repo.updateProfile(fullName: name);
      expect(p.dateOfBirth, isNull);
      expect(p.gender, isNull);
    });

    test('ngày sinh ở tương lai / trước 1900 → 400', () async {
      for (final dob in [DateTime(2999, 1, 1), DateTime(1899, 12, 31)]) {
        final e = await _failure(
            () => repo.updateProfile(fullName: name, dateOfBirth: dob));
        expect(e.kind, ApiErrorKind.validation, reason: '$dob');
      }
    });

    test('tên trống hoặc giới tính lạ → 400', () async {
      expect((await _failure(() => repo.updateProfile(fullName: '   '))).kind,
          ApiErrorKind.validation);
      final raw = await dioA()
          .put<dynamic>('/api/me/profile',
              data: {'fullName': name, 'gender': 'ROBOT'})
          .then<int?>((r) => r.statusCode, onError: (Object e) {
        return (e as DioException).response?.statusCode;
      });
      expect(raw, 400);
    });

    test('sổ địa chỉ mới tinh: rỗng', () async {
      expect(await repo.listAddresses(), isEmpty);
    });

    test('địa chỉ đầu tiên tự thành mặc định dù gửi isDefault=false', () async {
      final first = await repo.createAddress(_addr('Một', isDefault: false));

      expect(first.isDefault, isTrue);
      expect(first.recipientPhone, '0912345678');
      expect(first.ward, 'Tân Phú');
    });

    test('địa chỉ thứ hai không mặc định; trường tuỳ chọn null được lưu', () async {
      final second =
          await repo.createAddress(_addr('Hai', ward: null, district: null));

      expect(second.isDefault, isFalse);
      expect(second.ward, isNull);
      expect(second.district, isNull);
    });

    test('SĐT người nhận được chuẩn hoá về 0xxxxxxxxx', () async {
      final a3 = await repo.createAddress(_addr('Ba', phone: '+84 912 345 679'));
      expect(a3.recipientPhone, '0912345679');
    });

    test('danh sách: mặc định đứng đầu; chỉ một địa chỉ mặc định', () async {
      final list = await repo.listAddresses();

      expect(list.map((x) => x.addressLine), ['Một', 'Hai', 'Ba']);
      expect(list.where((x) => x.isDefault), hasLength(1));
      expect(list.first.isDefault, isTrue);
    });

    test('tạo với isDefault=true chuyển cờ sang địa chỉ mới và đưa lên đầu',
        () async {
      await repo.createAddress(_addr('Bốn', isDefault: true, type: AddressType.farm));

      final list = await repo.listAddresses();
      expect(list.first.addressLine, 'Bốn');
      expect(list.first.addressType, 'FARM');
      expect(list.where((x) => x.isDefault), hasLength(1));
    });

    test('đặt mặc định bằng set-default', () async {
      final list = await repo.listAddresses();
      final target = list.firstWhere((x) => x.addressLine == 'Hai');

      final result = await repo.setDefaultAddress(target.id);

      expect(result.isDefault, isTrue);
      final after = await repo.listAddresses();
      expect(after.first.id, target.id);
      expect(after.where((x) => x.isDefault), hasLength(1));
      // Đặt lại cho địa chỉ đang mặc định vẫn ổn (idempotent).
      expect((await repo.setDefaultAddress(target.id)).isDefault, isTrue);
    });

    test('sửa địa chỉ: nội dung đổi, cờ mặc định giữ nguyên', () async {
      final def = (await repo.listAddresses()).first;

      final edited = await repo.updateAddress(
          def.id, _addr('Hai (đã sửa)', isDefault: false, type: AddressType.other));

      expect(edited.addressLine, 'Hai (đã sửa)');
      expect(edited.addressType, 'OTHER');
      expect(edited.isDefault, isTrue,
          reason: 'isDefault=false không được bỏ cờ mặc định');
      expect((await repo.listAddresses()).where((x) => x.isDefault), hasLength(1));
    });

    test('sửa địa chỉ khác với isDefault=true thì chuyển cờ sang nó', () async {
      final list = await repo.listAddresses();
      final other = list.firstWhere((x) => !x.isDefault);

      final edited = await repo.updateAddress(
          other.id, _addr(other.addressLine, isDefault: true));

      expect(edited.isDefault, isTrue);
      final after = await repo.listAddresses();
      expect(after.first.id, other.id);
      expect(after.where((x) => x.isDefault), hasLength(1));
    });

    test('dữ liệu sai bị từ chối (400): SĐT, tỉnh trống, loại lạ', () async {
      expect((await _failure(() => repo.createAddress(_addr('X', phone: '12345')))).kind,
          ApiErrorKind.validation);
      expect(
          (await _failure(() => repo.createAddress(const AddressInput(
                  recipientName: 'A',
                  recipientPhone: '0912345678',
                  addressLine: 'x',
                  province: '  ',
                  addressType: 'HOME'))))
              .kind,
          ApiErrorKind.validation);
      expect(
          (await _failure(() => repo.createAddress(const AddressInput(
                  recipientName: 'A',
                  recipientPhone: '0912345678',
                  addressLine: 'x',
                  province: 'y',
                  addressType: 'CASTLE'))))
              .kind,
          ApiErrorKind.validation);
    });

    test('địa chỉ không tồn tại → 404 + thông báo tiếng Việt (sửa/xoá/đặt mặc định)',
        () async {
      const ghost = '00000000-0000-0000-0000-000000000000';
      for (final call in <Future<Object?> Function()>[
        () => repo.updateAddress(ghost, _addr('x')),
        () => repo.deleteAddress(ghost),
        () => repo.setDefaultAddress(ghost),
      ]) {
        final e = await _failure(call);
        expect(e.kind, ApiErrorKind.notFound);
        expect(e.message, contains('không còn tồn tại'));
      }
    });

    test('địa chỉ của người khác: 404 (không lộ), không xuất hiện trong danh sách',
        () async {
      final theirs = await repoB.createAddress(_addr('Của B'));
      expect(theirs.isDefault, isTrue);

      for (final call in <Future<Object?> Function()>[
        () => repo.updateAddress(theirs.id, _addr('Chiếm đoạt')),
        () => repo.deleteAddress(theirs.id),
        () => repo.setDefaultAddress(theirs.id),
      ]) {
        expect((await _failure(call)).kind, ApiErrorKind.notFound);
      }
      expect((await repo.listAddresses()).any((x) => x.id == theirs.id), isFalse);
      // Địa chỉ của B vẫn nguyên vẹn.
      final bList = await repoB.listAddresses();
      expect(bList.single.addressLine, 'Của B');
    });

    test('xoá địa chỉ mặc định: không còn địa chỉ nào mặc định', () async {
      final def = (await repo.listAddresses()).firstWhere((x) => x.isDefault);

      await repo.deleteAddress(def.id);

      final after = await repo.listAddresses();
      expect(after.any((x) => x.id == def.id), isFalse);
      expect(after.any((x) => x.isDefault), isFalse);
    });

    test('tối đa 10 địa chỉ: thứ 11 → 422 + thông báo tiếng Việt', () async {
      var count = (await repo.listAddresses()).length;
      while (count < ProfileRepository.maxAddresses) {
        await repo.createAddress(_addr('Đệm ${++count}'));
      }
      expect((await repo.listAddresses()), hasLength(10));

      final e = await _failure(() => repo.createAddress(_addr('Thứ 11')));

      expect(e.statusCode, 422);
      expect(e.message, contains('tối đa 10 địa chỉ'));
    });

    test('xoá bớt thì thêm lại được', () async {
      final list = await repo.listAddresses();
      await repo.deleteAddress(list.first.id);

      final created = await repo.createAddress(_addr('Vừa đủ'));

      expect(created.id, isNotEmpty);
      expect((await repo.listAddresses()), hasLength(10));
    });

    test('dọn: xoá hết địa chỉ test', () async {
      for (final x in await repo.listAddresses()) {
        await repo.deleteAddress(x.id);
      }
      for (final x in await repoB.listAddresses()) {
        await repoB.deleteAddress(x.id);
      }
      expect(await repo.listAddresses(), isEmpty);
      expect(await repoB.listAddresses(), isEmpty);
    });

    test('profileProvider/addressesProvider chạy được với API thật', () async {
      final p = await a.read(profileProvider.future);
      expect(p.fullName, name);

      final notifier = a.read(addressesProvider.notifier);
      await a.read(addressesProvider.future);
      await notifier.create(_addr('Qua provider'));
      expect(a.read(addressesProvider).value!.single.isDefault, isTrue);
      await notifier.delete(a.read(addressesProvider).value!.single.id);
      expect(a.read(addressesProvider).value, isEmpty);
    });
  });
}
