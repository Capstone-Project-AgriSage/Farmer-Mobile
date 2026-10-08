import 'package:farmer_mobile/core/network/paged.dart';
import 'package:farmer_mobile/features/catalog/data/catalog_models.dart';

// Shapes copied from real answers of GET /api/catalog/products and /products/{id}.

const priced = CatalogProductListItem(
  id: 'p-st25',
  sku: 'DEMO-LUA-ST25',
  name: 'Lúa giống ST25 (bao 25 kg)',
  categoryId: 'c-giong',
  categoryName: 'Giống cây trồng',
  fromPrice: 32000,
);

const unpriced = CatalogProductListItem(
  id: 'p-huuco',
  sku: 'DEMO-HUUCO',
  name: 'Phân hữu cơ vi sinh (bao 20 kg) - chưa có giá',
  categoryId: 'c-phan',
  categoryName: 'Phân bón',
);

Paged<CatalogProductListItem> page(List<CatalogProductListItem> items, {int number = 1, int total = 0, int size = 20}) =>
    Paged(items: items, page: number, pageSize: size, totalCount: total == 0 ? items.length : total);

const stProduct = {
  'id': 'p-st25',
  'sku': 'DEMO-LUA-ST25',
  'name': 'Lúa giống ST25 (bao 25 kg)',
  'description': 'Lúa giống xác nhận ST25, tỷ lệ nảy mầm trên 85%.',
  'usageInstructions': 'Gieo sạ 80-100 kg/ha.',
  'imageUrl': null,
  'categoryId': 'c-giong',
  'categoryName': 'Giống cây trồng',
  'brandId': null,
  'brandName': null,
  'packagings': [
    {
      'id': 'k-kg',
      'unitName': 'Kilogram',
      'symbol': 'kg',
      'packagingName': null,
      'conversionToBase': 1,
      'isBaseUnit': true,
      'barcode': null,
      'price': 32000.0,
    },
    {
      'id': 'k-bao',
      'unitName': 'Bao',
      'symbol': 'bao',
      'packagingName': 'Bao 25 kg',
      'conversionToBase': 25,
      'isBaseUnit': false,
      'barcode': null,
      'price': 780000.0,
    },
  ],
  'ingredients': [],
};

const unpricedProduct = {
  'id': 'p-huuco',
  'sku': 'DEMO-HUUCO',
  'name': 'Phân hữu cơ vi sinh (bao 20 kg) - chưa có giá',
  'description': null,
  'usageInstructions': null,
  'imageUrl': null,
  'categoryId': 'c-phan',
  'categoryName': 'Phân bón',
  'brandName': null,
  'packagings': [
    {
      'id': 'k-bao20',
      'unitName': 'Bao',
      'symbol': 'bao',
      'packagingName': 'Bao 20 kg',
      'conversionToBase': 20,
      'isBaseUnit': false,
      'price': null,
    },
  ],
  'ingredients': [
    {'name': 'Hữu cơ', 'concentration': '45%'},
  ],
};
