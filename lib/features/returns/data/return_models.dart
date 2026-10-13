import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/json_utils.dart';

/// Trạng thái yêu cầu trả hàng (`SalesReturnStatus` của backend).
abstract class ReturnStatus {
  static const requested = 'REQUESTED';
  static const approved = 'APPROVED';
  static const rejected = 'REJECTED';
  static const received = 'RECEIVED';
  static const inspected = 'INSPECTED';
  static const partiallyResolved = 'PARTIALLY_RESOLVED';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';

  static String label(String s) => switch (s) {
        requested => 'Chờ cửa hàng duyệt',
        approved => 'Đã duyệt',
        rejected => 'Bị từ chối',
        received => 'Cửa hàng đã nhận hàng',
        inspected => 'Đã kiểm tra hàng',
        partiallyResolved => 'Đang xử lý hoàn tiền',
        completed => 'Hoàn tất',
        cancelled => 'Đã huỷ',
        _ => s,
      };

  /// Mô tả bước tiếp theo cho người dùng.
  static String hint(String s) => switch (s) {
        requested => 'Yêu cầu đã gửi. Cửa hàng sẽ xem xét và phản hồi.',
        approved => 'Cửa hàng đã đồng ý. Vui lòng mang hàng trả về cửa hàng theo hướng dẫn.',
        rejected => 'Cửa hàng không chấp nhận yêu cầu này. Liên hệ cửa hàng nếu cần biết thêm.',
        received => 'Cửa hàng đã nhận hàng trả và đang kiểm tra.',
        inspected => 'Cửa hàng đã kiểm tra xong hàng trả.',
        partiallyResolved => 'Cửa hàng đang xử lý khoản hoàn lại cho bạn.',
        completed => 'Yêu cầu trả hàng đã hoàn tất.',
        cancelled => 'Yêu cầu đã được huỷ.',
        _ => '',
      };

  static (Color, Color) colors(String s) => switch (s) {
        requested => (AppColors.statusWarning, AppColors.statusWarningSurface),
        approved || received || inspected || partiallyResolved =>
          (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
        completed => (AppColors.statusSuccess, AppColors.statusSuccessSurface),
        rejected => (AppColors.statusError, AppColors.statusErrorSurface),
        _ => (AppColors.textSecondary, AppColors.surfaceSubtle),
      };

  /// Các bước của một yêu cầu thành công, để vẽ tiến trình.
  static const steps = [requested, approved, received, inspected, completed];

  /// Khách chỉ huỷ được khi cửa hàng chưa duyệt.
  static bool canCancel(String s) => s == requested;

  static bool isFailed(String s) => s == rejected || s == cancelled;
}

/// Lý do trả hàng (`ReasonCode`).
abstract class ReturnReason {
  static const all = <String>[
    'WRONG_PRODUCT',
    'DAMAGED_PRODUCT',
    'QUALITY_ISSUE',
    'EXPIRED_PRODUCT',
    'DELIVERY_DAMAGE',
    'CUSTOMER_REJECTION',
    'OTHER',
  ];

