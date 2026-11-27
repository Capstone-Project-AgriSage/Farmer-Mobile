import '../../../core/network/json_utils.dart';

/// Một vị trí của điện thoại tài xế (FLOW_2 §9a).
class TrackPoint {
  const TrackPoint({required this.latitude, required this.longitude, this.recordedAt});

  final double latitude;
  final double longitude;
  final DateTime? recordedAt;

  factory TrackPoint.fromJson(Map<String, dynamic> json) => TrackPoint(
        latitude: asDoubleOr0(json['latitude']),
        longitude: asDoubleOr0(json['longitude']),
        recordedAt: asDate(json['recordedAt']),
      );
}

/// `GET /api/me/orders/{orderId}/deliveries/{deliveryId}/tracking`: tài xế đang ở đâu, chỉ trong lúc lượt giao đang
/// chạy. Giao xong thì [inProgress] = false và không còn vị trí nào.
class DeliveryTracking {
  const DeliveryTracking({
    required this.deliveryId,
    required this.status,
    required this.inProgress,
    this.attemptNumber,
    this.driverName,
    this.driverPhone,
    this.destination,
    this.lastPoint,
    this.trail = const [],
  });

  final String deliveryId;
  final String status;
  final bool inProgress;
  final int? attemptNumber;
  final String? driverName;
  final String? driverPhone;

  /// Địa chỉ giao; null khi địa chỉ chưa có tọa độ.
  final TrackPoint? destination;

  /// null khi điện thoại tài xế chưa gửi vị trí nào.
  final TrackPoint? lastPoint;

  /// Đường đi của lượt giao, cũ nhất trước.
  final List<TrackPoint> trail;

  /// Điểm cuối cũ hơn 3 phút: tài xế có thể đang mất sóng.
  static const staleAfter = Duration(minutes: 3);

  bool isStale(DateTime now) {
    final at = lastPoint?.recordedAt;
    return at == null || now.difference(at) > staleAfter;
  }

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    final destination = json['destination'] as Map<String, dynamic>?;
    final last = json['lastPoint'] as Map<String, dynamic>?;
    return DeliveryTracking(
      deliveryId: json['deliveryId'] as String? ?? '',
      status: json['status'] as String? ?? '',
      inProgress: json['inProgress'] as bool? ?? false,
      attemptNumber: asInt(json['attemptNumber']),
      driverName: driver?['fullName'] as String?,
      driverPhone: driver?['phoneNumber'] as String?,
      destination: destination == null ? null : TrackPoint.fromJson(destination),
      lastPoint: last == null ? null : TrackPoint.fromJson(last),
      trail: [
        for (final p in (json['trail'] as List<dynamic>? ?? const [])) TrackPoint.fromJson(p as Map<String, dynamic>),
      ],
    );
  }
}
