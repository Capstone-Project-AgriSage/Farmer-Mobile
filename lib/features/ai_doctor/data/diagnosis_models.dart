import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/json_utils.dart';

/// Trạng thái ca chẩn đoán (`DiagnosisCaseStatus` của backend).
///
/// Từ 21/10/2026 không còn chuyên gia duyệt (AI_DIAGNOSIS.md 2.0): AI phân tích xong là nông dân thấy kết quả
/// ngay (AI_COMPLETED). UNDER_REVIEW, VERIFIED, INCONCLUSIVE chỉ còn ở các ca cũ.
abstract class DiagnosisStatus {
  static const submitted = 'SUBMITTED';
  static const processing = 'PROCESSING';
  static const aiCompleted = 'AI_COMPLETED';
  static const underReview = 'UNDER_REVIEW';
  static const failed = 'FAILED';
  static const verified = 'VERIFIED';
  static const inconclusive = 'INCONCLUSIVE';
  static const cancelled = 'CANCELLED';

  /// AI đang phân tích (thường chỉ vài giây).
  static bool isWaiting(String s) => s == submitted || s == processing;

  /// Chỉ huỷ khi chưa có kết quả: đang phân tích hoặc AI chưa phân tích được.
  static bool canCancel(String s) => isWaiting(s) || s == failed;

  /// Bộ lọc ở lịch sử (backend lọc MỘT trạng thái). Ca cũ đã duyệt nằm trong "Tất cả".
  static const filters = <String?>[null, aiCompleted, failed, cancelled];

  static String label(String? s) => switch (s) {
        null => 'Tất cả',
        aiCompleted || underReview => 'Đã có kết quả',
        verified => 'Đã xác nhận',
        inconclusive => 'Cần chụp lại',
        failed => 'Chưa phân tích được',
        cancelled => 'Đã huỷ',
        _ when isWaiting(s) => 'Đang phân tích',
        _ => s,
      };

  /// (màu chữ, màu nền)
  static (Color, Color) colors(String s) {
    if (isWaiting(s)) return (AppColors.statusWarning, AppColors.statusWarningSurface);
    return switch (s) {
      aiCompleted || underReview || verified => (AppColors.statusSuccess, AppColors.statusSuccessSurface),
      failed => (AppColors.statusError, AppColors.statusErrorSurface),
      inconclusive => (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
      _ => (AppColors.textSecondary, AppColors.surfaceSubtle),
    };
  }
}

/// Mức chắc chắn của kết quả (`result.certainty`). Nông dân không bao giờ thấy con số xác suất.
abstract class DiagnosisCertainty {
  /// AI đạt ngưỡng: có cách xử lý và sản phẩm gợi ý.
  static const confident = 'CONFIDENT';

  /// AI chưa chắc: chỉ có bệnh đoán nhiều nhất, không có thuốc, khuyên chụp lại hoặc hỏi cửa hàng.
  static const uncertain = 'UNCERTAIN';

  /// Ca cũ đã được cửa hàng duyệt trước 21/10/2026.
  static const verified = 'VERIFIED';
}

/// Tên tiếng Việt của 5 lớp bệnh backend dùng (`diseases.code`). Tên backend là
/// tiếng Anh nên ưu tiên tên này khi biết mã.
String diseaseDisplayName(String code, String backendName) =>
    switch (code) {
      'LEAF_BLAST' => 'Đạo ôn lá',
      'BACTERIAL_LEAF_BLIGHT' => 'Bạc lá',
      'BROWN_SPOT' => 'Đốm nâu',
      'SHEATH_BLIGHT' => 'Khô vằn',
      'HEALTHY' => 'Lá khoẻ mạnh',
      _ => backendName,
    };

String treatmentTypeLabel(String t) => switch (t) {
      'CULTURAL' => 'Biện pháp canh tác',
      'CHEMICAL' => 'Thuốc / hoá chất',
      'PREVENTIVE' => 'Phòng ngừa',
      'OTHER' => 'Khác',
      _ => t,
    };

class DiagnosisImage {
  const DiagnosisImage({required this.url, this.expiresAt});

