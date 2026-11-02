import '../../../core/network/json_utils.dart';
import '../../ai_doctor/data/diagnosis_models.dart' show Treatment, diseaseDisplayName;

/// Loại vấn đề trên ruộng lúa (`problemType` của backend, ADVISORY.md).
abstract class ProblemType {
  static const disease = 'DISEASE';
  static const pest = 'PEST';
  static const weed = 'WEED';
  static const nutrition = 'NUTRITION';
  static const growth = 'GROWTH';

  /// Thứ tự các nhãn lọc ở màn tìm kiếm (null = tất cả).
  static const filters = <String?>[null, disease, pest, weed, nutrition, growth];

  static String label(String? t) => switch (t) {
        null => 'Tất cả',
        disease => 'Bệnh',
        pest => 'Sâu rầy',
        weed => 'Cỏ dại',
        nutrition => 'Dinh dưỡng',
        growth => 'Sinh trưởng, đất',
        _ => t,
      };
}

/// Giai đoạn của lúa (`growthStage`). Không chọn = chưa rõ: hiện mọi sản phẩm phù hợp.
abstract class GrowthStage {
  static const seedling = 'SEEDLING';
  static const tillering = 'TILLERING';
  static const booting = 'BOOTING';
  static const heading = 'HEADING';
  static const ripening = 'RIPENING';

  static const values = <String>[seedling, tillering, booting, heading, ripening];

  static String label(String s) => switch (s) {
        seedling => 'Mạ, sau sạ',
        tillering => 'Đẻ nhánh',
        booting => 'Làm đòng',
        heading => 'Trổ bông',
        ripening => 'Chín',
        _ => s,
      };
}

/// Đơn vị diện tích nông dân hay dùng. Máy chỉ gửi mét vuông (`areaSqm`), 1 công = 1.000 m².
enum AreaUnit {
  cong('công', 1000),
  sao('sào', 360),
  ha('ha', 10000),
  m2('m²', 1);

  const AreaUnit(this.label, this.sqm);

  final String label;
  final double sqm;

  static AreaUnit fromName(String? name) =>
      AreaUnit.values.firstWhere((u) => u.name == name, orElse: () => AreaUnit.cong);
}

/// Tình trạng hàng (`stockStatus`): chỉ có trạng thái, không bao giờ có số lượng tồn.
abstract class AdvisoryStock {
  static const enough = 'ENOUGH';
  static const notEnough = 'NOT_ENOUGH';
  static const outOfStock = 'OUT_OF_STOCK';

  static String label(String s) => switch (s) {
        enough => 'Còn hàng',
        notEnough => 'Không đủ số lượng',
        outOfStock => 'Hết hàng',
        _ => s,
      };
}

/// Lý do không có sản phẩm nào (`emptyReason`).
String? emptyReasonText(String? reason) => switch (reason) {
      null => null,
      'NO_APPROVED_PRODUCT' => 'Cửa hàng chưa có sản phẩm gợi ý cho vấn đề này. Hãy hỏi cửa hàng để được tư vấn.',
      'NO_PRODUCT_FOR_STAGE' =>
        'Chưa có sản phẩm hợp với giai đoạn lúa bạn chọn. Thử chọn giai đoạn khác hoặc bỏ chọn giai đoạn.',
      'NOTHING_IN_STORE' =>
        'Các sản phẩm phù hợp hiện chưa bán hoặc chưa có giá. Hãy hỏi cửa hàng.',
      _ => 'Chưa có sản phẩm gợi ý. Hãy hỏi cửa hàng để được tư vấn.',
    };

/// Một vấn đề trong danh sách tìm kiếm (`GET /api/me/advisory/problems`).
class AdvisoryProblem {
  const AdvisoryProblem({
    required this.id,
    required this.code,
    required this.name,
    required this.problemType,
    this.summary,
    this.matchedBy,
  });

  final String id;
  final String code;
  final String name;
  final String problemType;
  final String? summary;

