import 'dart:ui';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/json_utils.dart';

/// Trạng thái đơn (`OrderResponse.status`).
abstract class OrderStatus {
  static const pending = 'PENDING_CONFIRMATION';
  static const confirmed = 'CONFIRMED';
  static const preparing = 'PREPARING';
  static const ready = 'READY_FOR_FULFILLMENT';
  static const partiallyFulfilled = 'PARTIALLY_FULFILLED';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
  static const partiallyCancelled = 'PARTIALLY_CANCELLED';

  /// Bộ lọc ở danh sách đơn (null = tất cả).
  static const filters = <String?>[
    null,
    pending,
    confirmed,
    preparing,
    ready,
    partiallyFulfilled,
    completed,
    cancelled,
  ];

  static String label(String? s) => switch (s) {
        null => 'Tất cả',
        pending => 'Chờ xác nhận',
        confirmed => 'Đã xác nhận',
        preparing => 'Đang chuẩn bị',
        ready => 'Sẵn sàng giao/nhận',
        partiallyFulfilled => 'Đã giao một phần',
        completed => 'Hoàn thành',
        cancelled => 'Đã huỷ',
        partiallyCancelled => 'Huỷ phần còn lại',
        _ => s,
      };

  /// (màu chữ, màu nền) của nhãn trạng thái.
  static (Color, Color) colors(String s) => switch (s) {
        pending => (AppColors.statusWarning, AppColors.statusWarningSurface),
        confirmed || preparing || ready =>
          (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
        partiallyFulfilled => (AppColors.primary, AppColors.primaryLight),
        completed => (AppColors.statusSuccess, AppColors.statusSuccessSurface),
        _ => (AppColors.statusError, AppColors.statusErrorSurface),
      };

  /// Chỉ huỷ online được khi cửa hàng chưa xác nhận.
  static bool canCancel(String s) => s == pending;

  /// Đơn đã có hàng giao/nhận nên có thể yêu cầu trả hàng.
  static bool canReturn(String s) =>
      s == partiallyFulfilled || s == completed || s == partiallyCancelled;

  /// Đơn còn nhận thanh toán (theo backend).
  static bool canPay(String s) =>
      s != cancelled && s != partiallyCancelled && s != completed;
}

abstract class SettlementType {
  static const full = 'FULL_PAYMENT';
  static const credit = 'CREDIT';

  static String label(String s) => s == credit ? 'Mua ghi nợ' : 'Trả ngay';
}

abstract class FulfillmentType {
  static const delivery = 'DELIVERY';
  static const pickup = 'PICKUP';

  static String label(String s) =>
      s == pickup ? 'Nhận tại cửa hàng' : 'Giao hàng tận nơi';
}

class OrderAddress {
  const OrderAddress({
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

  String get fullAddress => [addressLine, ward, district, province]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(', ');

  factory OrderAddress.fromJson(Map<String, dynamic> json) => OrderAddress(
        recipientName: json['recipientName'] as String? ?? '',
        recipientPhone: json['recipientPhone'] as String? ?? '',
        addressLine: json['addressLine'] as String? ?? '',
        ward: json['ward'] as String?,
        district: json['district'] as String?,
        province: json['province'] as String? ?? '',
      );
}

class OrderLine {
  const OrderLine({
    required this.id,
    required this.productName,
    required this.packagingName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.status,
  });

  final String id;
  final String productName;
  final String packagingName;

  /// Số quy cách (bao, thùng...).
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String status;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        id: json['id'] as String,
        productName: json['productName'] as String? ?? '',
        packagingName: json['packagingName'] as String? ?? '',
        quantity: asInt(json['quantity']) ?? 0,
        unitPrice: asDoubleOr0(json['unitPrice']),
        lineTotal: asDoubleOr0(json['lineTotalAmount']),
        status: json['status'] as String? ?? '',
      );
}

/// Dòng trong danh sách đơn (`OrderListItem`).
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.settlementType,
    required this.fulfillmentType,
    required this.totalAmount,
    required this.itemCount,
    required this.createdAt,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String settlementType;
  final String fulfillmentType;
  final double totalAmount;
  final int itemCount;
  final DateTime createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        settlementType: json['settlementType'] as String? ?? SettlementType.full,
        fulfillmentType:
            json['fulfillmentType'] as String? ?? FulfillmentType.delivery,
        totalAmount: asDoubleOr0(json['totalAmount']),
        itemCount: asInt(json['itemCount']) ?? 0,
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      );
}

