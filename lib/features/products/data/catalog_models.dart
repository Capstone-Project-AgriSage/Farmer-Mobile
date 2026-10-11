import '../../../core/network/json_utils.dart';

/// Danh mục (cây) từ `GET /api/catalog/categories`.
class CategoryNode {
  const CategoryNode({
    required this.id,
    required this.name,
    this.children = const [],
  });

  final String id;
  final String name;
  final List<CategoryNode> children;

  factory CategoryNode.fromJson(Map<String, dynamic> json) => CategoryNode(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        children: [
          for (final c in (json['children'] as List? ?? const []))
            CategoryNode.fromJson(c as Map<String, dynamic>),
        ],
      );
}

/// Một dòng trong danh sách sản phẩm. `id` là id sản phẩm của cửa hàng
/// (storeProductId), dùng cho chi tiết và giỏ hàng.
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.sku,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    this.imageUrl,
    this.brandName,
    this.fromPrice,
  });

  final String id;
  final String sku;
  final String name;
  final String? imageUrl;
  final String categoryId;
  final String categoryName;
  final String? brandName;

  /// Giá thấp nhất trong các quy cách đang bán; null = chưa có giá.
  final double? fromPrice;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) => CatalogProduct(
        id: json['id'] as String,
        sku: json['sku'] as String? ?? '',
        name: json['name'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        categoryId: json['categoryId'] as String? ?? '',
        categoryName: json['categoryName'] as String? ?? '',
        brandName: json['brandName'] as String?,
        fromPrice: asDouble(json['fromPrice']),
      );
}

/// Quy cách bán (bao, thùng, chai...). `price` null = không bán theo quy cách
/// này (đơn vị cơ sở) hoặc chưa có giá → không đặt mua được.
class Packaging {
  const Packaging({
    required this.id,
    required this.unitName,
    required this.conversionToBase,
    required this.isBaseUnit,
    this.symbol,
    this.packagingName,
    this.price,
  });

  final String id;
  final String unitName;
  final String? symbol;
  final String? packagingName;
  final int conversionToBase;
  final bool isBaseUnit;
  final double? price;

  bool get isPurchasable => price != null;

  /// Tên hiển thị: "Bao 25 kg", hoặc tên đơn vị nếu không có tên quy cách.
  String get label => (packagingName?.trim().isNotEmpty ?? false)
      ? packagingName!.trim()
      : unitName;

  factory Packaging.fromJson(Map<String, dynamic> json) => Packaging(
        id: json['id'] as String,
        unitName: json['unitName'] as String? ?? '',
        symbol: json['symbol'] as String?,
        packagingName: json['packagingName'] as String?,
        conversionToBase: asInt(json['conversionToBase']) ?? 1,
        isBaseUnit: json['isBaseUnit'] as bool? ?? false,
        price: asDouble(json['price']),
      );
}

class Ingredient {
  const Ingredient({required this.name, this.concentration});

  final String name;
  final String? concentration;

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String? ?? '',
        concentration: json['concentration'] as String?,
      );
}

/// Chi tiết sản phẩm (`GET /api/catalog/products/{id}`).
class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.sku,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.packagings,
    required this.ingredients,
    this.description,
    this.usageInstructions,
    this.imageUrl,
    this.brandName,
  });

  final String id;
  final String sku;
  final String name;
  final String? description;
  final String? usageInstructions;
  final String? imageUrl;
  final String categoryId;
  final String categoryName;
  final String? brandName;
  final List<Packaging> packagings;
  final List<Ingredient> ingredients;

  /// Quy cách đặt mua được (có giá), rẻ nhất trước.
  List<Packaging> get purchasable =>
      packagings.where((p) => p.isPurchasable).toList()
        ..sort((a, b) => a.price!.compareTo(b.price!));

  /// Đơn vị cơ sở, ví dụ "kg" — để giải thích "Bao 25 kg = 25 kg".
  Packaging? get baseUnit {
    for (final p in packagings) {
      if (p.isBaseUnit) return p;
    }
    return null;
  }

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        id: json['id'] as String,
        sku: json['sku'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        usageInstructions: json['usageInstructions'] as String?,
        imageUrl: json['imageUrl'] as String?,
        categoryId: json['categoryId'] as String? ?? '',
        categoryName: json['categoryName'] as String? ?? '',
        brandName: json['brandName'] as String?,
        packagings: [
          for (final p in (json['packagings'] as List? ?? const []))
            Packaging.fromJson(p as Map<String, dynamic>),
        ],
        ingredients: [
          for (final i in (json['ingredients'] as List? ?? const []))
            Ingredient.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// Lý do một dòng trong giỏ không đặt được.
abstract class CartUnavailableReason {
  static const notSellable = 'NOT_SELLABLE';
  static const noPrice = 'NO_PRICE';

  static String label(String? reason) => switch (reason) {
        notSellable => 'Sản phẩm ngừng bán',
        noPrice => 'Chưa có giá',
        _ => 'Không thể đặt mua',
      };
}

class CartLine {
  const CartLine({
    required this.id,
    required this.storeProductId,
    required this.productPackagingId,
    required this.sku,
    required this.productName,
    required this.packagingName,
    required this.quantity,
    required this.isAvailable,
    this.imageUrl,
    this.unitPrice,
    this.lineTotal,
    this.unavailableReason,
  });

  final String id;
  final String storeProductId;
  final String productPackagingId;
  final String sku;
  final String productName;
  final String packagingName;
  final String? imageUrl;
  final int quantity;
  final double? unitPrice;
  final double? lineTotal;
  final bool isAvailable;
  final String? unavailableReason;

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        id: json['id'] as String,
        storeProductId: json['storeProductId'] as String,
        productPackagingId: json['productPackagingId'] as String,
        sku: json['sku'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        packagingName: json['packagingName'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        quantity: asInt(json['quantity']) ?? 0,
        unitPrice: asDouble(json['unitPrice']),
        lineTotal: asDouble(json['lineTotalAmount']),
        isAvailable: json['isAvailable'] as bool? ?? false,
        unavailableReason: json['unavailableReason'] as String?,
      );
}

/// Giỏ hàng (`/api/me/cart`). Giá do server tính lại mỗi lần, app không tự cộng.
class Cart {
  const Cart({this.id, this.lines = const [], this.subtotal = 0});

  static const empty = Cart();

  /// null = chưa có giỏ (rỗng).
  final String? id;
  final List<CartLine> lines;
  final double subtotal;

  bool get isEmpty => lines.isEmpty;

  /// Còn dòng không đặt được thì phải xoá trước khi đặt hàng.
  bool get hasUnavailable => lines.any((l) => !l.isAvailable);

  bool get canCheckout => lines.isNotEmpty && !hasUnavailable;

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        id: json['id'] as String?,
        lines: [
          for (final l in (json['items'] as List? ?? const []))
            CartLine.fromJson(l as Map<String, dynamic>),
        ],
        subtotal: asDoubleOr0(json['subtotalAmount']),
      );
}