  static String label(String code) => switch (code) {
        'WRONG_PRODUCT' => 'Giao sai sản phẩm',
        'DAMAGED_PRODUCT' => 'Sản phẩm bị hư hỏng',
        'QUALITY_ISSUE' => 'Chất lượng không đạt',
        'EXPIRED_PRODUCT' => 'Hết hạn sử dụng',
        'DELIVERY_DAMAGE' => 'Hư hỏng khi vận chuyển',
        'CUSTOMER_REJECTION' => 'Không còn nhu cầu',
        'OTHER' => 'Lý do khác',
        _ => code,
      };
}

/// Tình trạng hàng sau khi cửa hàng kiểm tra.
String conditionLabel(String c) => switch (c) {
      'PENDING_INSPECTION' => 'Chờ kiểm tra',
      'RESELLABLE' => 'Còn bán được',
      'DAMAGED' => 'Hư hỏng',
      'EXPIRED' => 'Hết hạn',
      'UNUSABLE' => 'Không dùng được',
      _ => c,
    };

String refundMethodLabel(String m) => switch (m) {
      'CASH' => 'Tiền mặt',
      'BANK_TRANSFER' => 'Chuyển khoản',
      'OTHER_EXTERNAL' => 'Hình thức khác',
      _ => m,
    };

String refundStatusLabel(String s) => switch (s) {
      'PENDING' => 'Chờ hoàn tiền',
      'COMPLETED' => 'Đã hoàn tiền',
      'FAILED' => 'Hoàn tiền thất bại',
      'CANCELLED' => 'Đã huỷ',
      _ => s,
    };

/// Số lượng theo đơn vị bán (bao, chai...) nếu chia hết, không thì theo đơn vị nhỏ nhất.
String formatReturnQty(int baseQty, int conversion, String? packagingName) {
  if (conversion > 1 && baseQty % conversion == 0) {
    final q = baseQty ~/ conversion;
    return packagingName == null || packagingName.isEmpty ? '$q' : '$q $packagingName';
  }
  if (conversion <= 1) {
    return packagingName == null || packagingName.isEmpty
        ? '$baseQty'
        : '$baseQty $packagingName';
  }
  return '$baseQty (đơn vị nhỏ nhất)';
}

/// Nơi hàng được lấy ra (một lô hoặc một lần giao). Backend yêu cầu mỗi dòng
/// trả hàng chỉ rõ đúng một nguồn.
class ReturnSource {
  const ReturnSource({
    required this.returnable,
    this.deliveryItemLotAllocationId,
    this.originalStockMovementItemId,
  });

  final int returnable;
  final String? deliveryItemLotAllocationId;
  final String? originalStockMovementItemId;

  factory ReturnSource.fromJson(Map<String, dynamic> json) => ReturnSource(
        returnable: asInt(json['returnableBaseQuantity']) ?? 0,
        deliveryItemLotAllocationId: json['deliveryItemLotAllocationId'] as String?,
        originalStockMovementItemId: json['originalStockMovementItemId'] as String?,
      );
}

/// Một món của đơn còn có thể trả (`ReturnableOrderItem`).
class ReturnableItem {
  const ReturnableItem({
    required this.orderItemId,
    required this.productName,
    required this.fulfilled,
    required this.alreadyReturned,
    required this.returnable,
    required this.unitPrice,
    required this.conversion,
    required this.sources,
  });

  final String orderItemId;
  final String productName;

  /// Mọi số lượng bên dưới tính theo đơn vị nhỏ nhất ("base").
  final int fulfilled;
  final int alreadyReturned;
  final int returnable;

  /// Đơn giá theo một đơn vị bán (bao, chai...).
  final double unitPrice;

  /// 1 đơn vị bán = bao nhiêu đơn vị nhỏ nhất.
  final int conversion;
  final List<ReturnSource> sources;

  /// Số đơn vị bán nguyên có thể trả.
  int get maxUnits => conversion <= 0 ? 0 : returnable ~/ conversion;

  /// Còn hàng nhưng chỉ là phần lẻ, không đủ một đơn vị bán.
  bool get onlyFraction => returnable > 0 && maxUnits == 0;

  factory ReturnableItem.fromJson(Map<String, dynamic> json) => ReturnableItem(
        orderItemId: json['orderItemId'] as String,
        productName: json['productName'] as String? ?? '',
        fulfilled: asInt(json['fulfilledBaseQuantity']) ?? 0,
        alreadyReturned: asInt(json['alreadyReturnedBaseQuantity']) ?? 0,
        returnable: asInt(json['returnableBaseQuantity']) ?? 0,
        unitPrice: asDoubleOr0(json['unitPrice']),
        conversion: asInt(json['conversionToBase']) ?? 1,
        sources: [
          for (final s in (json['sources'] as List? ?? const []))
            ReturnSource.fromJson(s as Map<String, dynamic>),
        ],
      );
}

class Returnable {
  const Returnable({
    required this.orderId,
    required this.orderNumber,
    required this.items,
  });

  final String orderId;
  final String orderNumber;
  final List<ReturnableItem> items;

