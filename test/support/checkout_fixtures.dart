import 'package:farmer_mobile/features/credit/data/credit_models.dart';
import 'package:farmer_mobile/features/profile/data/address_models.dart';

// Shapes follow AddressResponse, MyCreditSummaryResponse and OrderResponse (FLOW_2).

const homeAddress = Address(
  id: 'a-home',
  recipientName: 'Nông dân E2E 170679',
  recipientPhone: '0917067932',
  addressLine: 'Ấp 2',
  district: 'Thới Lai',
  province: 'Cần Thơ',
  addressType: AddressType.home,
  isDefault: true,
);

const farmAddress = Address(
  id: 'a-farm',
  recipientName: 'Anh Ba',
  recipientPhone: '0912345678',
  addressLine: 'Ruộng số 7',
  ward: 'Xã Thới Đông',
  district: 'Thới Lai',
  province: 'Cần Thơ',
  addressType: AddressType.farm,
  isDefault: false,
);

MyCredit credit({String status = 'ACTIVE', double available = 1988000}) => MyCredit(
      status: status,
      creditLimit: 5000000,
      availableCredit: available,
      outstandingReceivable: 3000000,
      reservedCredit: 12000,
      paymentTermDays: 30,
    );

const addressJson = {
  'id': 'a-home',
  'recipientName': 'Nông dân E2E 170679',
  'recipientPhone': '0917067932',
  'addressLine': 'Ấp 2',
  'ward': null,
  'district': 'Thới Lai',
  'province': 'Cần Thơ',
  'latitude': null,
  'longitude': 105.7123456,
  'addressType': 'HOME',
  'isDefault': true,
  'createdAt': '2026-10-04T10:00:00+00:00',
};

const orderJson = {
  'id': 'o-1',
  'orderNumber': 'ON-20261008-0001',
  'source': 'FARMER_MOBILE',
  'settlementType': 'FULL_PAYMENT',
  'fulfillmentType': 'DELIVERY',
  'deliveryAddress': {
    'recipientName': 'Nông dân E2E 170679',
    'recipientPhone': '0917067932',
    'addressLine': 'Ấp 2',
    'ward': null,
    'district': 'Thới Lai',
    'province': 'Cần Thơ',
    'latitude': null,
    'longitude': null,
  },
  'status': 'PENDING_CONFIRMATION',
  'subtotalAmount': 1560000.0,
  'totalAmount': 1560000.0,
  'note': 'Giao buổi sáng',
  'createdAt': '2026-10-08T09:10:00+00:00',
  'confirmedAt': null,
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'items': [
    {
      'id': 'i-1',
      'storeProductId': 'p-st25',
      'productPackagingId': 'k-bao',
      'sku': 'DEMO-LUA-ST25',
      'productName': 'Lúa giống ST25 (bao 25 kg)',
      'packagingName': 'Bao 25 kg',
      'quantity': 2,
      'unitPrice': 780000.0,
      'lineTotalAmount': 1560000.0,
      'status': 'OPEN',
    },
  ],
};
