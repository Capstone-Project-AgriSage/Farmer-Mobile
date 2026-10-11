import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/data/models/address.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/profile_fakes.dart';

void main() {
  late FakeAdapter adapter;
  late ProfileRepository repo;

  void use(FakeHandler h) {
    adapter = FakeAdapter(h);
    repo = ProfileRepository(createApiDio(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      onSessionExpired: () async {},
      adapter: adapter,
    ));
  }

  group('hồ sơ', () {
    test('parse đầy đủ, ngày sinh giữ nguyên ngày (không lệch múi giờ)', () async {
      use((o) => jsonBody(200, profileJson(email: 'a@b.com')));

      final p = await repo.getProfile();

      expect(adapter.requests.single.path, '/api/me/profile');
      expect(p.fullName, 'Trần Văn Hải');
      expect(p.phoneNumber, '0912345678');
      expect(p.email, 'a@b.com');
      expect(p.gender, 'MALE');
      expect(p.dateOfBirth, DateTime(1980, 5, 1));
      expect(p.customerGroup?.name, 'Khách quen');
    });

    test('các trường null (chưa có ngày sinh, giới tính, nhóm)', () async {
      use((o) => jsonBody(200, {
            ...profileJson(dob: null, gender: null),
            'customerGroup': null,
          }));

      final p = await repo.getProfile();

      expect(p.dateOfBirth, isNull);
      expect(p.gender, isNull);
      expect(p.customerGroup, isNull);
    });

    test('cập nhật: gửi tên đã trim, ngày dạng yyyy-MM-dd, null được giữ', () async {
      use((o) => jsonBody(200, profileJson()));

      await repo.updateProfile(
          fullName: '  Nguyễn Văn B ', dateOfBirth: DateTime(1999, 1, 9), gender: 'FEMALE');
      await repo.updateProfile(fullName: 'A');

      expect(adapter.requests[0].method, 'PUT');
      expect(adapter.requests[0].data, {
        'fullName': 'Nguyễn Văn B',
        'dateOfBirth': '1999-01-09',
        'gender': 'FEMALE',
      });
      expect(adapter.requests[1].data,
          {'fullName': 'A', 'dateOfBirth': null, 'gender': null});
    });

    test('400 validation → lỗi có fieldErrors', () async {
      use((o) => jsonBody(400, {
            'title': 'One or more validation errors occurred.',
            'errors': {
              'DateOfBirth': ['dateOfBirth must be a past date after 1900.']
            },
          }));

      await expectLater(
        repo.updateProfile(fullName: 'A', dateOfBirth: DateTime(2999)),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.fieldErrors.keys, 'keys', contains('DateOfBirth'))),
      );
    });
  });

  group('địa chỉ', () {
    test('danh sách giữ thứ tự backend (mặc định đứng đầu)', () async {
      use((o) => jsonBody(200, [
            addressJson(id: 'a', isDefault: true),
            addressJson(id: 'b', type: 'HOME', ward: null, district: null),
          ]));

      final list = await repo.listAddresses();

      expect(list.map((a) => a.id), ['a', 'b']);
      expect(list.first.isDefault, isTrue);
      expect(list[1].addressType, 'HOME');
      expect(list[1].ward, isNull);
    });

    test('fullAddress bỏ phần trống', () {
      final a = Address.fromJson(addressJson(ward: null, district: ' '));
      expect(a.fullAddress, 'Ấp 3, Cần Thơ');
      final b = Address.fromJson(addressJson());
      expect(b.fullAddress, 'Ấp 3, Tân Phú, Cái Răng, Cần Thơ');
    });

    test('tạo: POST đúng trường, trim, trường tuỳ chọn rỗng → null', () async {
      use((o) => jsonBody(201, addressJson(id: 'new')));

      final a = await repo.createAddress(const AddressInput(
        recipientName: ' Nguyễn A ',
        recipientPhone: '0912345678',
        addressLine: ' 12 Ấp 3 ',
        province: ' Cần Thơ ',
        addressType: AddressType.farm,
        ward: '  ',
        district: '',
        isDefault: true,
      ));

      expect(a.id, 'new');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/me/addresses');
      expect(adapter.requests.single.data, {
        'recipientName': 'Nguyễn A',
        'recipientPhone': '0912345678',
        'addressLine': '12 Ấp 3',
        'province': 'Cần Thơ',
        'addressType': 'FARM',
        'ward': null,
        'district': null,
        'isDefault': true,
      });
    });

    test('tạo thứ 11 → 422 với thông báo tiếng Việt về giới hạn', () async {
      use((o) => jsonBody(422, problem(422, 'A customer can keep at most 10 addresses.')));

      await expectLater(
        repo.createAddress(const AddressInput(
            recipientName: 'A',
            recipientPhone: '0912345678',
            addressLine: 'x',
            province: 'y',
            addressType: 'HOME')),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('tối đa 10 địa chỉ'))),
      );
    });

    test('sửa: PUT /{id}; 404 → thông báo "không còn tồn tại"', () async {
      use((o) => jsonBody(404, problem(404, 'not found')));

      await expectLater(
        repo.updateAddress(
            'abc',
            const AddressInput(
                recipientName: 'A',
                recipientPhone: '0912345678',
                addressLine: 'x',
                province: 'y',
                addressType: 'HOME')),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.notFound)
            .having((e) => e.message, 'message', contains('không còn tồn tại'))),
      );
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, '/api/me/addresses/abc');
    });

    test('xoá: DELETE /{id} (204)', () async {
      use((o) => emptyBody(204));
      await repo.deleteAddress('abc');
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/api/me/addresses/abc');
    });

    test('đặt mặc định: POST /{id}/set-default trả địa chỉ', () async {
      use((o) => jsonBody(200, addressJson(id: 'abc', isDefault: true)));
      final a = await repo.setDefaultAddress('abc');
      expect(adapter.requests.single.path, '/api/me/addresses/abc/set-default');
      expect(a.isDefault, isTrue);
    });
  });

  test('AddressType.label và Genders.label', () {
    expect(AddressType.label('HOME'), 'Nhà riêng');
    expect(AddressType.label('FARM'), 'Vườn / Ruộng');
    expect(AddressType.label('OTHER'), 'Khác');
    expect(Genders.label('MALE'), 'Nam');
    expect(Genders.label('FEMALE'), 'Nữ');
    expect(Genders.label('OTHER'), 'Khác');
  });
}
