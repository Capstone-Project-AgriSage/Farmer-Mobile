import '../models/diagnose.dart';

/// Dữ liệu mock cho lịch sử chẩn đoán AI
final List<DiagnoseRecord> mockDiagnoses = [
  DiagnoseRecord(
    id: 'DG-001',
    diseaseName: 'Đạo ôn lá',
    diseaseNameEn: 'Rice Blast',
    confidence: 0.92,
    description:
        'Đạo ôn lá là bệnh phổ biến nhất trên cây lúa, gây ra bởi nấm Pyricularia oryzae. '
        'Bệnh tấn công lá, thân, cổ bông gây thiệt hại nặng nề về năng suất.',
    cause:
        'Do nấm Pyricularia oryzae (Magnaporthe oryzae) gây ra. Phát triển mạnh trong điều kiện '
        'ẩm độ cao (>90%), nhiệt độ 20-28°C, bón thừa đạm.',
    symptoms: [
      'Vết bệnh hình thoi, màu nâu xám, viền nâu đậm',
      'Tâm vết bệnh màu xám trắng, hai đầu nhọn',
      'Khi nặng, các vết bệnh liên kết làm cháy lá',
      'Lá bị bệnh thường khô từ đầu lá vào',
    ],
    treatments: [
      'Phun thuốc trừ nấm chứa Tricyclazole (Beam 75WP) hoặc Isoprothiolane',
      'Giảm lượng đạm bón, cân đối NPK',
      'Tránh bón đạm quá nhiều vào giai đoạn đẻ nhánh',
      'Sử dụng giống kháng bệnh: ST25, OM18, Đài Thơm 8',
      'Giữ mực nước hợp lý trên ruộng',
    ],
    status: DiagnoseStatus.reviewed,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    suggestedProducts: [
      SuggestedProduct(
        id: 'SP-001',
        name: 'Thuốc Trừ Bệnh Beam 75WP',
        unit: 'Gói 100g',
        price: 92000,
        usage: 'Phun đều lên lá khi phát hiện triệu chứng đầu tiên',
        dosage: '1 gói pha 16-20 lít nước, phun cho 500-700m²',
      ),
      SuggestedProduct(
        id: 'SP-002',
        name: 'Thuốc Trừ Nấm Filia 525SE',
        unit: 'Chai 250ml',
        price: 145000,
        usage: 'Phun phòng ngừa hoặc khi bệnh mới xuất hiện',
        dosage: '25ml pha 16 lít nước, phun cho 500m²',
      ),
      SuggestedProduct(
        id: 'SP-003',
        name: 'Phân bón lá Đầu Trâu 502',
        unit: 'Gói 50g',
        price: 35000,
        usage: 'Bổ sung dinh dưỡng giúp cây phục hồi sau bệnh',
        dosage: '1 gói pha 16 lít nước, phun cho 1000m²',
      ),
    ],
  ),
  DiagnoseRecord(
    id: 'DG-002',
    diseaseName: 'Bạc lá',
    diseaseNameEn: 'Bacterial Leaf Blight',
    confidence: 0.85,
    description:
        'Bạc lá do vi khuẩn Xanthomonas oryzae pv. oryzae gây ra. '
        'Là bệnh vi khuẩn nguy hiểm nhất trên lúa, thường xuất hiện vào mùa mưa.',
    cause:
        'Do vi khuẩn Xanthomonas oryzae gây ra. Lây lan qua nước mưa, gió, '
        'côn trùng. Phát triển mạnh khi mưa nhiều, ẩm độ cao.',
    symptoms: [
      'Lá héo và chuyển màu vàng bạc từ mép lá vào',
      'Vết bệnh lan dọc theo gân lá, viền lượn sóng',
      'Giọt keo vi khuẩn xuất hiện vào buổi sáng sớm',
      'Lá bệnh nặng bị khô trắng và rách',
    ],
    treatments: [
      'Phun thuốc chứa đồng: Bordeaux, Copper Hydroxide',
      'Sử dụng kháng sinh nông nghiệp: Kasugamycin',
      'Tiêu hủy tàn dư cây bệnh sau thu hoạch',
      'Xử lý hạt giống trước khi gieo',
    ],
    status: DiagnoseStatus.pendingReview,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  DiagnoseRecord(
    id: 'DG-003',
    diseaseName: 'Không xác định',
    diseaseNameEn: 'Uncertain',
    confidence: 0.35,
    description: 'AI không đủ tự tin để đưa ra kết luận chẩn đoán.',
    cause: '',
    symptoms: [],
    treatments: [],
    status: DiagnoseStatus.uncertain,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  DiagnoseRecord(
    id: 'DG-004',
    diseaseName: 'Khô vằn',
    diseaseNameEn: 'Sheath Blight',
    confidence: 0.78,
    description:
        'Khô vằn là bệnh nấm do Rhizoctonia solani gây ra. '
        'Bệnh thường xuất hiện ở bẹ lá và thân lúa, gây thiệt hại đáng kể về năng suất.',
    cause:
        'Do nấm Rhizoctonia solani gây ra. Phát triển mạnh ở điều kiện nóng ẩm, '
        'mật độ gieo sạ dày, bón thừa đạm.',
    symptoms: [
      'Vết bệnh hình bầu dục trên bẹ lá, viền nâu đậm',
      'Tâm vết bệnh màu xám trắng',
      'Bệnh lan từ gốc lên phía trên',
      'Bẹ lá bị mục, cây dễ đổ ngã',
    ],
    treatments: [
      'Phun thuốc trừ nấm Validamycin (Validacin 5L)',
      'Hexaconazole hoặc Propiconazole',
      'Giảm mật độ gieo sạ, không quá 120kg/ha',
      'Bón phân cân đối, tránh thừa đạm',
    ],
    status: DiagnoseStatus.diagnosed,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
];
