import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_models.dart';
import 'package:farmer_mobile/features/ai_doctor/data/diagnosis_repository.dart';

/// Mặc định là ca AI còn đang phân tích (PROCESSING): chưa có kết quả, huỷ được.
Map<String, dynamic> caseJson(
  String id, {
  String status = 'PROCESSING',
  String? note,
  bool withImage = true,
  Map<String, dynamic>? result,
  Map<String, dynamic>? inconclusive,
  bool? canRetry,
}) =>
    {
      'id': id,
      'caseNumber': 'DG-20261012-$id',
      'status': status,
      'submittedAt': '2026-10-12T02:00:00Z',
      'completedAt': ['AI_COMPLETED', 'VERIFIED', 'INCONCLUSIVE'].contains(status) ? '2026-10-12T05:00:00Z' : null,
      'farmerNote': note,
      'image': withImage
          ? {
              'id': 'img1',
              'imageUrl': 'https://example.invalid/diag/$id.jpg?token=x',
              'expiresAt': '2026-10-12T03:00:00Z',
              'isPrimary': true,
              'fileName': 'leaf.jpg',
            }
          : null,
      'result': result,
      'inconclusive': inconclusive,
      'canRetry': canRetry ?? status == 'FAILED',
    };

/// Mặc định là kết quả của ca cũ đã được cửa hàng xác nhận (VERIFIED). Kết quả AI: `aiResultJson`.
Map<String, dynamic> resultJson({
  String certainty = 'VERIFIED',
  String? hint,
  String code = 'LEAF_BLAST',
  String name = 'Leaf Blast',
  bool healthy = false,
  String? comment = 'Vết bệnh hình thoi điển hình.',
  String? symptoms = 'Vết hình thoi màu nâu xám trên lá.',
  String? prevention = 'Bón phân cân đối, tránh thừa đạm.',
  List<Map<String, dynamic>>? treatments,
  List<Map<String, dynamic>>? products,
}) =>
    {
      'certainty': certainty,
      'hint': hint,
      'disease': {
        'id': 'd1',
        'code': code,
        'name': name,
        'isHealthy': healthy,
        'symptoms': symptoms,
        'prevention': prevention,
      },
      'reviewerComment': comment,
      'treatments': treatments ??
          [
            {
              'id': 't2',
              'type': 'PREVENTIVE',
              'title': 'Giữ ruộng thoáng',
              'instructions': 'Tỉa bớt lá, giữ mực nước hợp lý.',
              'precautions': null,
              'rankOrder': 2,
            },
            {
              'id': 't1',
              'type': 'CHEMICAL',
              'title': 'Phun thuốc đặc trị đạo ôn',
              'instructions': 'Phun 2 lần cách nhau 7 ngày.',
              'precautions': 'Đeo khẩu trang, không phun khi trời nắng gắt.',
              'rankOrder': 1,
              'activeIngredientName': 'Tricyclazole',
            },
          ],
      'products': products ??
          [
            {
              'storeProductId': 'sp2',
              'productId': 'p2',
              'name': 'Thuốc Beam 75WP',
              'sku': 'BEAM',
              'imageUrl': null,
              'reason': 'Đặc trị đạo ôn',
              'rankOrder': 2,
            },
            {
              'storeProductId': 'sp1',
              'productId': 'p1',
              'name': 'Phân NPK',
              'sku': 'NPK',
              'imageUrl': null,
              'reason': null,
              'rankOrder': 1,
            },
          ],
    };

/// Kết quả AI hiện ngay cho nông dân: chắc chắn (có thuốc) hoặc chưa chắc (không thuốc, không sản phẩm).
Map<String, dynamic> aiResultJson({
  bool uncertain = false,
  String code = 'LEAF_BLAST',
  String name = 'Leaf Blast',
  bool healthy = false,
  String? symptoms = 'Vết hình thoi màu nâu xám trên lá.',
  String? prevention = 'Bón phân cân đối, tránh thừa đạm.',
  List<Map<String, dynamic>>? treatments,
  List<Map<String, dynamic>>? products,
}) =>
    resultJson(
      certainty: uncertain ? 'UNCERTAIN' : 'CONFIDENT',
      hint: uncertain ? 'RETAKE_PHOTO_OR_ASK_STORE' : null,
      code: code,
      name: name,
      healthy: healthy,
      comment: null,
      symptoms: symptoms,
      prevention: prevention,
      treatments: treatments ??
          (uncertain
              ? [
                  {
                    'id': 't2',
                    'type': 'PREVENTIVE',
                    'title': 'Giữ ruộng thoáng',
                    'instructions': 'Tỉa bớt lá, giữ mực nước hợp lý.',
                    'precautions': null,
                    'rankOrder': 1,
                  },
                ]
              : null),
      products: products ?? (uncertain || healthy ? const [] : null),
    );