  /// NAME, KEYWORD hoặc SYMPTOM: nông dân gõ khớp với phần nào.
  final String? matchedBy;

  String get displayName => diseaseDisplayName(code, name);

  factory AdvisoryProblem.fromJson(Map<String, dynamic> json) => AdvisoryProblem(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        problemType: json['problemType'] as String? ?? ProblemType.disease,
        summary: json['summary'] as String?,
        matchedBy: json['matchedBy'] as String?,
      );
}

class AdvisoryProblemDetail {
  const AdvisoryProblemDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.problemType,
    this.description,
    this.symptoms,
    this.causes,
    this.prevention,
  });

  final String id;
  final String code;
  final String name;
  final String problemType;
  final String? description;
  final String? symptoms;
  final String? causes;
  final String? prevention;

  String get displayName => diseaseDisplayName(code, name);

  factory AdvisoryProblemDetail.fromJson(Map<String, dynamic> json) => AdvisoryProblemDetail(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        problemType: json['problemType'] as String? ?? ProblemType.disease,
        description: json['description'] as String?,
        symptoms: json['symptoms'] as String?,
        causes: json['causes'] as String?,
        prevention: json['prevention'] as String?,
      );
}

/// Một dòng quy cách trong kế hoạch mua (số lượng nguyên, giá do server tính).
class AdvisoryPlanLine {
  const AdvisoryPlanLine({
    required this.packagingId,
    required this.packagingName,
    required this.quantity,
    required this.unitPrice,
    required this.lineAmount,
  });

  final String packagingId;
  final String packagingName;
  final int quantity;
  final double unitPrice;
  final double lineAmount;

  factory AdvisoryPlanLine.fromJson(Map<String, dynamic> json) => AdvisoryPlanLine(
        packagingId: json['productPackagingId'] as String? ?? '',
        packagingName: json['packagingName'] as String? ?? '',
        quantity: asInt(json['quantity']) ?? 0,
        unitPrice: asDoubleOr0(json['unitPrice']),
        lineAmount: asDoubleOr0(json['lineAmount']),
      );
}

/// Số lượng cần cho diện tích đã nhập: chia theo quy cách bán, làm tròn lên.
class AdvisoryPlan {
  const AdvisoryPlan({required this.baseQuantity, required this.totalAmount, required this.lines});

  final int baseQuantity;
  final double totalAmount;
  final List<AdvisoryPlanLine> lines;

  factory AdvisoryPlan.fromJson(Map<String, dynamic> json) => AdvisoryPlan(
        baseQuantity: asInt(json['baseQuantity']) ?? 0,
        totalAmount: asDoubleOr0(json['totalAmount']),
        lines: [
          for (final l in (json['lines'] as List? ?? const []))
            AdvisoryPlanLine.fromJson(l as Map<String, dynamic>),
        ],
      );
}

/// Sản phẩm được gợi ý cho vấn đề (đã được cửa hàng duyệt).
class AdvisoryProduct {
  const AdvisoryProduct({
    required this.storeProductId,
    required this.productId,
    required this.name,
    required this.sku,
    required this.group,
    required this.rankOrder,
    required this.reason,
    required this.doseText,
    required this.applications,
    required this.stockStatus,
    this.imageUrl,
    this.registrationSource,
    this.preHarvestDays,
    this.growthStages = const [],
    this.plan,
  });

  /// Mã sản phẩm ở danh mục (`/products/{id}`) và khi thêm vào giỏ.
  final String storeProductId;
  final String productId;
  final String name;
  final String sku;
  final String? imageUrl;

  /// PROTECTION (thuốc bảo vệ thực vật) hoặc NUTRITION (phân bón).
  final String group;
  final int rankOrder;
  final String reason;

  /// Văn bản đăng ký của thuốc (thông tư, trang); phân bón không có.
  final String? registrationSource;
  final String doseText;
  final int applications;
  final int? preHarvestDays;
  final List<String> growthStages;
  final String stockStatus;

