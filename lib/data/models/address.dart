class Address {
  final String id;
  final String name;
  final String phone;
  final String street;
  final String ward;
  final String district;
  final String province;
  final bool isDefault;

  Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.street,
    required this.ward,
    required this.district,
    required this.province,
    this.isDefault = false,
  });

  String get fullAddress => '$street, $ward, $district, $province';
}
