import '../../../core/utils/json_utils.dart';

/// Why a cart line cannot be bought right now (the server's `unavailableReason`).
abstract final class CartUnavailableReason {
  static const notSellable = 'NOT_SELLABLE';
  static const noPrice = 'NO_PRICE';
}

String unavailableReasonLabel(String? reason) => switch (reason) {
      CartUnavailableReason.notSellable => 'Sản phẩm này hiện ngừng bán',
      CartUnavailableReason.noPrice => 'Sản phẩm này chưa có giá bán',
      _ => 'Sản phẩm này hiện không mua được',
    };

class CartLine {
  const CartLine({
    required this.id,
    required this.storeProductId,
    required this.productPackagingId,
    required this.productName,
    required this.packagingName,
    required this.quantity,
    required this.isAvailable,
    this.sku,
    this.imageUrl,
    this.unitPrice,
    this.lineTotalAmount,
    this.unavailableReason,
  });

  final String id;
  final String storeProductId;
  final String productPackagingId;
  final String? sku;
  final String productName;
  final String packagingName;
  final String? imageUrl;
  final int quantity;

  /// Null when the product has no price (then `isAvailable` is false).
  final double? unitPrice;
  final double? lineTotalAmount;
  final bool isAvailable;
  final String? unavailableReason;

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        id: asString(json['id']),
        storeProductId: asString(json['storeProductId']),
        productPackagingId: asString(json['productPackagingId']),
        sku: asStringOrNull(json['sku']),
        productName: asString(json['productName']),
        packagingName: asString(json['packagingName']),
        imageUrl: asStringOrNull(json['imageUrl']),
        quantity: asInt(json['quantity'], 1),
        unitPrice: asDoubleOrNull(json['unitPrice']),
        lineTotalAmount: asDoubleOrNull(json['lineTotalAmount']),
        isAvailable: asBool(json['isAvailable'], true),
        unavailableReason: asStringOrNull(json['unavailableReason']),
      );
}

/// The cart as the server last priced it. The app never computes a price itself.
class Cart {
  const Cart({this.id, this.items = const [], this.subtotalAmount = 0, this.priceListId});

  const Cart.empty() : this();

  final String? id;
  final List<CartLine> items;
  final double subtotalAmount;
  final String? priceListId;

  bool get isEmpty => items.isEmpty;

  /// The number shown on the cart badge: how many different lines.
  int get lineCount => items.length;

  bool get hasUnavailableItem => items.any((i) => !i.isAvailable);

  /// Checkout is allowed only for a non-empty cart whose every line can be bought.
  bool get canCheckout => items.isNotEmpty && !hasUnavailableItem;

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        id: asStringOrNull(json['id']),
        items: asObjectList(json['items']).map(CartLine.fromJson).toList(growable: false),
        subtotalAmount: asDouble(json['subtotalAmount']),
        priceListId: asStringOrNull(json['priceListId']),
      );
}
