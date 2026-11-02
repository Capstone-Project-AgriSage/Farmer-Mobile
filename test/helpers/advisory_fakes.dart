import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/features/advisory/data/advisory_models.dart';
import 'package:farmer_mobile/features/advisory/data/advisory_repository.dart';

Map<String, dynamic> problemJson(
  String code,
  String name, {
  String type = 'DISEASE',
  String? summary = 'Vết bệnh trên lá.',
  String matchedBy = 'NAME',
}) =>
    {
      'id': 'd-$code',
      'code': code,
      'name': name,
      'problemType': type,
      'summary': summary,
      'matchedBy': matchedBy,
    };

Map<String, dynamic> planJson({
  int baseQuantity = 3,
  double total = 255000,
  String packagingId = 'pk1',
  String packaging = 'Chai 100 ml',
  int quantity = 3,
  double unitPrice = 85000,
}) =>
    {
      'baseQuantity': baseQuantity,
      'totalAmount': total,
      'lines': [
        {
          'productPackagingId': packagingId,
          'packagingName': packaging,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'lineAmount': unitPrice * quantity,
        },
      ],
    };

Map<String, dynamic> advisoryProductJson(
  String id,
  String name, {
  String group = 'PROTECTION',
  String stock = 'ENOUGH',
  Map<String, dynamic>? plan,
  bool withPlan = true,
  int? preHarvestDays = 14,
  String? registrationSource = 'TT 75/2025/TT-BNNMT, Phụ lục I, tr. 187',
  String doseText = '0,25-0,3 lít/ha pha trong 500-600 lít nước.',
  int applications = 1,
}) =>
    {
      'storeProductId': id,
      'productId': 'p-$id',
      'name': name,
      'sku': 'SKU-$id',
      'imageUrl': null,
      'group': group,
      'rankOrder': 1,
      'reason': group == 'PROTECTION' ? 'Đăng ký phòng trừ: Khô vằn' : 'Cung cấp đạm cho lúa',
      'registrationSource': group == 'PROTECTION' ? registrationSource : null,
      'doseText': doseText,
      'applications': applications,
      'preHarvestDays': preHarvestDays,
      'growthStages': <String>[],
      'stockStatus': stock,
      'plan': withPlan ? (plan ?? planJson()) : null,
    };

Map<String, dynamic> recommendationJson({
  String code = 'SHEATH_BLIGHT',
  String name = 'Bệnh khô vằn',
  String type = 'DISEASE',
  double? areaSqm,
  String? growthStage,
  List<Map<String, dynamic>>? protection,
  List<Map<String, dynamic>>? nutrition,
  String? emptyReason,
  List<Map<String, dynamic>>? care,
}) =>
    {
      'sessionId': 'sess-1',
      'problem': {
        'id': 'd-$code',
        'code': code,
        'name': name,
        'problemType': type,
        'description': null,
        'symptoms': 'Vết bệnh như da hổ trên bẹ lá.',
        'causes': null,
        'prevention': null,
      },
      'careGuidance': care ??
          [
            {
              'id': 't1',
              'type': 'CULTURAL',
              'title': 'Giảm đạm, làm thông thoáng ruộng',
              'instructions': 'Ngưng bón đạm, giữ ruộng thông thoáng.',
              'precautions': null,
              'rankOrder': 1,
            },
          ],
      'areaSqm': areaSqm,
      'growthStage': growthStage,
      'protection': protection ?? [advisoryProductJson('sp1', 'Tilt Super 300EC')],
      'nutrition': nutrition ?? <Map<String, dynamic>>[],
      'emptyReason': emptyReason,
      'safetyNote': 'Đọc kỹ nhãn trước khi dùng, mang đồ bảo hộ, tuân thủ thời gian cách ly.',
    };

/// Thay cho `AdvisoryRepository`: ghi lại mọi lần gọi để test kiểm tra điều kiện gửi lên.
class FakeAdvisoryRepository extends AdvisoryRepository {
  FakeAdvisoryRepository() : super(Dio());

  List<Map<String, dynamic>> problemRows = [
    problemJson('LEAF_BLAST', 'Leaf Blast', summary: 'Vết hình thoi trên lá.'),
    problemJson('BROWN_PLANTHOPPER', 'Rầy nâu', type: 'PEST', summary: 'Lúa cháy từng chòm.'),
    problemJson('NITROGEN_DEFICIENCY', 'Lúa vàng lá do thiếu đạm', type: 'NUTRITION'),
  ];

  /// Câu trả lời cho lần tư vấn tiếp theo (có thể đổi theo diện tích / giai đoạn trong test).
  Map<String, dynamic> Function(AdvisoryQuery query) answer = (q) => recommendationJson(areaSqm: q.areaSqm, growthStage: q.growthStage);

  final List<({String? search, String? type})> problemCalls = [];
  final List<AdvisoryQuery> recommendCalls = [];
  Object? problemError;
  Object? recommendError;

  @override
  Future<PagedResult<AdvisoryProblem>> problems({String? search, String? type, int page = 1}) async {
    problemCalls.add((search: search, type: type));
    if (problemError != null) throw problemError!;
    final text = _fold(search ?? '');
    final rows = problemRows.where((r) {
      final okType = type == null || r['problemType'] == type;
      final okText = text.isEmpty || _fold(r['name'] as String).contains(text) || _fold(r['summary'] as String? ?? '').contains(text);
      return okType && okText;
    }).toList();
    return PagedResult(
      items: [for (final r in rows) AdvisoryProblem.fromJson(r)],
      page: 1,
      pageSize: 50,
      totalCount: rows.length,
      totalPages: 1,
    );
  }

  @override
  Future<AdvisoryRecommendation> recommend(AdvisoryQuery query) async {
    recommendCalls.add(query);
    if (recommendError != null) throw recommendError!;
    return AdvisoryRecommendation.fromJson(answer(query));
  }

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
      .replaceAll(RegExp('[èéẹẻẽêềếệểễ]'), 'e')
      .replaceAll(RegExp('[ìíịỉĩ]'), 'i')
      .replaceAll(RegExp('[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
      .replaceAll(RegExp('[ùúụủũưừứựửữ]'), 'u')
      .replaceAll(RegExp('[ỳýỵỷỹ]'), 'y')
      .replaceAll('đ', 'd');
}
