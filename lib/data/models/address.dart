/// Loại địa chỉ (backend: `addressType`).
abstract class AddressType {
  static const home = 'HOME';
  static const farm = 'FARM';
  static const other = 'OTHER';
  static const all = [home, farm, other];

  static String label(String type) => switch (type) {
        home => 'Nhà riêng',
        farm => 'Vườn / Ruộng',
        _ => 'Khác',
      };
}

/// Địa chỉ giao hàng của nông dân (`/api/me/addresses`).
class Address {
  const Address({
    required this.id,
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.province,
    required this.addressType,
    this.ward,
    this.district,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

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

  /// "Số nhà, Phường/Xã, Quận/Huyện, Tỉnh" — bỏ qua phần trống.
  String get fullAddress => [addressLine, ward, district, province]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(', ');

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        recipientName: json['recipientName'] as String? ?? '',
        recipientPhone: json['recipientPhone'] as String? ?? '',
        addressLine: json['addressLine'] as String? ?? '',
        ward: json['ward'] as String?,
        district: json['district'] as String?,
        province: json['province'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        addressType: json['addressType'] as String? ?? AddressType.other,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

/// Dữ liệu gửi lên khi tạo/sửa địa chỉ.
class AddressInput {
  const AddressInput({
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.province,
    required this.addressType,
    this.ward,
    this.district,
    this.isDefault = false,
  });

  final String recipientName;
  final String recipientPhone;
  final String addressLine;
  final String province;
  final String addressType;
  final String? ward;
  final String? district;
  final bool isDefault;

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, dynamic> toJson() => {
        'recipientName': recipientName.trim(),
        'recipientPhone': recipientPhone.trim(),
        'addressLine': addressLine.trim(),
        'province': province.trim(),
        'addressType': addressType,
        'ward': _blankToNull(ward),
        'district': _blankToNull(district),
        'isDefault': isDefault,
      };
}