  /// URL có chữ ký, hết hạn sau ~1 giờ (xem `expiresAt`).
  final String url;
  final DateTime? expiresAt;

  factory DiagnosisImage.fromJson(Map<String, dynamic> json) => DiagnosisImage(
        url: json['imageUrl'] as String? ?? '',
        expiresAt: asDate(json['expiresAt']),
      );
}

class Disease {
  const Disease({
    required this.id,
    required this.code,
    required this.name,
    required this.isHealthy,
    this.symptoms,
    this.prevention,
  });

  final String id;
  final String code;
  final String name;
  final bool isHealthy;
  final String? symptoms;
  final String? prevention;

  String get displayName => diseaseDisplayName(code, name);

  factory Disease.fromJson(Map<String, dynamic> json) => Disease(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isHealthy: json['isHealthy'] as bool? ?? false,
        symptoms: json['symptoms'] as String?,
        prevention: json['prevention'] as String?,
      );
}

class Treatment {
  const Treatment({
    required this.type,
    required this.title,
    required this.instructions,
    this.precautions,
    this.reason,
    this.rankOrder = 0,
    this.activeIngredientName,
  });

  final String type;
  final String title;
  final String instructions;
  final String? precautions;
  final String? reason;
  final int rankOrder;

  /// Hoạt chất của cách xử lý (thường với thuốc / hoá chất).
  final String? activeIngredientName;

  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
        precautions: json['precautions'] as String?,
        reason: json['reason'] as String?,
        rankOrder: asInt(json['rankOrder']) ?? 0,
        activeIngredientName: json['activeIngredientName'] as String?,
      );
}

/// Sản phẩm gợi ý (chứa hoạt chất của cách xử lý bệnh, hoặc do cửa hàng chọn ở ca cũ).
/// Không có giá: app lấy giá từ danh mục khi mở sản phẩm.
class RecommendedProduct {
  const RecommendedProduct({
    required this.storeProductId,
    required this.name,
    required this.sku,
    this.imageUrl,
    this.reason,
    this.rankOrder = 0,
  });

  /// Dùng làm mã sản phẩm ở danh mục (`/api/catalog/products/{id}`).
  final String storeProductId;
  final String name;
  final String sku;
  final String? imageUrl;
  final String? reason;
  final int rankOrder;

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) => RecommendedProduct(
        storeProductId: json['storeProductId'] as String,
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        reason: json['reason'] as String?,
        rankOrder: asInt(json['rankOrder']) ?? 0,
      );
}

/// Kết quả nông dân đọc: của AI (CONFIDENT / UNCERTAIN) hoặc của cửa hàng ở ca cũ (VERIFIED).
class DiagnosisResult {
  const DiagnosisResult({
    required this.disease,
    required this.treatments,
    required this.products,
    this.reviewerComment,
    this.certainty = DiagnosisCertainty.verified,
    this.hint,
  });

  final Disease disease;
  final String? reviewerComment;
  final List<Treatment> treatments;
  final List<RecommendedProduct> products;
  final String certainty;

  /// `RETAKE_PHOTO_OR_ASK_STORE` khi AI chưa chắc.
  final String? hint;

  bool get isUncertain => certainty == DiagnosisCertainty.uncertain;
  bool get isFromAi => certainty != DiagnosisCertainty.verified;

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) => DiagnosisResult(
        disease: Disease.fromJson(json['disease'] as Map<String, dynamic>),
        reviewerComment: json['reviewerComment'] as String?,
        certainty: json['certainty'] as String? ?? DiagnosisCertainty.verified,
        hint: json['hint'] as String?,
        treatments: [
          for (final t in (json['treatments'] as List? ?? const []))
            Treatment.fromJson(t as Map<String, dynamic>),
        ]..sort((a, b) => a.rankOrder.compareTo(b.rankOrder)),
        products: [
          for (final p in (json['products'] as List? ?? const []))
            RecommendedProduct.fromJson(p as Map<String, dynamic>),
        ]..sort((a, b) => a.rankOrder.compareTo(b.rankOrder)),
      );
}

