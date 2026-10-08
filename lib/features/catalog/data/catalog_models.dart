import '../../../core/utils/json_utils.dart';

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.isActive,
    required this.children,
  });

  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;
  final List<CatalogCategory> children;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) => CatalogCategory(
        id: asString(json['id']),
        name: asString(json['name']),
        displayOrder: asInt(json['displayOrder']),
        isActive: asBool(json['isActive'], true),
        children: asObjectList(json['children']).map(CatalogCategory.fromJson).toList(growable: false),
      );
}

/// One row of `GET /api/catalog/products`. The id is also the `storeProductId` the cart expects.
class CatalogProductListItem {
  const CatalogProductListItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.sku,
    this.imageUrl,
    this.categoryName,
    this.brandName,
    this.fromPrice,
  });

  final String id;
  final String name;
  final String categoryId;
  final String? sku;
  final String? imageUrl;
  final String? categoryName;
  final String? brandName;

  /// The lowest price over the packagings that have one; null when none has a price (the store has not priced it).
  final double? fromPrice;

  bool get hasPrice => fromPrice != null;

  factory CatalogProductListItem.fromJson(Map<String, dynamic> json) => CatalogProductListItem(
        id: asString(json['id']),
        name: asString(json['name']),
        categoryId: asString(json['categoryId']),
        sku: asStringOrNull(json['sku']),
        imageUrl: asStringOrNull(json['imageUrl']),
        categoryName: asStringOrNull(json['categoryName']),
        brandName: asStringOrNull(json['brandName']),
        fromPrice: asDoubleOrNull(json['fromPrice']),
      );
}

class CatalogPackaging {
  const CatalogPackaging({
    required this.id,
    required this.conversionToBase,
    required this.isBaseUnit,
    this.unitName,
    this.symbol,
    this.packagingName,
    this.price,
  });

  final String id;
  final String? unitName;
  final String? symbol;
  final String? packagingName;

  /// How many base units one pack holds (the inventory core counts in base units).
  final double conversionToBase;
  final bool isBaseUnit;

  /// Null when the store has not set a price for this packaging: it cannot be bought online.
  final double? price;

  bool get hasPrice => price != null;

  /// The name shown to the farmer: the packaging name, else the unit, else its symbol.
  String get label {
    for (final candidate in [packagingName, unitName, symbol]) {
      if (candidate != null && candidate.trim().isNotEmpty) return candidate;
    }
    return 'Đơn vị lẻ';
  }

  factory CatalogPackaging.fromJson(Map<String, dynamic> json) => CatalogPackaging(
        id: asString(json['id']),
        unitName: asStringOrNull(json['unitName']),
        symbol: asStringOrNull(json['symbol']),
        packagingName: asStringOrNull(json['packagingName']),
        conversionToBase: asDouble(json['conversionToBase'], 1),
        isBaseUnit: asBool(json['isBaseUnit']),
        price: asDoubleOrNull(json['price']),
      );
}

class CatalogIngredient {
  const CatalogIngredient({this.name, this.concentration});

  final String? name;
  final String? concentration;

  /// `Hoạt chất 40%`, or just the name.
  String get label => [name, concentration].where((p) => p != null && p.trim().isNotEmpty).join(' ');

  factory CatalogIngredient.fromJson(Map<String, dynamic> json) => CatalogIngredient(
        name: asStringOrNull(json['name']),
        concentration: asStringOrNull(json['concentration']),
      );
}

/// `GET /api/catalog/products/{id}`.
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.packagings,
    required this.ingredients,
    this.sku,
    this.description,
    this.usageInstructions,
    this.imageUrl,
    this.categoryName,
    this.brandName,
  });

  final String id;
  final String name;
  final String categoryId;
  final String? sku;
  final String? description;
  final String? usageInstructions;
  final String? imageUrl;
  final String? categoryName;
  final String? brandName;
  final List<CatalogPackaging> packagings;
  final List<CatalogIngredient> ingredients;

  /// The packagings that can be bought online (they have a price), the largest pack first: the order a farmer
  /// usually buys in.
  List<CatalogPackaging> get sellablePackagings => packagings.where((p) => p.hasPrice).toList()
    ..sort((a, b) => b.conversionToBase.compareTo(a.conversionToBase));

  bool get isSellable => packagings.any((p) => p.hasPrice);

  String get ingredientsText => ingredients.map((i) => i.label).where((l) => l.isNotEmpty).join(', ');

  factory CatalogProduct.fromJson(Map<String, dynamic> json) => CatalogProduct(
        id: asString(json['id']),
        name: asString(json['name']),
        categoryId: asString(json['categoryId']),
        sku: asStringOrNull(json['sku']),
        description: asStringOrNull(json['description']),
        usageInstructions: asStringOrNull(json['usageInstructions']),
        imageUrl: asStringOrNull(json['imageUrl']),
        categoryName: asStringOrNull(json['categoryName']),
        brandName: asStringOrNull(json['brandName']),
        packagings: asObjectList(json['packagings']).map(CatalogPackaging.fromJson).toList(growable: false),
        ingredients: asObjectList(json['ingredients']).map(CatalogIngredient.fromJson).toList(growable: false),
      );
}
