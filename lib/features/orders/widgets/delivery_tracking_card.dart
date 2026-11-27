import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/order_providers.dart';

/// Nền bản đồ; test thay bằng ô trống để không gọi mạng.
final mapTileProviderProvider = Provider<TileProvider>((ref) => NetworkTileProvider());

/// "Tài xế đang giao": vị trí và đường đi của tài xế trong lúc lượt giao của phiếu này đang chạy (FLOW_2 §9a). Không
/// hiện gì khi chưa bắt đầu, đã giao xong, hoặc không đọc được.
class DeliveryTrackingCard extends ConsumerStatefulWidget {
  const DeliveryTrackingCard({super.key, required this.orderId, required this.deliveryId});

  final String orderId;
  final String deliveryId;

  static const refreshEvery = Duration(seconds: 15);

  @override
  ConsumerState<DeliveryTrackingCard> createState() => _DeliveryTrackingCardState();
}

class _DeliveryTrackingCardState extends ConsumerState<DeliveryTrackingCard> {
  // Cần Thơ, khi chưa có điểm nào.
  static const _storeArea = LatLng(10.0341, 105.7880);
  static final _clock = DateFormat('HH:mm');

  Timer? _timer;

  ({String orderId, String deliveryId}) get _key => (orderId: widget.orderId, deliveryId: widget.deliveryId);

  @override
  void initState() {
    super.initState();
    // Đọc lại khi thẻ đang hiện; rời màn là dừng (không đọc nền). Vị trí cũ vẫn hiện trong lúc đọc lại.
    _timer = Timer.periodic(DeliveryTrackingCard.refreshEvery, (_) => ref.invalidate(deliveryTrackingProvider(_key)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lượt giao vừa kết thúc: đọc lại phiếu giao để thấy kết quả.
    ref.listen(deliveryTrackingProvider(_key), (previous, next) {
      if (previous?.valueOrNull?.inProgress == true && next.valueOrNull?.inProgress == false) {
        ref.invalidate(orderDeliveriesProvider(widget.orderId));
      }
    });
    final tracking = ref.watch(deliveryTrackingProvider(_key)).valueOrNull;
    if (tracking == null || !tracking.inProgress) return const SizedBox.shrink();

    final stale = tracking.isStale(DateTime.now());
    final last = tracking.lastPoint;
    final status = last == null
        ? 'Chưa có tín hiệu vị trí'
        : stale
            ? 'Mất tín hiệu từ ${_clock.format(last.recordedAt!.toLocal())}'
            : 'Cập nhật lúc ${_clock.format(last.recordedAt!.toLocal())}';
    final route = [for (final p in tracking.trail) LatLng(p.latitude, p.longitude)];
    final driver = last == null ? null : LatLng(last.latitude, last.longitude);
    final destination = tracking.destination == null ? null : LatLng(tracking.destination!.latitude, tracking.destination!.longitude);
    final points = [if (driver != null) driver, if (destination != null) destination, ...route];

    return Container(
      key: Key('delivery_tracking_${widget.deliveryId}'),
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tài xế đang giao${tracking.driverName == null ? '' : ': ${tracking.driverName}'}',
                          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                      Text(status,
                          key: const Key('tracking_status'),
                          style: AppTextStyles.caption
                              .copyWith(color: stale ? AppColors.statusWarning : AppColors.statusSuccess)),
                    ],
                  ),
                ),
                if (tracking.driverPhone != null)
                  IconButton(
                    tooltip: 'Gọi tài xế',
                    icon: const Icon(Icons.call, color: AppColors.primary),
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: tracking.driverPhone)),
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: SizedBox(
              height: 220,
              child: FlutterMap(
                // A new camera once the first position arrives.
                key: ValueKey('map_${driver != null}'),
                options: MapOptions(
                  initialCenter: points.isEmpty ? _storeArea : points.first,
                  initialZoom: 14,
                  initialCameraFit: points.length < 2
                      ? null
                      : CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(32), maxZoom: 16),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'vn.agrisage.farmer',
                    tileProvider: ref.watch(mapTileProviderProvider),
                  ),
                  if (route.length > 1)
                    PolylineLayer(polylines: [Polyline(points: route, color: const Color(0xFF2563EB), strokeWidth: 4)]),
                  CircleLayer(circles: [
                    if (destination != null)
                      CircleMarker(
                        point: destination,
                        radius: 7,
                        color: const Color(0xFFEF4444),
                        borderColor: const Color(0xFF991B1B),
                        borderStrokeWidth: 2,
                      ),
                    if (driver != null)
                      CircleMarker(
                        point: driver,
                        radius: 9,
                        color: stale ? const Color(0xFF94A3B8) : const Color(0xFF22C55E),
                        borderColor: stale ? const Color(0xFF475569) : const Color(0xFF166534),
                        borderStrokeWidth: 2,
                      ),
                  ]),
                  const SimpleAttributionWidget(source: Text('OpenStreetMap')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
