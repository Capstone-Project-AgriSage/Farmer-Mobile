import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/json_utils.dart';

/// Trạng thái ca chẩn đoán (`DiagnosisCaseStatus` của backend).
///
/// Nông dân KHÔNG bao giờ thấy kết quả AI: mọi ca đều chờ chuyên gia duyệt.
/// Các trạng thái trung gian của backend đều có nghĩa "đang chờ" với nông dân.
abstract class DiagnosisStatus {
  static const submitted = 'SUBMITTED';
  static const processing = 'PROCESSING';
  static const aiCompleted = 'AI_COMPLETED';
  static const underReview = 'UNDER_REVIEW';
  static const failed = 'FAILED';
  static const verified = 'VERIFIED';
  static const inconclusive = 'INCONCLUSIVE';
  static const cancelled = 'CANCELLED';

  /// Đang chờ chuyên gia (kể cả khi AI lỗi: chuyên gia chẩn đoán tay).
  static bool isWaiting(String s) =>
      s == submitted ||
      s == processing ||
      s == aiCompleted ||
      s == underReview ||
      s == failed;

  /// Backend cho huỷ ở mọi trạng thái chờ.
  static bool canCancel(String s) => isWaiting(s);

  /// Bộ lọc ở lịch sử. Backend chỉ lọc được MỘT trạng thái nên không có bộ lọc
  /// "đang chờ" (gồm 5 trạng thái); các ca đang chờ nằm trong "Tất cả".
  static const filters = <String?>[null, verified, inconclusive, cancelled];

  static String label(String? s) => switch (s) {
        null => 'Tất cả',
        verified => 'Đã có kết quả',
        inconclusive => 'Cần chụp lại',
        cancelled => 'Đã huỷ',
        _ when isWaiting(s) => 'Chờ chuyên gia xem',
        _ => s,
      };

  /// (màu chữ, màu nền)
  static (Color, Color) colors(String s) {
    if (isWaiting(s)) return (AppColors.statusWarning, AppColors.statusWarningSurface);
    return switch (s) {
      verified => (AppColors.statusSuccess, AppColors.statusSuccessSurface),
      inconclusive => (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
      _ => (AppColors.textSecondary, AppColors.surfaceSubtle),
    };
  }
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
  });

  final String type;
  final String title;
  final String instructions;
  final String? precautions;
  final String? reason;
  final int rankOrder;

  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
        precautions: json['precautions'] as String?,
        reason: json['reason'] as String?,
        rankOrder: asInt(json['rankOrder']) ?? 0,
      );
}

/// Sản phẩm chuyên gia gợi ý. Không có giá: app lấy giá từ danh mục khi mở sản phẩm.
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

/// Kết quả đã được chuyên gia xác nhận (chỉ có khi VERIFIED).
class DiagnosisResult {
  const DiagnosisResult({
    required this.disease,
    required this.treatments,
    required this.products,
    this.reviewerComment,
  });

  final Disease disease;
  final String? reviewerComment;
  final List<Treatment> treatments;
  final List<RecommendedProduct> products;

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) => DiagnosisResult(
        disease: Disease.fromJson(json['disease'] as Map<String, dynamic>),
        reviewerComment: json['reviewerComment'] as String?,
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

/// Chuyên gia chưa kết luận được: lời nhắn + gợi ý chụp lại.
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
  });

  final String id;
  final String caseNumber;
  final String status;
  final DateTime submittedAt;
  final DateTime? completedAt;

  /// Chỉ có khi VERIFIED.
  final String? diseaseCode;
  final String? diseaseName;

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
      );
}