  List<ReturnableItem> get available => items.where((i) => i.returnable > 0).toList();

  factory Returnable.fromJson(Map<String, dynamic> json) => Returnable(
        orderId: json['orderId'] as String,
        orderNumber: json['orderNumber'] as String? ?? '',
        items: [
          for (final i in (json['items'] as List? ?? const []))
            ReturnableItem.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// Dòng người dùng chọn trả: [units] đơn vị bán của [item] với [reasonCode].
class ReturnSelection {
  const ReturnSelection(this.item, this.units, this.reasonCode);

  final ReturnableItem item;
  final int units;
  final String reasonCode;

  int get baseQuantity => units * item.conversion;
  double get value => units * item.unitPrice;
}

/// Một dòng của body `POST /api/me/returns`.
class ReturnLineRequest {
  const ReturnLineRequest({
    required this.orderItemId,
    required this.baseQuantity,
    required this.reasonCode,
    this.deliveryItemLotAllocationId,
    this.originalStockMovementItemId,
  });

  final String orderItemId;
  final int baseQuantity;
  final String reasonCode;
  final String? deliveryItemLotAllocationId;
  final String? originalStockMovementItemId;

  /// Backend yêu cầu đúng MỘT trong hai nguồn.
  Map<String, dynamic> toJson() => {
        'orderItemId': orderItemId,
        'returnedBaseQuantity': baseQuantity,
        'reasonCode': reasonCode,
        if (deliveryItemLotAllocationId != null)
          'deliveryItemLotAllocationId': deliveryItemLotAllocationId
        else
          'originalStockMovementItemId': originalStockMovementItemId,
      };

  /// Chia số lượng của một món qua các nguồn (lô) theo thứ tự cho đến khi đủ.
  /// Trả về rỗng nếu các nguồn không đủ số lượng.
  static List<ReturnLineRequest> allocate(ReturnSelection s) {
    var left = s.baseQuantity;
    final lines = <ReturnLineRequest>[];
    for (final src in s.item.sources) {
      if (left <= 0) break;
      if (src.returnable <= 0) continue;
      // Nguồn không có mã lô/phiếu xuất thì backend không nhận: coi như không đủ nguồn.
      if (src.deliveryItemLotAllocationId == null &&
          src.originalStockMovementItemId == null) {
        return const [];
      }
      final take = left < src.returnable ? left : src.returnable;
      lines.add(ReturnLineRequest(
        orderItemId: s.item.orderItemId,
        baseQuantity: take,
        reasonCode: s.reasonCode,
        deliveryItemLotAllocationId: src.deliveryItemLotAllocationId,
        originalStockMovementItemId: src.deliveryItemLotAllocationId == null
            ? src.originalStockMovementItemId
            : null,
      ));
      left -= take;
    }
    return left > 0 ? const [] : lines;
  }
}

/// Dòng trong danh sách yêu cầu trả hàng.
class ReturnSummary {
  const ReturnSummary({
    required this.id,
    required this.returnNumber,
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.totalReturnAmount,
    required this.totalRefundAmount,
    required this.requestedAt,
  });

  final String id;
  final String returnNumber;
  final String orderId;
  final String orderNumber;
  final String status;
  final double totalReturnAmount;
  final double totalRefundAmount;
  final DateTime requestedAt;

  factory ReturnSummary.fromJson(Map<String, dynamic> json) => ReturnSummary(
        id: json['id'] as String,
        returnNumber: json['returnNumber'] as String? ?? '',
        orderId: json['orderId'] as String? ?? '',
        orderNumber: json['orderNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        totalReturnAmount: asDoubleOr0(json['totalReturnAmount']),
        totalRefundAmount: asDoubleOr0(json['totalRefundAmount']),
        requestedAt: asDate(json['requestedAt']) ?? DateTime.now(),
      );
}

class ReturnItem {
  const ReturnItem({
    required this.id,
    required this.orderItemId,
    required this.baseQuantity,
    required this.conversion,
    required this.unitPrice,
    required this.value,
    required this.reasonCode,
    required this.condition,
    this.inspectionNote,
  });

  final String id;
  final String orderItemId;
  final int baseQuantity;
  final int conversion;
  final double unitPrice;
  final double value;
  final String reasonCode;
  final String condition;
  final String? inspectionNote;

  bool get inspected => condition != 'PENDING_INSPECTION';

  factory ReturnItem.fromJson(Map<String, dynamic> json) => ReturnItem(
        id: json['id'] as String,
        orderItemId: json['orderItemId'] as String? ?? '',
        baseQuantity: asInt(json['returnedBaseQuantity']) ?? 0,
        conversion: asInt(json['conversionToBaseSnapshot']) ?? 1,
        unitPrice: asDoubleOr0(json['sellingUnitPriceSnapshot']),
        value: asDoubleOr0(json['returnValue']),
        reasonCode: json['reasonCode'] as String? ?? '',
        condition: json['conditionStatus'] as String? ?? 'PENDING_INSPECTION',
        inspectionNote: json['inspectionNote'] as String?,
      );
}

class ReturnRefund {
  const ReturnRefund({
    required this.refundNumber,
    required this.method,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.completedAt,
    this.reference,
  });

  final String refundNumber;
  final String method;
  final double amount;
  final String status;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? reference;

  factory ReturnRefund.fromJson(Map<String, dynamic> json) => ReturnRefund(
        refundNumber: json['refundNumber'] as String? ?? '',
        method: json['refundMethod'] as String? ?? '',
        amount: asDoubleOr0(json['amount']),
        status: json['status'] as String? ?? '',
        requestedAt: asDate(json['requestedAt']) ?? DateTime.now(),
        completedAt: asDate(json['completedAt']),
        reference: json['externalReference'] as String?,
      );
}

/// Chi tiết yêu cầu trả hàng (`SalesReturnResponse`).
class ReturnDetail {
  const ReturnDetail({
    required this.id,
    required this.returnNumber,
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.requestedAt,
    required this.totalReturnAmount,
    required this.totalDebtAdjustment,
    required this.totalRefundAmount,
    required this.items,
    required this.refunds,
    this.approvedAt,
    this.receivedAt,
    this.inspectedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.reasonSummary,
    this.note,
  });

  final String id;
  final String returnNumber;
  final String orderId;
  final String orderNumber;
  final String status;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? receivedAt;
  final DateTime? inspectedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? reasonSummary;
  final String? note;

  /// Tổng giá trị hàng trả.
  final double totalReturnAmount;

  /// Phần trừ vào công nợ (đơn mua ghi nợ).
  final double totalDebtAdjustment;

  /// Phần cửa hàng hoàn lại bằng tiền.
  final double totalRefundAmount;
  final List<ReturnItem> items;
  final List<ReturnRefund> refunds;

  bool get canCancel => ReturnStatus.canCancel(status);

  factory ReturnDetail.fromJson(Map<String, dynamic> json) => ReturnDetail(
        id: json['id'] as String,
        returnNumber: json['returnNumber'] as String? ?? '',
        orderId: json['orderId'] as String? ?? '',
        orderNumber: json['orderNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        requestedAt: asDate(json['requestedAt']) ?? DateTime.now(),
        approvedAt: asDate(json['approvedAt']),
        receivedAt: asDate(json['receivedAt']),
        inspectedAt: asDate(json['inspectedAt']),
        completedAt: asDate(json['completedAt']),
        cancelledAt: asDate(json['cancelledAt']),
        cancelReason: json['cancelReason'] as String?,
        reasonSummary: json['reasonSummary'] as String?,
        note: json['note'] as String?,
        totalReturnAmount: asDoubleOr0(json['totalReturnAmount']),
        totalDebtAdjustment: asDoubleOr0(json['totalDebtAdjustment']),
        totalRefundAmount: asDoubleOr0(json['totalRefundAmount']),
        items: [
          for (final i in (json['items'] as List? ?? const []))
            ReturnItem.fromJson(i as Map<String, dynamic>),
        ],
        refunds: [
          for (final r in (json['refunds'] as List? ?? const []))
            ReturnRefund.fromJson(r as Map<String, dynamic>),
        ],
      );
}