/// Chi tiết đơn (`OrderResponse`).
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.settlementType,
    required this.fulfillmentType,
    required this.totalAmount,
    required this.subtotalAmount,
    required this.createdAt,
    required this.items,
    this.creditTermDays,
    this.address,
    this.note,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  final String id;
  final String orderNumber;
  final String status;
  final String settlementType;
  final String fulfillmentType;
  final int? creditTermDays;
  final OrderAddress? address;
  final double subtotalAmount;
  final double totalAmount;
  final String? note;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final List<OrderLine> items;

  bool get isDelivery => fulfillmentType == FulfillmentType.delivery;
  bool get isCredit => settlementType == SettlementType.credit;

  factory OrderDetail.fromJson(Map<String, dynamic> json) => OrderDetail(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        settlementType: json['settlementType'] as String? ?? SettlementType.full,
        fulfillmentType:
            json['fulfillmentType'] as String? ?? FulfillmentType.delivery,
        creditTermDays: asInt(json['creditTermDays']),
        address: json['deliveryAddress'] == null
            ? null
            : OrderAddress.fromJson(json['deliveryAddress'] as Map<String, dynamic>),
        subtotalAmount: asDoubleOr0(json['subtotalAmount']),
        totalAmount: asDoubleOr0(json['totalAmount']),
        note: json['note'] as String?,
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        confirmedAt: asDate(json['confirmedAt']),
        completedAt: asDate(json['completedAt']),
        cancelledAt: asDate(json['cancelledAt']),
        cancelReason: json['cancelReason'] as String?,
        items: [
          for (final i in (json['items'] as List? ?? const []))
            OrderLine.fromJson(i as Map<String, dynamic>),
        ],
      );
}

// ── Thanh toán ─────────────────────────────────────────────────────

abstract class PaymentStatus {
  static const pending = 'PENDING';
  static const paid = 'PAID';
  static const failed = 'FAILED';
  static const cancelled = 'CANCELLED';

  static String label(String s) => switch (s) {
        pending => 'Chờ thanh toán',
        paid => 'Đã thanh toán',
        failed => 'Thất bại / hết hạn',
        cancelled => 'Đã huỷ',
        'PARTIALLY_REFUNDED' => 'Đã hoàn một phần',
        'REFUNDED' => 'Đã hoàn tiền',
        _ => s,
      };
}

abstract class PaymentMethod {
  static String label(String m) => switch (m) {
        'PAYOS' => 'payOS (VietQR)',
        'CASH' => 'Tiền mặt',
        'BANK_TRANSFER' => 'Chuyển khoản',
        _ => m,
      };
}

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.paymentNumber,
    required this.method,
    required this.amount,
    required this.status,
    required this.initiatedAt,
    this.confirmedAt,
  });

  final String id;
  final String paymentNumber;
  final String method;
  final double amount;
  final String status;
  final DateTime initiatedAt;
  final DateTime? confirmedAt;

  factory PaymentItem.fromJson(Map<String, dynamic> json) => PaymentItem(
        id: json['id'] as String,
        paymentNumber: json['paymentNumber'] as String? ?? '',
        method: json['paymentMethod'] as String? ?? '',
        amount: asDoubleOr0(json['amount']),
        status: json['status'] as String? ?? '',
        initiatedAt: asDate(json['initiatedAt']) ?? DateTime.now(),
        confirmedAt: asDate(json['confirmedAt']),
      );
}

