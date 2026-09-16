/// Model cho kết quả chẩn đoán bệnh cây trồng bằng AI
class DiagnoseRecord {
  final String id;
  final String diseaseName;
  final String diseaseNameEn;
  final double confidence;
  final String description;
  final String cause;
  final List<String> symptoms;
  final List<String> treatments;
  final DiagnoseStatus status;
  final DateTime createdAt;
  final List<SuggestedProduct> suggestedProducts;

  const DiagnoseRecord({
    required this.id,
    required this.diseaseName,
    required this.diseaseNameEn,
    required this.confidence,
    required this.description,
    required this.cause,
    required this.symptoms,
    required this.treatments,
    required this.status,
    required this.createdAt,
    this.suggestedProducts = const [],
  });

  bool get isConfident => confidence >= 0.70;
}

enum DiagnoseStatus {
  diagnosed,       // AI đã chẩn đoán xong
  uncertain,       // AI không đủ tự tin
  pendingReview,   // Chờ đại lý duyệt thuốc
  reviewed,        // Đại lý đã gợi ý thuốc
}

/// Sản phẩm thuốc được đại lý gợi ý
class SuggestedProduct {
  final String id;
  final String name;
  final String unit;
  final int price;
  final String usage;
  final String dosage;

  const SuggestedProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.usage,
    required this.dosage,
  });
}
