import '../../../core/utils/json_utils.dart';

abstract final class DeliveryStatus {
  static const retryPending = 'RETRY_PENDING';
}

abstract final class AttemptStatus {
  static const failed = 'FAILED';
}

class DeliveryStaff {
  const DeliveryStaff({required this.fullName, this.phoneNumber});

  final String fullName;
  final String? phoneNumber;

  factory DeliveryStaff.fromJson(Map<String, dynamic> json) =>
      DeliveryStaff(fullName: asString(json['fullName']), phoneNumber: asStringOrNull(json['phoneNumber']));
}

class DeliveryItem {
  const DeliveryItem({
    required this.orderItemId,
    required this.productName,
    required this.packagingName,
    required this.plannedQuantity,
    required this.deliveredQuantity,
    required this.remainingQuantity,
  });

  final String orderItemId;
  final String productName;
  final String packagingName;
  final int plannedQuantity;
  final int deliveredQuantity;
  final int remainingQuantity;

  factory DeliveryItem.fromJson(Map<String, dynamic> json) => DeliveryItem(
        orderItemId: asString(json['orderItemId']),
        productName: asString(json['productName']),
        packagingName: asString(json['packagingName']),
        plannedQuantity: asInt(json['plannedQuantity']),
        deliveredQuantity: asInt(json['deliveredQuantity']),
        remainingQuantity: asInt(json['remainingQuantity']),
      );
}

/// One try at handing the goods over (a delivery can take several).
class DeliveryAttempt {
  const DeliveryAttempt({
    required this.attemptNumber,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.receiverName,
    this.proofImageUrl,
    this.failureReasonCode,
  });

  final int attemptNumber;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? receiverName;

  /// The photo the driver took at handover (a public link).
  final String? proofImageUrl;
  final String? failureReasonCode;

  factory DeliveryAttempt.fromJson(Map<String, dynamic> json) => DeliveryAttempt(
        attemptNumber: asInt(json['attemptNumber']),
        status: asString(json['status']),
        startedAt: asDateTime(json['startedAt']),
        completedAt: asDateTime(json['completedAt']),
        receiverName: asStringOrNull(json['receiverName']),
        proofImageUrl: asStringOrNull(json['proofImageUrl']),
        failureReasonCode: asStringOrNull(json['failureReasonCode']),
      );
}

/// `MyDeliveryResponse`: one delivery of the farmer's order, as the farmer sees it.
class MyDelivery {
  const MyDelivery({
    required this.id,
    required this.deliveryNumber,
    required this.status,
    required this.items,
    required this.attempts,
    this.scheduledAt,
    this.dispatchedAt,
    this.completedAt,
    this.assignedTo,
  });

  final String id;
  final String deliveryNumber;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? dispatchedAt;
  final DateTime? completedAt;
  final DeliveryStaff? assignedTo;
  final List<DeliveryItem> items;
  final List<DeliveryAttempt> attempts;

  bool get isRetryPending => status == DeliveryStatus.retryPending;

  /// The date worth showing: when it left, else when it is planned.
  DateTime? get displayDate => dispatchedAt ?? scheduledAt;

  /// Why the last failed attempt failed, so a delivery waiting for a retry can say why.
  String? get lastFailureReason {
    for (final attempt in attempts.reversed) {
      if (attempt.status == AttemptStatus.failed) return attempt.failureReasonCode;
    }
    return null;
  }

  factory MyDelivery.fromJson(Map<String, dynamic> json) => MyDelivery(
        id: asString(json['id']),
        deliveryNumber: asString(json['deliveryNumber']),
        status: asString(json['status']),
        scheduledAt: asDateTime(json['scheduledAt']),
        dispatchedAt: asDateTime(json['dispatchedAt']),
        completedAt: asDateTime(json['completedAt']),
        assignedTo: json['assignedTo'] is Map<String, dynamic>
            ? DeliveryStaff.fromJson(json['assignedTo'] as Map<String, dynamic>)
            : null,
        items: asObjectList(json['items']).map(DeliveryItem.fromJson).toList(growable: false),
        attempts: asObjectList(json['attempts']).map(DeliveryAttempt.fromJson).toList(growable: false),
      );
}
