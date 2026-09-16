import '../models/order.dart';

final List<Order> mockOrders = [
  Order(
    id: 'ORD-1001',
    orderCode: 'DH-20231001-A1',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    status: OrderStatus.pending,
    paymentMethod: PaymentMethod.qr,
    deliveryAddress: 'Ấp 3, Xã Bình Thành, Huyện Thoại Sơn, An Giang',
    totalAmount: 450000,
    items: [
      const OrderItem(productId: 'P-001', productName: 'Thuốc Trừ Bệnh Beam 75WP', quantity: 2, unitPrice: 92000, unit: 'Gói 100g'),
      const OrderItem(productId: 'P-002', productName: 'Thuốc Trừ Nấm Filia 525SE', quantity: 1, unitPrice: 145000, unit: 'Chai 250ml'),
    ],
  ),
  Order(
    id: 'ORD-1002',
    orderCode: 'DH-20230928-B2',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    status: OrderStatus.delivering,
    paymentMethod: PaymentMethod.debt,
    deliveryAddress: 'Ấp 3, Xã Bình Thành, Huyện Thoại Sơn, An Giang',
    totalAmount: 1250000,
    items: [
      const OrderItem(productId: 'P-003', productName: 'Phân bón NPK 20-20-15', quantity: 5, unitPrice: 250000, unit: 'Bao 50kg'),
    ],
  ),
  Order(
    id: 'ORD-1003',
    orderCode: 'DH-20230920-C3',
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    status: OrderStatus.delivered,
    paymentMethod: PaymentMethod.debt,
    deliveryAddress: 'Nhận tại cửa hàng (Đại lý VTNN Hai Lúa)',
    totalAmount: 850000,
    items: [
      const OrderItem(productId: 'P-004', productName: 'Thuốc trừ sâu Regent 800WG', quantity: 10, unitPrice: 85000, unit: 'Gói 1.6g'),
    ],
  ),
  Order(
    id: 'ORD-1004',
    orderCode: 'DH-20230915-D4',
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
    status: OrderStatus.cancelled,
    paymentMethod: PaymentMethod.qr,
    deliveryAddress: 'Ấp 3, Xã Bình Thành, Huyện Thoại Sơn, An Giang',
    totalAmount: 320000,
    items: [
      const OrderItem(productId: 'P-005', productName: 'Phân bón lá Đầu Trâu 502', quantity: 4, unitPrice: 80000, unit: 'Chai 500ml'),
    ],
  ),
];
