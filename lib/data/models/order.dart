// Order model
enum OrderStatus { pending, confirmed, delivering, delivered, cancelled }

class Order {
  final String id;
  final String orderCode;
  final DateTime createdAt;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? deliveryAddress;

  const Order({
    required this.id,
    required this.orderCode,
    required this.createdAt,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    this.deliveryAddress,
  });

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending: return 'Chờ xác nhận';
      case OrderStatus.confirmed: return 'Đã xác nhận';
      case OrderStatus.delivering: return 'Đang giao hàng';
      case OrderStatus.delivered: return 'Đã giao hàng';
      case OrderStatus.cancelled: return 'Đã huỷ';
    }
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String unit;
  const OrderItem({required this.productId, required this.productName, required this.quantity, required this.unitPrice, required this.unit});
  double get subtotal => unitPrice * quantity;
}

enum PaymentMethod { qr, debt }
