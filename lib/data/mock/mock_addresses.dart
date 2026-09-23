import '../models/address.dart';

final List<Address> mockAddresses = [
  Address(
    id: 'addr1',
    name: 'Trần Văn Hải',
    phone: '0912345678',
    street: '123 Ấp Thới Phước',
    ward: 'Xã Thới Tân',
    district: 'Huyện Thới Lai',
    province: 'TP. Cần Thơ',
    isDefault: true,
  ),
  Address(
    id: 'addr2',
    name: 'Trần Văn Hải',
    phone: '0912345678',
    street: '456 Ấp Thới Đông',
    ward: 'Xã Trường Thắng',
    district: 'Huyện Thới Lai',
    province: 'TP. Cần Thơ',
    isDefault: false,
  ),
];
