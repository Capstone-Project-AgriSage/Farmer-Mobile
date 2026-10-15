import 'package:farmer_mobile/features/profile/data/location_service.dart';

/// Bộ định vị giả cho test: trả sẵn một kết quả hoặc ném lỗi.
class FakeLocationService implements LocationService {
  DetectedAddress result = const DetectedAddress(
    latitude: 10.0452,
    longitude: 105.7469,
    province: 'Cần Thơ',
    district: 'Huyện Thới Lai',
    ward: 'Xã Thới Tân',
    line: '12 Đường Tỉnh 922',
  );

  /// Nếu khác null thì [detect] ném lỗi này.
  Object? error;

  int calls = 0;

  @override
  Future<DetectedAddress> detect() async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}
