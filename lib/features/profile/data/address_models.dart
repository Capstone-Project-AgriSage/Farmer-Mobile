import '../../../core/utils/json_utils.dart';

/// The kinds of address the API accepts.
abstract final class AddressType {
  static const home = 'HOME';
  static const farm = 'FARM';
  static const other = 'OTHER';

  static const all = [home, farm, other];

  static String label(String? type) => switch (type) {
        home => 'Nhà',
        farm => 'Ruộng / Vườn',
        other => 'Khác',
        _ => 'Khác',
      };
}

/// A saved delivery address of the farmer (`/api/me/addresses`). A farmer keeps at most 10.
class Address {
  const Address({
    required this.id,
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.province,
    required this.addressType,
    required this.isDefault,
    this.ward,
    this.district,
    this.latitude,
    this.longitude,
  });

  static const maxPerFarmer = 10;

  final String id;
  final String recipientName;
  final String recipientPhone;
  final String addressLine;
  final String? ward;
  final String? district;
  final String province;
  final double? latitude;
  final double? longitude;
  final String addressType;
  final bool isDefault;

  /// `Ấp Thới Phước, Xã Thới Đông, Thới Lai, Cần Thơ`: the parts that are filled in, in reading order.
  String get fullAddress => joinAddress(addressLine, ward, district, province);

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: asString(json['id']),
        recipientName: asString(json['recipientName']),
        recipientPhone: asString(json['recipientPhone']),
        addressLine: asString(json['addressLine']),
        ward: asStringOrNull(json['ward']),
        district: asStringOrNull(json['district']),
        province: asString(json['province']),
        latitude: asDoubleOrNull(json['latitude']),
        longitude: asDoubleOrNull(json['longitude']),
        addressType: asString(json['addressType'], AddressType.other),
        isDefault: asBool(json['isDefault']),
      );
}

String joinAddress(String? line, String? ward, String? district, String? province) =>
    [line, ward, district, province].where((p) => p != null && p.trim().isNotEmpty).join(', ');

/// What the farmer types when adding or editing an address.
class AddressInput {
  const AddressInput({
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.province,
    this.ward,
    this.district,
    this.latitude,
    this.longitude,
    this.addressType = AddressType.home,
    this.isDefault = false,
  });

  final String recipientName;
  final String recipientPhone;
  final String addressLine;
  final String province;
  final String? ward;
  final String? district;
  final double? latitude;
  final double? longitude;
  final String addressType;
  final bool isDefault;

  Map<String, dynamic> toJson() => {
        'recipientName': recipientName.trim(),
        'recipientPhone': recipientPhone.trim(),
        'addressLine': addressLine.trim(),
        'province': province.trim(),
        'ward': _blankToNull(ward),
        'district': _blankToNull(district),
        'latitude': latitude,
        'longitude': longitude,
        'addressType': addressType,
        'isDefault': isDefault,
      };

  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
