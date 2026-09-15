// Product model — bám sát types/index.ts của Farmer-Web
class StockStatus {
  static const String inStock = 'Còn hàng';
  static const String lowStock = 'Sắp hết';
  static const String outOfStock = 'Hết hàng';
}

class Product {
  final String id;
  final String slug;
  final String name;
  final String category;
  final double price;          // Giá lẻ
  final double? wholesalePrice; // Giá sỉ
  final String unit;
  final String description;
  final String imageUrl;
  final String stockStatus;
  final int stockQuantity;
  final String? activeIngredient; // Hoạt chất (thuốc BVTV)
  final String? manufacturer;

  const Product({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    required this.price,
    this.wholesalePrice,
    required this.unit,
    required this.description,
    required this.imageUrl,
    required this.stockStatus,
    required this.stockQuantity,
    this.activeIngredient,
    this.manufacturer,
  });

  bool get isAvailable => stockStatus != StockStatus.outOfStock;
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;
}
