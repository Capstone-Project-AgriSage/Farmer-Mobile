import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_provider.dart';
import '../../ai_doctor/data/diagnosis_models.dart';
import '../../ai_doctor/data/diagnosis_repository.dart';
import '../../orders/data/order_models.dart';
import '../../orders/data/order_repository.dart';
import '../../ai_doctor/providers/diagnosis_providers.dart';
import '../../orders/providers/order_providers.dart';

/// Số đơn theo nhóm + đơn mới nhất, cho thẻ "Đơn hàng của bạn" ở Trang chủ.
class HomeOrderStats {
  const HomeOrderStats({
    required this.pending,
    required this.inProgress,
    required this.done,
    required this.total,
    this.latest,
  });

  /// Chờ cửa hàng xác nhận.
  final int pending;

  /// Đã xác nhận nhưng chưa xong (chuẩn bị, sẵn sàng, đã giao một phần...).
  final int inProgress;

  /// Hoàn thành (kể cả đơn đã huỷ phần còn lại: hàng đã giao đủ phần còn hiệu lực).
  final int done;
  final int total;
  final OrderSummary? latest;
}

/// Backend chỉ lọc được MỘT trạng thái mỗi lần gọi, nên đếm bằng các lệnh
/// `pageSize=1` lấy `totalCount`; "đang xử lý" = tổng trừ các nhóm còn lại (không
/// phải liệt kê từng trạng thái trung gian nên không sót khi backend thêm trạng thái).
final homeOrderStatsProvider = FutureProvider.autoDispose<HomeOrderStats>((ref) async {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  final repo = ref.watch(orderRepositoryProvider);
  final r = await Future.wait([
    repo.list(size: 1),
    repo.list(size: 1, status: OrderStatus.pending),
    repo.list(size: 1, status: OrderStatus.completed),
    repo.list(size: 1, status: OrderStatus.partiallyCancelled),
    repo.list(size: 1, status: OrderStatus.cancelled),
  ]);
  final total = r[0].totalCount;
  final pending = r[1].totalCount;
  final done = r[2].totalCount + r[3].totalCount;
  final cancelled = r[4].totalCount;
  return HomeOrderStats(
    pending: pending,
    inProgress: math.max(0, total - pending - done - cancelled),
    done: done,
    total: total,
    latest: r[0].items.isEmpty ? null : r[0].items.first,
  );
});

/// Ca chẩn đoán mới nhất; null = chưa gửi ảnh nào.
final latestDiagnosisProvider = FutureProvider.autoDispose<DiagnosisSummary?>((ref) async {
  ref.watch(sessionProvider.select((s) => s.user?.id));
  final page = await ref.watch(diagnosisRepositoryProvider).list(size: 1);
  return page.items.isEmpty ? null : page.items.first;
});

/// Làm mới danh sách đơn và thẻ đơn hàng ở Trang chủ sau khi đơn thay đổi.
void invalidateOrders(WidgetRef ref) {
  ref
    ..invalidate(myOrdersProvider)
    ..invalidate(homeOrderStatsProvider);
}

/// Làm mới danh sách chẩn đoán và thẻ chẩn đoán ở Trang chủ.
void invalidateDiagnoses(WidgetRef ref) {
  ref
    ..invalidate(myDiagnosesProvider)
    ..invalidate(latestDiagnosisProvider);
}