/// Tóm tắt thanh toán của một đơn (`GET /api/me/orders/{id}/payments`).
class OrderPayments {
  const OrderPayments({
    required this.orderTotal,
    required this.paidAmount,
    required this.remainingToPay,
    required this.payments,
    this.refundCount = 0,
  });

  final double orderTotal;
  final double paidAmount;
  final double remainingToPay;
  final List<PaymentItem> payments;
  final int refundCount;

  bool get isFullyPaid => remainingToPay <= 0;

  /// Link payOS đang chờ (nếu có).
  PaymentItem? get pendingPayOs {
    for (final p in payments) {
      if (p.method == 'PAYOS' && p.status == PaymentStatus.pending) return p;
    }
    return null;
  }

  factory OrderPayments.fromJson(Map<String, dynamic> json) => OrderPayments(
        orderTotal: asDoubleOr0(json['orderTotal']),
        paidAmount: asDoubleOr0(json['paidAmount']),
        remainingToPay: asDoubleOr0(json['remainingToPay']),
        payments: [
          for (final p in (json['payments'] as List? ?? const []))
            PaymentItem.fromJson(p as Map<String, dynamic>),
        ],
        refundCount: (json['refunds'] as List? ?? const []).length,
      );
}

/// Link thanh toán payOS vừa tạo.
class PayOsLink {
  const PayOsLink({
    required this.paymentId,
    required this.paymentNumber,
    required this.amount,
    required this.checkoutUrl,
    required this.status,
    this.qrCode,
    this.expiresAt,
  });

  final String paymentId;
  final String paymentNumber;
  final double amount;
  final String checkoutUrl;

  /// Chuỗi VietQR, app tự vẽ thành mã QR.
  final String? qrCode;
  final DateTime? expiresAt;
  final String status;

  factory PayOsLink.fromJson(Map<String, dynamic> json) => PayOsLink(
        paymentId: json['paymentId'] as String,
        paymentNumber: json['paymentNumber'] as String? ?? '',
        amount: asDoubleOr0(json['amount']),
        checkoutUrl: json['checkoutUrl'] as String? ?? '',
        qrCode: json['qrCode'] as String?,
        expiresAt: asDate(json['expiresAt']),
        status: json['status'] as String? ?? PaymentStatus.pending,
      );
}

/// Một khoản thanh toán (`PaymentResponse`) — chỉ các trường app cần.
class Payment {
  const Payment({
    required this.id,
    required this.paymentNumber,
    required this.status,
    required this.amount,
  });

  final String id;
  final String paymentNumber;
  final String status;
  final double amount;

  bool get isPaid => status == PaymentStatus.paid;
  bool get isPending => status == PaymentStatus.pending;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        paymentNumber: json['paymentNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        amount: asDoubleOr0(json['amount']),
      );
}

// ── Giao hàng ──────────────────────────────────────────────────────

abstract class DeliveryStatus {
  static String label(String s) => switch (s) {
        'ASSIGNED' => 'Đã phân công',
        'OUT_FOR_DELIVERY' => 'Đang giao',
        'PARTIALLY_DELIVERED' => 'Đã giao một phần',
        'RETRY_PENDING' => 'Chờ giao lại',
        'DELIVERED' => 'Đã giao',
        'CANCELLED' => 'Đã huỷ',
        'DRAFT' => 'Đang lập phiếu',
        _ => s,
      };

  static String attemptLabel(String s) => switch (s) {
        'IN_PROGRESS' => 'Đang giao',
        'SUCCESS' => 'Thành công',
        'PARTIAL_SUCCESS' => 'Giao một phần',
        'FAILED' => 'Không thành công',
        'CANCELLED' => 'Đã huỷ',
        _ => s,
      };