/// Ca cũ cửa hàng chưa kết luận được: lời nhắn + gợi ý chụp lại.
class DiagnosisInconclusive {
  const DiagnosisInconclusive({this.comment, this.hint});

  final String? comment;
  final String? hint;

  factory DiagnosisInconclusive.fromJson(Map<String, dynamic> json) =>
      DiagnosisInconclusive(
        comment: json['comment'] as String?,
        hint: json['hint'] as String?,
      );
}

/// Dòng trong lịch sử (`MyDiagnosisCaseListItem`).
class DiagnosisSummary {
  const DiagnosisSummary({
    required this.id,
    required this.caseNumber,
    required this.status,
    required this.submittedAt,
    this.completedAt,
    this.diseaseCode,
    this.diseaseName,
    this.certainty,
  });

  final String id;
  final String caseNumber;
  final String status;
  final DateTime submittedAt;
  final DateTime? completedAt;

  /// Bệnh AI đoán (hoặc cửa hàng đã xác nhận ở ca cũ); null khi chưa có kết quả.
  final String? diseaseCode;
  final String? diseaseName;

  /// CONFIDENT / UNCERTAIN / VERIFIED, null khi chưa có kết quả.
  final String? certainty;

  bool get isUncertain => certainty == DiagnosisCertainty.uncertain;

  String? get diseaseDisplay => diseaseCode == null
      ? diseaseName
      : diseaseDisplayName(diseaseCode!, diseaseName ?? '');

  factory DiagnosisSummary.fromJson(Map<String, dynamic> json) => DiagnosisSummary(
        id: json['id'] as String,
        caseNumber: json['caseNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        submittedAt: asDate(json['submittedAt']) ?? DateTime.now(),
        completedAt: asDate(json['completedAt']),
        diseaseCode: json['diseaseCode'] as String?,
        diseaseName: json['diseaseName'] as String?,
        certainty: json['certainty'] as String?,
      );
}

/// Chi tiết ca (`MyDiagnosisCaseResponse`).
class DiagnosisCase {
  const DiagnosisCase({
    required this.id,
    required this.caseNumber,
    required this.status,
    required this.submittedAt,
    this.completedAt,
    this.note,
    this.image,
    this.result,
    this.inconclusive,
    this.canRetry = false,
  });

  final String id;
  final String caseNumber;
  final String status;
  final DateTime submittedAt;
  final DateTime? completedAt;
  final String? note;
  final DiagnosisImage? image;
  final DiagnosisResult? result;
  final DiagnosisInconclusive? inconclusive;

  /// AI chưa phân tích được (hoặc ca bị gián đoạn): gửi lại để AI phân tích.
  final bool canRetry;

  bool get isWaiting => DiagnosisStatus.isWaiting(status);
  bool get canCancel => DiagnosisStatus.canCancel(status);

  factory DiagnosisCase.fromJson(Map<String, dynamic> json) => DiagnosisCase(
        id: json['id'] as String,
        caseNumber: json['caseNumber'] as String? ?? '',
        status: json['status'] as String? ?? '',
        submittedAt: asDate(json['submittedAt']) ?? DateTime.now(),
        completedAt: asDate(json['completedAt']),
        note: json['farmerNote'] as String?,
        image: json['image'] == null
            ? null
            : DiagnosisImage.fromJson(json['image'] as Map<String, dynamic>),
        result: json['result'] == null
            ? null
            : DiagnosisResult.fromJson(json['result'] as Map<String, dynamic>),
        inconclusive: json['inconclusive'] == null
            ? null
            : DiagnosisInconclusive.fromJson(json['inconclusive'] as Map<String, dynamic>),
        canRetry: json['canRetry'] as bool? ?? false,
      );
}