DiagnosisCase caseOf(String id,
        {String status = 'PROCESSING',
        String? note,
        bool withImage = true,
        Map<String, dynamic>? result,
        Map<String, dynamic>? inconclusive,
        bool? canRetry}) =>
    DiagnosisCase.fromJson(caseJson(id,
        status: status,
        note: note,
        withImage: withImage,
        result: result,
        inconclusive: inconclusive,
        canRetry: canRetry));

DiagnosisSummary diagSummaryOf(String id,
        {String status = 'PROCESSING', String? code, String? name, String? certainty}) =>
    DiagnosisSummary(
      id: id,
      caseNumber: 'DG-$id',
      status: status,
      submittedAt: DateTime.utc(2026, 10, 12, 2),
      diseaseCode: code,
      diseaseName: name,
      certainty: certainty,
    );

class FakeDiagnosisRepository extends DiagnosisRepository {
  FakeDiagnosisRepository() : super(Dio());

  final List<String> calls = [];
  Map<String, DiagnosisCase> cases = {};
  List<DiagnosisSummary> list0 = [];
  int pageSize0 = 20;

  Object? createError;
  Object? listError;
  Object? getError;
  Object? cancelError;
  Object? retryError;
  Future<void>? createGate;

  ({PickedPhoto photo, String? note})? lastCreate;
  String? lastCancel;
  String? lastRetry;
  final List<({int page, String? status})> listCalls = [];

  @override
  Future<DiagnosisCase> create({required PickedPhoto photo, String? note}) async {
    calls.add('create');
    lastCreate = (photo: photo, note: note);
    await createGate;
    if (createError != null) throw createError!;
    // Như server thật: AI chạy xong ngay trong yêu cầu gửi ảnh nên ca đã có kết quả.
    final c = caseOf('new', status: 'AI_COMPLETED', note: note, withImage: false, result: aiResultJson());
    cases['new'] = c;
    return c;
  }

  @override
  Future<PagedResult<DiagnosisSummary>> list(
      {int page = 1, String? status, int size = DiagnosisRepository.pageSize}) async {
    calls.add('list');
    listCalls.add((page: page, status: status));
    if (listError != null) throw listError!;
    final filtered = list0.where((c) => status == null || c.status == status).toList();
    final per = size == DiagnosisRepository.pageSize ? pageSize0 : size;
    final items = filtered.skip((page - 1) * per).take(per).toList();
    return PagedResult(
      items: items,
      page: page,
      pageSize: per,
      totalCount: filtered.length,
      totalPages: (filtered.length + per - 1) ~/ per,
    );
  }

  @override
  Future<DiagnosisCase> get(String id) async {
    calls.add('get:$id');
    if (getError != null) throw getError!;
    final c = cases[id];
    if (c == null) {
      throw const ApiException(
          kind: ApiErrorKind.notFound, statusCode: 404, message: 'Không tìm thấy ca chẩn đoán.');
    }
    return c;
  }

  @override
  Future<DiagnosisCase> cancel(String id, {String? reason}) async {
    calls.add('cancel:$id');
    lastCancel = id;
    if (cancelError != null) throw cancelError!;
    final c = caseOf(id, status: 'CANCELLED', withImage: false);
    cases[id] = c;
    return c;
  }

  @override
  Future<DiagnosisCase> retry(String id) async {
    calls.add('retry:$id');
    lastRetry = id;
    if (retryError != null) throw retryError!;
    final c = caseOf(id, status: 'AI_COMPLETED', withImage: false, result: aiResultJson());
    cases[id] = c;
    return c;
  }
}

class FakePhotoPicker implements PhotoPicker {
  /// Ảnh "bị mất" khi Android đóng app lúc đang chụp (trả về khi màn chụp mở lại).
  PickedPhoto? lost;
  PickedPhoto? next = const PickedPhoto(path: 'leaf.jpg', name: 'leaf.jpg', sizeBytes: 200000);
  Object? error;
  final List<PhotoSource> asked = [];

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    asked.add(source);
    if (error != null) throw error!;
    return next;
  }

  @override
  Future<PickedPhoto?> recoverLost() async {
    final p = lost;
    lost = null;
    return p;
  }
}