  static String failureLabel(String code) => switch (code) {
        'CUSTOMER_ABSENT' => 'Khách vắng nhà',
        'UNREACHABLE' => 'Không liên lạc được',
        'CUSTOMER_REFUSED' => 'Khách từ chối nhận',
        'DAMAGED' => 'Hàng hư hỏng',
        'WEATHER' => 'Thời tiết',
        'VEHICLE_ISSUE' => 'Sự cố xe',
        'ADDRESS_ISSUE' => 'Sai/khó tìm địa chỉ',
        _ => 'Lý do khác',
      };
}

class DeliveryLine {
  const DeliveryLine({
    required this.productName,
    required this.packagingName,
    required this.planned,
    required this.delivered,
    required this.remaining,
  });

  final String productName;
  final String packagingName;
  final int planned;
  final int delivered;
  final int remaining;

  factory DeliveryLine.fromJson(Map<String, dynamic> json) => DeliveryLine(
        productName: json['productName'] as String? ?? '',
        packagingName: json['packagingName'] as String? ?? '',
        planned: asInt(json['plannedQuantity']) ?? 0,
        delivered: asInt(json['deliveredQuantity']) ?? 0,
        remaining: asInt(json['remainingQuantity']) ?? 0,
      );
}

class DeliveryAttempt {
  const DeliveryAttempt({
    required this.number,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.receiverName,
    this.proofImageUrl,
    this.failureReasonCode,
  });

  final int number;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? receiverName;
  final String? proofImageUrl;
  final String? failureReasonCode;

  factory DeliveryAttempt.fromJson(Map<String, dynamic> json) => DeliveryAttempt(
        number: asInt(json['attemptNumber']) ?? 0,
        status: json['status'] as String? ?? '',
        startedAt: asDate(json['startedAt']) ?? DateTime.now(),
        completedAt: asDate(json['completedAt']),
        receiverName: json['receiverName'] as String?,
        proofImageUrl: json['proofImageUrl'] as String?,
        failureReasonCode: json['failureReasonCode'] as String?,
      );
}

class Delivery {
  const Delivery({
    required this.id,
    required this.deliveryNumber,
    required this.status,
    required this.lines,
    required this.attempts,
    this.scheduledAt,
    this.dispatchedAt,
    this.completedAt,
    this.driverName,
    this.driverPhone,
  });

  final String id;
  final String deliveryNumber;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? dispatchedAt;
  final DateTime? completedAt;
  final String? driverName;
  final String? driverPhone;
  final List<DeliveryLine> lines;
  final List<DeliveryAttempt> attempts;

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final staff = json['assignedTo'] as Map<String, dynamic>?;
    return Delivery(
      id: json['id'] as String,
      deliveryNumber: json['deliveryNumber'] as String? ?? '',
      status: json['status'] as String? ?? '',
      scheduledAt: asDate(json['scheduledAt']),
      dispatchedAt: asDate(json['dispatchedAt']),
      completedAt: asDate(json['completedAt']),
      driverName: staff?['fullName'] as String?,
      driverPhone: staff?['phoneNumber'] as String?,
      lines: [
        for (final l in (json['items'] as List? ?? const []))
          DeliveryLine.fromJson(l as Map<String, dynamic>),
      ],
      attempts: [
        for (final a in (json['attempts'] as List? ?? const []))
          DeliveryAttempt.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}

// ── Hạn mức mua chịu ───────────────────────────────────────────────

class CreditSummary {
  const CreditSummary({
    required this.status,
    required this.creditLimit,
    required this.availableCredit,
    required this.outstanding,
    this.paymentTermDays,
  });

  final String status;
  final double creditLimit;
  final double availableCredit;
  final double outstanding;
  final int? paymentTermDays;

  bool get isActive => status == 'ACTIVE';

  factory CreditSummary.fromJson(Map<String, dynamic> json) => CreditSummary(
        status: json['status'] as String? ?? '',
        creditLimit: asDoubleOr0(json['creditLimit']),
        availableCredit: asDoubleOr0(json['availableCredit']),
        outstanding: asDoubleOr0(json['outstandingReceivable']),
        paymentTermDays: asInt(json['paymentTermDays']),
      );
}
