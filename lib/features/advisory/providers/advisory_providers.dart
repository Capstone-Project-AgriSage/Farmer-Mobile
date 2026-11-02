import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_prefs.dart';
import '../../payment/data/pending_payment.dart' show KeyValueStore, PrefsKeyValueStore;
import '../data/advisory_models.dart';
import '../data/advisory_repository.dart';

/// Điều kiện tìm vấn đề; khoá của provider nên so sánh theo giá trị.
class AdvisoryProblemQuery {
  const AdvisoryProblemQuery({this.search = '', this.type});

  final String search;

  /// null = mọi loại.
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is AdvisoryProblemQuery && other.search == search && other.type == type;

  @override
  int get hashCode => Object.hash(search, type);
}

final advisoryProblemsProvider = FutureProvider.autoDispose
    .family<List<AdvisoryProblem>, AdvisoryProblemQuery>((ref, q) async {
  final page = await ref
      .watch(advisoryRepositoryProvider)
      .problems(search: q.search.trim().isEmpty ? null : q.search, type: q.type);
  return page.items;
});

/// Mỗi điều kiện (vấn đề, diện tích, giai đoạn) là một lần tư vấn; đổi diện tích thì gọi lại, server cập nhật
/// cùng ca tư vấn thay vì tạo ca mới.
final advisoryRecommendationProvider = FutureProvider.autoDispose
    .family<AdvisoryRecommendation, AdvisoryQuery>(
        (ref, q) => ref.watch(advisoryRepositoryProvider).recommend(q));

/// Diện tích ruộng nông dân nhập lần trước (nhớ trên máy, không bí mật).
class AreaInput {
  const AreaInput(this.value, this.unit);

  final double value;
  final AreaUnit unit;

  double get sqm => value * unit.sqm;

  /// Một ô số, không đuôi `.0` thừa: 3 công, 0,5 ha.
  String get valueText =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString().replaceAll('.', ',');
}

final advisoryAreaStoreProvider = Provider<KeyValueStore>(
    (ref) => PrefsKeyValueStore(ref.watch(sharedPreferencesProvider)));

class AdvisoryAreaController extends Notifier<AreaInput?> {
  static const key = 'agrisage.advisory_area';

  KeyValueStore get _store => ref.read(advisoryAreaStoreProvider);

  @override
  AreaInput? build() {
    final raw = _store.getString(key);
    if (raw == null) return null;
    final parts = raw.split('|');
    final value = parts.length == 2 ? double.tryParse(parts[0]) : null;
    if (value == null || value <= 0) return null;
    return AreaInput(value, AreaUnit.fromName(parts[1]));
  }

  Future<void> save(AreaInput? input) async {
    state = input;
    if (input == null) {
      await _store.remove(key);
    } else {
      await _store.setString(key, '${input.value}|${input.unit.name}');
    }
  }
}

final advisoryAreaProvider =
    NotifierProvider<AdvisoryAreaController, AreaInput?>(AdvisoryAreaController.new);