  /// null khi chưa nhập diện tích hoặc cửa hàng chưa ghi liều theo ha.
  final AdvisoryPlan? plan;

  bool get inStock => stockStatus != AdvisoryStock.outOfStock;

  factory AdvisoryProduct.fromJson(Map<String, dynamic> json) => AdvisoryProduct(
        storeProductId: json['storeProductId'] as String? ?? '',
        productId: json['productId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        group: json['group'] as String? ?? 'PROTECTION',
        rankOrder: asInt(json['rankOrder']) ?? 0,
        reason: json['reason'] as String? ?? '',
        registrationSource: json['registrationSource'] as String?,
        doseText: json['doseText'] as String? ?? '',
        applications: asInt(json['applications']) ?? 1,
        preHarvestDays: asInt(json['preHarvestDays']),
        growthStages: [for (final s in (json['growthStages'] as List? ?? const [])) s as String],
        stockStatus: json['stockStatus'] as String? ?? AdvisoryStock.enough,
        plan: json['plan'] == null ? null : AdvisoryPlan.fromJson(json['plan'] as Map<String, dynamic>),
      );
}

/// Kết quả tư vấn cho một vấn đề (`POST /api/me/advisory/recommendations`).
class AdvisoryRecommendation {
  const AdvisoryRecommendation({
    required this.sessionId,
    required this.problem,
    required this.careGuidance,
    required this.protection,
    required this.nutrition,
    required this.safetyNote,
    this.areaSqm,
    this.growthStage,
    this.emptyReason,
  });

  final String sessionId;
  final AdvisoryProblemDetail problem;
  final List<Treatment> careGuidance;
  final double? areaSqm;
  final String? growthStage;
  final List<AdvisoryProduct> protection;
  final List<AdvisoryProduct> nutrition;
  final String? emptyReason;
  final String safetyNote;

  bool get hasProducts => protection.isNotEmpty || nutrition.isNotEmpty;

  factory AdvisoryRecommendation.fromJson(Map<String, dynamic> json) => AdvisoryRecommendation(
        sessionId: json['sessionId'] as String? ?? '',
        problem: AdvisoryProblemDetail.fromJson(json['problem'] as Map<String, dynamic>),
        careGuidance: [
          for (final t in (json['careGuidance'] as List? ?? const []))
            Treatment.fromJson(t as Map<String, dynamic>),
        ],
        areaSqm: asDouble(json['areaSqm']),
        growthStage: json['growthStage'] as String?,
        protection: [
          for (final p in (json['protection'] as List? ?? const []))
            AdvisoryProduct.fromJson(p as Map<String, dynamic>),
        ],
        nutrition: [
          for (final p in (json['nutrition'] as List? ?? const []))
            AdvisoryProduct.fromJson(p as Map<String, dynamic>),
        ],
        emptyReason: json['emptyReason'] as String?,
        safetyNote: json['safetyNote'] as String? ?? '',
      );
}

/// Điều kiện của một lần tư vấn; dùng làm khoá của provider nên so sánh theo giá trị.
class AdvisoryQuery {
  const AdvisoryQuery({required this.diseaseId, this.areaSqm, this.growthStage, this.diagnosisCaseId});

  final String diseaseId;
  final double? areaSqm;
  final String? growthStage;

  /// Ca chẩn đoán AI mà nông dân đi từ đó sang (để cửa hàng biết nguồn).
  final String? diagnosisCaseId;

  @override
  bool operator ==(Object other) =>
      other is AdvisoryQuery &&
      other.diseaseId == diseaseId &&
      other.areaSqm == areaSqm &&
      other.growthStage == growthStage &&
      other.diagnosisCaseId == diagnosisCaseId;

  @override
  int get hashCode => Object.hash(diseaseId, areaSqm, growthStage, diagnosisCaseId);
}
