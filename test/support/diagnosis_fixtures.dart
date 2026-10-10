// Shapes follow MyDiagnosisCaseResponse / MyDiagnosisCaseListItem (AI_DIAGNOSIS.md section 6).

const _photo = {
  'id': 'img-1',
  'imageUrl': 'https://storage.test/diagnosis-images/img-1.jpg?token=abc',
  'expiresAt': '2026-10-10T10:00:00+00:00',
};

Map<String, dynamic> waitingCaseJson({String id = 'dg-1', String status = 'AI_COMPLETED', String? note = 'Lá vàng từ chóp'}) => {
      'id': id,
      'caseNumber': 'DG-20261010-0001',
      'status': status,
      'submittedAt': '2026-10-10T09:10:00+00:00',
      'completedAt': null,
      'farmerNote': note,
      'image': _photo,
      'result': null,
      'inconclusive': null,
    };

const verifiedResultJson = {
  'disease': {
    'id': 'ds-1',
    'code': 'LEAF_BLAST',
    'name': 'Đạo ôn',
    'isHealthy': false,
    'symptoms': 'Vết bệnh hình thoi, tâm xám xanh, viền nâu.',
    'prevention': 'Bón phân cân đối, tránh thừa đạm.',
  },
  'reviewerComment': 'Vết bệnh điển hình, nên xử lý sớm.',
  'treatments': [
    {
      'id': 't-1',
      'type': 'CHEMICAL',
      'title': 'Phun thuốc đặc trị đạo ôn',
      'instructions': 'Phun khi bệnh mới xuất hiện, lặp lại sau 7 ngày.',
      'precautions': 'Không phun lúc nắng gắt.',
      'rankOrder': 1,
      'reason': null,
    },
    {
      'id': 't-2',
      'type': 'CULTURAL',
      'title': 'Giữ mực nước ruộng',
      'instructions': 'Giữ nước ổn định, không để ruộng khô.',
      'precautions': null,
      'rankOrder': 2,
      'reason': null,
    },
  ],
  'products': [
    {
      'storeProductId': 'sp-1',
      'productId': 'p-1',
      'name': 'Thuốc trừ bệnh Fuji-One 40EC',
      'sku': 'FUJI-40',
      'imageUrl': 'https://cdn.test/fuji.jpg',
      'reason': 'Đặc trị đạo ôn lá',
      'rankOrder': 1,
    },
  ],
};

Map<String, dynamic> verifiedCaseJson({String id = 'dg-1', Map<String, dynamic>? result}) => {
      ...waitingCaseJson(id: id, status: 'VERIFIED'),
      'completedAt': '2026-10-10T11:30:00+00:00',
      'result': result ?? verifiedResultJson,
    };

Map<String, dynamic> inconclusiveCaseJson({String id = 'dg-1', String? comment = 'Ảnh bị mờ, chưa thấy rõ vết bệnh.'}) => {
      ...waitingCaseJson(id: id, status: 'INCONCLUSIVE'),
      'completedAt': '2026-10-10T11:30:00+00:00',
      'inconclusive': {'comment': comment, 'hint': 'RETAKE_PHOTO'},
    };

Map<String, dynamic> cancelledCaseJson({String id = 'dg-1'}) => waitingCaseJson(id: id, status: 'CANCELLED');

Map<String, dynamic> caseListRow({
  String id = 'dg-1',
  String number = 'DG-20261010-0001',
  String status = 'AI_COMPLETED',
  String? diseaseCode,
  String? diseaseName,
}) =>
    {
      'id': id,
      'caseNumber': number,
      'status': status,
      'submittedAt': '2026-10-10T09:10:00+00:00',
      'completedAt': null,
      'diseaseCode': diseaseCode,
      'diseaseName': diseaseName,
    };
