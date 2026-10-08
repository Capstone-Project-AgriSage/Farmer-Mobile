import '../../../core/utils/json_utils.dart';

/// `settlementType` of an order.
abstract final class SettlementType {
  static const fullPayment = 'FULL_PAYMENT';
  static const credit = 'CREDIT';
}

abstract final class OrderStatus {
  static const pendingConfirmation = 'PENDING_CONFIRMATION';
  static const confirmed = 'CONFIRMED';
  static const preparing = 'PREPARING';
  static const readyForFulfillment = 'READY_FOR_FULFILLMENT';
  static const partiallyFulfilled = 'PARTIALLY_FULFILLED';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
  static const partiallyCancelled = 'PARTIALLY_CANCELLED';

  /// The statuses a farmer can filter the list by (the server filters by one status at a time).
  static const filterable = [
    pendingConfirmation,
    confirmed,
    preparing,
    readyForFulfillment,
    partiallyFulfilled,
    completed,
    cancelled,
  ];

  static bool isClosed(String status) => status == cancelled || status == partiallyCancelled;
}

class OrderDeliveryAddress {
  const OrderDeliveryAddress({
    required this.recipientName,
    required this.recipientPhone,
    required this.addressLine,
    required this.province,
    this.ward,
    this.district,
  });

  final String recipientName;
  final String recipientPhone;
  final String addressLine;
  final String? ward;
  final String? district;
  final String province;

  String get fullAddress =>
      [addressLine, ward, district, province].where((p) => p != null && p.trim().isNotEmpty).join(', ');

  factory OrderDeliveryAddress.fromJson(Map<String, dynamic> json) => OrderDeliveryAddress(
        recipientName: asString(json['recipientName']),
        recipientPhone: asString(json['recipientPhone']),
        addressLine: asString(json['addressLine']),
        ward: asStringOrNull(json['ward']),
        district: asStringOrNull(json['district']),
        province: asString(json['province']),
      );
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productName,
    required this.packagingName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotalAmount,
    required this.status,
    this.sku,
  });

  final String id;
  final String? sku;
  final String productName;
  final String packagingName;
  final int quantity;
  final double unitPrice;
  final double lineTotalAmount;
  final String status;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: asString(json['id']),
        sku: asStringOrNull(json['sku']),
        productName: asString(json['productName']),
        packagingName: asString(json['packagingName']),
        quantity: asInt(json['quantity']),
        unitPrice: asDouble(json['unitPrice']),
        lineTotalAmount: asDouble(json['lineTotalAmount']),
        status: asString(json['status']),
      );
}

/// `OrderResponse`: one order with its lines.
class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.settlementType,
    required this.fulfillmentType,
    required this.status,
    required this.subtotalAmount,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
    this.deliveryAddress,
    this.note,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  final String id;
  final String orderNumber;
  final String settlementType;
  final String fulfillmentType;
  final String status;
  final OrderDeliveryAddress? deliveryAddress;
  final double subtotalAmount;
  final double totalAmount;
  final String? note;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final List<OrderItem> items;

  bool get isCredit => settlementType == SettlementType.credit;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: asString(json['id']),
        orderNumber: asString(json['orderNumber']),
        settlementType: asString(json['settlementType']),
        fulfillmentType: asString(json['fulfillmentType']),
        status: asString(json['status']),
        deliveryAddress: json['deliveryAddress'] is Map<String, dynamic>
            ? OrderDeliveryAddress.fromJson(json['deliveryAddress'] as Map<String, dynamic>)
            : null,
        subtotalAmount: asDouble(json['subtotalAmount']),
        totalAmount: asDouble(json['totalAmount']),
        note: asStringOrNull(json['note']),
        createdAt: asDateTime(json['createdAt']) ?? DateTime.now().toUtc(),
        confirmedAt: asDateTime(json['confirmedAt']),
        completedAt: asDateTime(json['completedAt']),
        cancelledAt: asDateTime(json['cancelledAt']),
        cancelReason: asStringOrNull(json['cancelReason']),
        items: asObjectList(json['items']).map(OrderItem.fromJson).toList(growable: false),
      );
}

/// One row of `GET /api/me/orders`: a summary, the lines come with the single-order call.
class OrderListItem {
  const OrderListItem({
    required this.id,
    required this.orderNumber,
    required this.settlementType,
    required this.fulfillmentType,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    required this.createdAt,
    this.confirmedAt,
  });

  final String id;
  final String orderNumber;
  final String settlementType;
  final String fulfillmentType;
  final String status;
  final double totalAmount;
  final int itemCount;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  bool get isCredit => settlementType == SettlementType.credit;

  factory OrderListItem.fromJson(Map<String, dynamic> json) => OrderListItem(
        id: asString(json['id']),
        orderNumber: asString(json['orderNumber']),
        settlementType: asString(json['settlementType']),
        fulfillmentType: asString(json['fulfillmentType']),
        status: asString(json['status']),
        totalAmount: asDouble(json['totalAmount']),
        itemCount: asInt(json['itemCount']),
        createdAt: asDateTime(json['createdAt']) ?? DateTime.now().toUtc(),
        confirmedAt: asDateTime(json['confirmedAt']),
      );
}

/// What the checkout sends. Online orders are always DELIVERY: someone who wants to collect goes to the counter.
class CheckoutInput {
  const CheckoutInput({required this.settlementType, required this.addressId, this.note});

  final String settlementType;
  final String addressId;
  final String? note;

  Map<String, dynamic> toJson() => {
        'source': 'FARMER_MOBILE',
        'settlementType': settlementType,
        'fulfillmentType': 'DELIVERY',
        'addressId': addressId,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };
}
