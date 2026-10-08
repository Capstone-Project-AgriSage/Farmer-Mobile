import 'package:farmer_mobile/features/cart/data/cart_models.dart';

// Shapes follow CartResponse / CartItemResponse (FLOW_2 §4).

const bao25 = CartLine(
  id: 'l-bao25',
  storeProductId: 'p-st25',
  productPackagingId: 'k-bao',
  sku: 'DEMO-LUA-ST25',
  productName: 'Lúa giống ST25 (bao 25 kg)',
  packagingName: 'Bao 25 kg',
  quantity: 2,
  unitPrice: 780000,
  lineTotalAmount: 1560000,
  isAvailable: true,
);

const noPriceLine = CartLine(
  id: 'l-huuco',
  storeProductId: 'p-huuco',
  productPackagingId: 'k-bao20',
  productName: 'Phân hữu cơ vi sinh (bao 20 kg)',
  packagingName: 'Bao 20 kg',
  quantity: 1,
  isAvailable: false,
  unavailableReason: CartUnavailableReason.noPrice,
);

Cart cartOf(List<CartLine> lines) => Cart(
      id: 'cart-1',
      items: lines,
      subtotalAmount: lines.fold<double>(0, (sum, l) => sum + (l.lineTotalAmount ?? 0)),
      priceListId: 'pl-1',
    );

const cartJson = {
  'id': 'cart-1',
  'items': [
    {
      'id': 'l-bao25',
      'storeProductId': 'p-st25',
      'productPackagingId': 'k-bao',
      'sku': 'DEMO-LUA-ST25',
      'productName': 'Lúa giống ST25 (bao 25 kg)',
      'packagingName': 'Bao 25 kg',
      'imageUrl': null,
      'quantity': 2,
      'unitPrice': 780000.0,
      'lineTotalAmount': 1560000.0,
      'isAvailable': true,
      'unavailableReason': null,
    },
    {
      'id': 'l-huuco',
      'storeProductId': 'p-huuco',
      'productPackagingId': 'k-bao20',
      'sku': 'DEMO-HUUCO',
      'productName': 'Phân hữu cơ vi sinh (bao 20 kg)',
      'packagingName': 'Bao 20 kg',
      'imageUrl': null,
      'quantity': 1,
      'unitPrice': null,
      'lineTotalAmount': null,
      'isAvailable': false,
      'unavailableReason': 'NO_PRICE',
    },
  ],
  'subtotalAmount': 1560000.0,
  'priceListId': 'pl-1',
};
