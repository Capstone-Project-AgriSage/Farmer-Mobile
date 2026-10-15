import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Vị trí hiện tại đã đổi thành các ô của form địa chỉ. Ô nào không xác định được thì null (để người dùng tự nhập).
class DetectedAddress {
  const DetectedAddress({
    required this.latitude,
    required this.longitude,
    this.province,
    this.district,
    this.ward,
    this.line,
  });

  final double latitude;
  final double longitude;
  final String? province;
  final String? district;
  final String? ward;

  /// Số nhà + tên đường nếu geocoder biết.
  final String? line;

  /// Có điền được ít nhất một ô chữ không (chỉ có toạ độ thì false).
  bool get hasText =>
      [province, district, ward, line].any((v) => v != null && v.isNotEmpty);
}

/// Phần chữ của một kết quả reverse geocoding. Tách khỏi plugin để kiểm thử thuần Dart.
class PlaceParts {
  const PlaceParts({
    this.administrativeArea,
    this.subAdministrativeArea,
    this.locality,
    this.subLocality,
    this.thoroughfare,
    this.subThoroughfare,
    this.street,
  });

  factory PlaceParts.fromPlacemark(Placemark p) => PlaceParts(
        administrativeArea: p.administrativeArea,
        subAdministrativeArea: p.subAdministrativeArea,
        locality: p.locality,
        subLocality: p.subLocality,
        thoroughfare: p.thoroughfare,
        subThoroughfare: p.subThoroughfare,
        street: p.street,
      );

  final String? administrativeArea;
  final String? subAdministrativeArea;
  final String? locality;
  final String? subLocality;
  final String? thoroughfare;
  final String? subThoroughfare;
  final String? street;
}

String? _blankToNull(String? v) {
  final t = v?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

final _provincePrefix = RegExp(r'^(thành phố|tỉnh|tp\.?|t\.p\.?)\s+', caseSensitive: false);
final _plusCode = RegExp(r'^[0-9A-Z]{4,}\+[0-9A-Z]{2,}');

/// "Thành phố Cần Thơ" -> "Cần Thơ" (người dùng thường gõ không kèm tiền tố; quận/huyện giữ nguyên, vì "Quận 1" mất
/// nghĩa nếu bỏ chữ "Quận").
String? _province(String? raw) {
  final t = _blankToNull(raw);
  return t == null ? null : _blankToNull(t.replaceFirst(_provincePrefix, ''));
}

/// Đổi một kết quả geocoder sang các ô của form. Geocoder không đảm bảo đủ ô (nông thôn thường thiếu số nhà),
/// nên ô nào trống thì để null thay vì đoán.
DetectedAddress addressFromPlace(double latitude, double longitude, PlaceParts p) {
  final province = _province(p.administrativeArea);
  final district = [p.subAdministrativeArea, p.locality]
      .map(_blankToNull)
      .whereType<String>()
      // Thành phố trực thuộc trung ương: locality trùng tên tỉnh, không phải quận/huyện.
      .where((d) => _province(d) != province)
      .firstOrNull;
  final ward = _blankToNull(p.subLocality);

  // "123" + "Đường ABC"; bỏ mã Plus Code và "đường không tên" mà Geocoder trả khi không có tên đường.
  String? road = _blankToNull(p.thoroughfare) ?? _blankToNull(p.street);
  if (road != null &&
      (_plusCode.hasMatch(road) ||
          road.toLowerCase() == 'unnamed road' ||
          road.toLowerCase().contains('không tên'))) {
    road = null;
  }
  final number = _blankToNull(p.subThoroughfare);
  final line = road == null ? null : (number == null ? road : '$number $road');

  return DetectedAddress(
    latitude: latitude,
    longitude: longitude,
    province: province,
    district: district,
    ward: ward,
    line: line,
  );
}

enum LocationProblem { serviceDisabled, denied, deniedForever, timeout }

class LocationException implements Exception {
  const LocationException(this.problem);

  final LocationProblem problem;

  String get message => switch (problem) {
        LocationProblem.serviceDisabled =>
          'Định vị (GPS) đang tắt. Hãy bật vị trí trong Cài đặt rồi thử lại, hoặc nhập địa chỉ bằng tay.',
        LocationProblem.denied =>
          'Bạn chưa cho phép ứng dụng dùng vị trí. Bạn có thể nhập địa chỉ bằng tay.',
        LocationProblem.deniedForever =>
          'Quyền vị trí đang bị tắt cho ứng dụng. Hãy bật lại trong Cài đặt ứng dụng, hoặc nhập địa chỉ bằng tay.',
        LocationProblem.timeout =>
          'Chưa lấy được vị trí. Hãy ra nơi thoáng hơn rồi thử lại, hoặc nhập địa chỉ bằng tay.',
      };

  @override
  String toString() => 'LocationException($problem)';
}

/// Lấy vị trí hiện tại và đổi thành địa chỉ. Ném [LocationException] khi không lấy được toạ độ; nếu có toạ độ mà
/// geocoder không trả địa chỉ thì vẫn trả [DetectedAddress] chỉ có toạ độ.
abstract class LocationService {
  Future<DetectedAddress> detect();
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  /// Backend nhận tối đa 7 chữ số thập phân.
  static double _round7(double v) => double.parse(v.toStringAsFixed(7));

  @override
  Future<DetectedAddress> detect() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationProblem.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        throw const LocationException(LocationProblem.denied);
      case LocationPermission.deniedForever:
        throw const LocationException(LocationProblem.deniedForever);
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      throw const LocationException(LocationProblem.timeout);
    }
    final lat = _round7(position.latitude);
    final lng = _round7(position.longitude);

    try {
      final marks = await Geocoding()
          .placemarkFromCoordinates(lat, lng, locale: const Locale('vi', 'VN'));
      if (marks.isNotEmpty) {
        return addressFromPlace(lat, lng, PlaceParts.fromPlacemark(marks.first));
      }
    } catch (_) {
      // Geocoder vắng (máy không có Google Play Services) hoặc không có mạng: vẫn dùng toạ độ.
    }
    return DetectedAddress(latitude: lat, longitude: lng);
  }
}

final locationServiceProvider =
    Provider<LocationService>((ref) => const DeviceLocationService());
