import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/data/models/address.dart';
import 'package:farmer_mobile/features/profile/data/profile_repository.dart';

Map<String, dynamic> addressJson({
  String id = 'a1',
  String name = 'Trần Văn Hải',
  String phone = '0912345678',
  String line = 'Ấp 3',
  String? ward = 'Tân Phú',
  String? district = 'Cái Răng',
  String province = 'Cần Thơ',
  String type = 'FARM',
  bool isDefault = false,
}) =>
    {
      'id': id,
      'recipientName': name,
      'recipientPhone': phone,
      'addressLine': line,
      'ward': ward,
      'district': district,
      'province': province,
      'latitude': null,
      'longitude': null,
      'addressType': type,
      'isDefault': isDefault,
      'createdAt': '2026-10-12T01:00:00Z',
    };

Map<String, dynamic> profileJson({
  String name = 'Trần Văn Hải',
  String? dob = '1980-05-01',
  String? gender = 'MALE',
  String? email,
}) =>
    {
      'farmerProfileId': 'f1',
      'userId': 'u1',
      'fullName': name,
      'phoneNumber': '0912345678',
      'email': email,
      'dateOfBirth': dob,
      'gender': gender,
      'customerGroup': {'id': 'g1', 'code': 'REGULAR', 'name': 'Khách quen'},
      'createdAt': '2026-10-05T12:24:00Z',
    };

Address makeAddress(
  String id, {
  bool isDefault = false,
  String name = 'Người nhận',
  String line = 'Số 1',
  String province = 'Cần Thơ',
  String type = AddressType.home,
}) =>
    Address(
      id: id,
      recipientName: name,
      recipientPhone: '0912345678',
      addressLine: line,
      province: province,
      addressType: type,
      isDefault: isDefault,
    );

/// Repository hồ sơ giả: giữ địa chỉ trong RAM và mô phỏng backend (địa chỉ
/// đầu tiên tự mặc định, chỉ một mặc định, mặc định đứng đầu, tối đa 10).
class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository() : super(Dio());

  final List<String> calls = [];
  FarmerProfile profile = FarmerProfile.fromJson(profileJson());
  List<Address> addresses = [];
  int _seq = 0;

  Object? listError;
  Object? profileError;
  Object? writeError;

  /// Chặn các lần ghi để kiểm tra trạng thái "đang xử lý".
  Future<void>? gate;

  /// Chặn lần tải danh sách để kiểm tra trạng thái "đang tải".
  Future<void>? listGate;

  /// Chặn lần tải hồ sơ.
  Future<void>? profileGate;

  AddressInput? lastInput;
  String? lastProfileName;
  DateTime? lastDob;
  String? lastGender;

  List<Address> _sorted(List<Address> l) =>
      [...l.where((a) => a.isDefault), ...l.where((a) => !a.isDefault)];

  Address _from(String id, AddressInput i, bool isDefault) => Address(
        id: id,
        recipientName: i.recipientName.trim(),
        recipientPhone: i.recipientPhone,
        addressLine: i.addressLine.trim(),
        province: i.province.trim(),
        addressType: i.addressType,
        ward: i.ward,
        district: i.district,
        isDefault: isDefault,
      );

  Address _withDefault(Address a, bool isDefault) => Address(
        id: a.id,
        recipientName: a.recipientName,
        recipientPhone: a.recipientPhone,
        addressLine: a.addressLine,
        province: a.province,
        addressType: a.addressType,
        ward: a.ward,
        district: a.district,
        isDefault: isDefault,
      );

  Address _find(String id) {
    final i = addresses.indexWhere((a) => a.id == id);
    if (i < 0) {
      throw const ApiException(
          kind: ApiErrorKind.notFound,
          statusCode: 404,
          message: 'Địa chỉ này không còn tồn tại.');
    }
    return addresses[i];
  }

  @override
  Future<FarmerProfile> getProfile() async {
    calls.add('getProfile');
    await profileGate;
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<FarmerProfile> updateProfile({
    required String fullName,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    calls.add('updateProfile');
    lastProfileName = fullName;
    lastDob = dateOfBirth;
    lastGender = gender;
    if (writeError != null) throw writeError!;
    profile = FarmerProfile(
      fullName: fullName.trim(),
      phoneNumber: profile.phoneNumber,
      email: profile.email,
      dateOfBirth: dateOfBirth,
      gender: gender,
      customerGroup: profile.customerGroup,
    );
    return profile;
  }

  @override
  Future<List<Address>> listAddresses() async {
    calls.add('listAddresses');
    await listGate;
    if (listError != null) throw listError!;
    return _sorted(addresses);
  }

  @override
  Future<Address> createAddress(AddressInput input) async {
    calls.add('createAddress');
    lastInput = input;
    await gate;
    if (writeError != null) throw writeError!;
    if (addresses.length >= ProfileRepository.maxAddresses) {
      throw const ApiException(
          kind: ApiErrorKind.businessRule,
          statusCode: 422,
          message: 'Tối đa 10 địa chỉ.');
    }
    final makeDefault = addresses.isEmpty || input.isDefault;
    if (makeDefault) {
      addresses = [for (final a in addresses) _withDefault(a, false)];
    }
    final a = _from('n${++_seq}', input, makeDefault);
    addresses = [...addresses, a];
    return a;
  }

  @override
  Future<Address> updateAddress(String id, AddressInput input) async {
    calls.add('updateAddress:$id');
    lastInput = input;
    await gate;
    if (writeError != null) throw writeError!;
    final old = _find(id);
    if (input.isDefault && !old.isDefault) {
      addresses = [for (final a in addresses) _withDefault(a, false)];
    }
    // isDefault=false không bỏ được cờ mặc định (như backend).
    final updated = _from(id, input, old.isDefault || input.isDefault);
    addresses = [for (final a in addresses) a.id == id ? updated : a];
    return updated;
  }

  @override
  Future<void> deleteAddress(String id) async {
    calls.add('deleteAddress:$id');
    await gate;
    if (writeError != null) throw writeError!;
    _find(id);
    addresses = addresses.where((a) => a.id != id).toList();
  }

  @override
  Future<Address> setDefaultAddress(String id) async {
    calls.add('setDefault:$id');
    await gate;
    if (writeError != null) throw writeError!;
    _find(id);
    addresses = [for (final a in addresses) _withDefault(a, a.id == id)];
    return addresses.firstWhere((a) => a.id == id);
  }
}
