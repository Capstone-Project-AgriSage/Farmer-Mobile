import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/json_utils.dart';
import '../../../core/storage/app_prefs.dart';
import '../../payment/data/pending_payment.dart' show KeyValueStore, PrefsKeyValueStore;

/// Danh mục cây trồng của backend (CropCatalog, AI_DIAGNOSIS.md 2.2), đúng thứ tự hiển thị. Vấn đề không ghi cây là lúa.
abstract class Crops {
  static const rice = 'RICE';
  static const all = [rice, 'DURIAN', 'COFFEE', 'CORN', 'MANGO'];
  static const _labels = {
    rice: 'Lúa',
    'DURIAN': 'Sầu riêng',
    'COFFEE': 'Cà phê',
    'CORN': 'Bắp (ngô)',
    'MANGO': 'Xoài',
  };

  static String label(String? code) => _labels[code ?? rice] ?? code ?? 'Lúa';

  /// "lá lúa", "lá sầu riêng": dùng trong câu (chữ thường).
  static String leafOf(String? code) => 'lá ${label(code).toLowerCase()}';
}

class CropDisease {
  const CropDisease({required this.code, required this.name});

  final String code;
  final String name;

  factory CropDisease.fromJson(Map<String, dynamic> json) =>
      CropDisease(code: json['code'] as String? ?? '', name: json['name'] as String? ?? '');
}

/// Một cây nông dân chọn được trước khi gửi ảnh (`GET /api/me/diagnosis/crops`): chỉ những cây mà mô hình AI đang
/// dùng nhận được ít nhất một bệnh.
class DiagnosisCrop {
  const DiagnosisCrop({
    required this.code,
    required this.name,
    this.diseaseCount = 0,
    this.photoDiagnosis = true,
    this.diseases = const [],
  });

  final String code;
  final String name;
  final int diseaseCount;
  final bool photoDiagnosis;
  final List<CropDisease> diseases;

  factory DiagnosisCrop.fromJson(Map<String, dynamic> json) => DiagnosisCrop(
        code: json['code'] as String? ?? Crops.rice,
        name: json['name'] as String? ?? Crops.label(json['code'] as String?),
        diseaseCount: asInt(json['diseaseCount']) ?? 0,
        photoDiagnosis: json['photoDiagnosis'] as bool? ?? true,
        diseases: [
          for (final d in (json['diseases'] as List? ?? const []))
            CropDisease.fromJson(d as Map<String, dynamic>),
        ],
      );
}

final cropChoiceStoreProvider = Provider<KeyValueStore>(
    (ref) => PrefsKeyValueStore(ref.watch(sharedPreferencesProvider)));

/// Cây nông dân chọn lần trước, nhớ trên máy (không bí mật): màn chụp ảnh và màn tư vấn mở sẵn cây này.
class LastCropController extends Notifier<String?> {
  static const key = 'agrisage.last_crop';

  KeyValueStore get _store => ref.read(cropChoiceStoreProvider);

  @override
  String? build() => _store.getString(key);

  Future<void> save(String? crop) async {
    if (crop == state) return;
    state = crop;
    if (crop == null) {
      await _store.remove(key);
    } else {
      await _store.setString(key, crop);
    }
  }
}

final lastCropProvider = NotifierProvider<LastCropController, String?>(LastCropController.new);
