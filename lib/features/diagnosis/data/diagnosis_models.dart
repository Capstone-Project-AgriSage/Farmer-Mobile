import '../../../core/utils/json_utils.dart';

/// `status` of a diagnosis case. The farmer sees only the stage: everything up to the reviewer's decision is "waiting".
abstract final class DiagnosisStatus {
  static const submitted = 'SUBMITTED';
  static const processing = 'PROCESSING';
  static const aiCompleted = 'AI_COMPLETED';
  static const underReview = 'UNDER_REVIEW';
  static const verified = 'VERIFIED';
  static const inconclusive = 'INCONCLUSIVE';
  static const failed = 'FAILED';
  static const cancelled = 'CANCELLED';

  /// The statuses a farmer can filter the list by.
  static const filterable = [verified, inconclusive, cancelled];

  /// The case is with the store: the AI ran (or failed) and a reviewer has not decided yet.
  static bool isWaiting(String status) =>
      status == submitted || status == processing || status == aiCompleted || status == underReview || status == failed;

  /// A farmer can withdraw a case until a reviewer has decided it.
  static bool canCancel(String status) => isWaiting(status);
}

class DiagnosisDisease {
  const DiagnosisDisease({
    required this.id,
    required this.code,
    required this.name,
    required this.isHealthy,
    this.symptoms,
    this.prevention,
  });

  final String id;

  /// `LEAF_BLAST`, `BACTERIAL_LEAF_BLIGHT`, `BROWN_SPOT`, `SHEATH_BLIGHT` or `HEALTHY`.
  final String code;
  final String name;
  final bool isHealthy;
  final String? symptoms;
  final String? prevention;

  factory DiagnosisDisease.fromJson(Map<String, dynamic> json) => DiagnosisDisease(
        id: asString(json['id']),
        code: asString(json['code']),
        name: asString(json['name']),
        isHealthy: asBool(json['isHealthy']),
        symptoms: asStringOrNull(json['symptoms']),
        prevention: asStringOrNull(json['prevention']),
      );
}

/// Guidance the reviewer attached (a way to treat or prevent the disease).
class DiagnosisTreatment {
  const DiagnosisTreatment({
    required this.id,
    required this.type,
    required this.title,
    required this.instructions,
    this.precautions,
    this.rankOrder = 0,
    this.reason,
  });

  final String id;

  /// `CULTURAL`, `CHEMICAL`, `PREVENTIVE` or `OTHER`.
  final String type;
  final String title;
  final String instructions;
  final String? precautions;
  final int rankOrder;
  final String? reason;

  factory DiagnosisTreatment.fromJson(Map<String, dynamic> json) => DiagnosisTreatment(
        id: asString(json['id']),
        type: asString(json['type']),
        title: asString(json['title']),
        instructions: asString(json['instructions']),
        precautions: asStringOrNull(json['precautions']),
        rankOrder: asInt(json['rankOrder']),
        reason: asStringOrNull(json['reason']),
      );
}

/// A store product the reviewer recommended; only products still on sale are sent.
class RecommendedProduct {
  const RecommendedProduct({
    required this.storeProductId,
    required this.productId,
    required this.name,
    required this.sku,
    this.imageUrl,
    this.reason,
    this.rankOrder = 0,
  });

  final String storeProductId;

  /// The id the catalog screens use (`/products/:id`).
  final String productId;
  final String name;
  final String sku;
  final String? imageUrl;
  final String? reason;
  final int rankOrder;

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) => RecommendedProduct(
        storeProductId: asString(json['storeProductId']),
        productId: asString(json['productId']),
        name: asString(json['name']),
        sku: asString(json['sku']),
        imageUrl: asStringOrNull(json['imageUrl']),
        reason: asStringOrNull(json['reason']),
        rankOrder: asInt(json['rankOrder']),
      );
}

/// What the farmer gets once a reviewer verified the case.
class DiagnosisResult {
  const DiagnosisResult({
    required this.disease,
    this.reviewerComment,
    this.treatments = const [],
    this.products = const [],
  });

  final DiagnosisDisease disease;
  final String? reviewerComment;
  final List<DiagnosisTreatment> treatments;
  final List<RecommendedProduct> products;

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) => DiagnosisResult(
        disease: DiagnosisDisease.fromJson(json['disease'] is Map<String, dynamic> ? json['disease'] as Map<String, dynamic> : const {}),
        reviewerComment: asStringOrNull(json['reviewerComment']),
        treatments: asObjectList(json['treatments']).map(DiagnosisTreatment.fromJson).toList(growable: false),
        products: asObjectList(json['products']).map(RecommendedProduct.fromJson).toList(growable: false),
      );
}

/// The reviewer could not conclude: the farmer is asked to send a better photo.
class DiagnosisInconclusive {
  const DiagnosisInconclusive({this.comment, this.hint = 'RETAKE_PHOTO'});

  final String? comment;
  final String hint;

  factory DiagnosisInconclusive.fromJson(Map<String, dynamic> json) => DiagnosisInconclusive(
        comment: asStringOrNull(json['comment']),
        hint: asString(json['hint'], 'RETAKE_PHOTO'),
      );
}

/// The photo of a case as a signed link that works for a limited time ([expiresAt]).
class DiagnosisPhoto {
  const DiagnosisPhoto({required this.id, required this.imageUrl, this.expiresAt});

  final String id;
  final String imageUrl;
  final DateTime? expiresAt;

  factory DiagnosisPhoto.fromJson(Map<String, dynamic> json) => DiagnosisPhoto(
        id: asString(json['id']),
        imageUrl: asString(json['imageUrl']),
        expiresAt: asDateTime(json['expiresAt']),
      );
}

class DiagnosisCaseListItem {
  const DiagnosisCaseListItem({
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
  final DateTime? submittedAt;
  final DateTime? completedAt;

  /// Only once the case is verified.
  final String? diseaseCode;
  final String? diseaseName;

  factory DiagnosisCaseListItem.fromJson(Map<String, dynamic> json) => DiagnosisCaseListItem(
        id: asString(json['id']),
        caseNumber: asString(json['caseNumber']),
        status: asString(json['status']),
        submittedAt: asDateTime(json['submittedAt']),
        completedAt: asDateTime(json['completedAt']),
        diseaseCode: asStringOrNull(json['diseaseCode']),
        diseaseName: asStringOrNull(json['diseaseName']),
      );
}

class DiagnosisCase {
  const DiagnosisCase({
    required this.id,
    required this.caseNumber,
    required this.status,
    required this.submittedAt,
    this.completedAt,
    this.farmerNote,
    this.photo,
    this.result,
    this.inconclusive,
  });

  final String id;
  final String caseNumber;
  final String status;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final String? farmerNote;
  final DiagnosisPhoto? photo;

  /// Set only when the case is VERIFIED.
  final DiagnosisResult? result;

  /// Set only when the case is INCONCLUSIVE.
  final DiagnosisInconclusive? inconclusive;

  bool get isWaiting => DiagnosisStatus.isWaiting(status);
  bool get isVerified => status == DiagnosisStatus.verified && result != null;
  bool get isInconclusive => status == DiagnosisStatus.inconclusive;
  bool get isCancelled => status == DiagnosisStatus.cancelled;
  bool get canCancel => DiagnosisStatus.canCancel(status);

  factory DiagnosisCase.fromJson(Map<String, dynamic> json) => DiagnosisCase(
        id: asString(json['id']),
        caseNumber: asString(json['caseNumber']),
        status: asString(json['status']),
        submittedAt: asDateTime(json['submittedAt']),
        completedAt: asDateTime(json['completedAt']),
        farmerNote: asStringOrNull(json['farmerNote']),
        photo: json['image'] is Map<String, dynamic> ? DiagnosisPhoto.fromJson(json['image'] as Map<String, dynamic>) : null,
        result: json['result'] is Map<String, dynamic> ? DiagnosisResult.fromJson(json['result'] as Map<String, dynamic>) : null,
        inconclusive: json['inconclusive'] is Map<String, dynamic>
            ? DiagnosisInconclusive.fromJson(json['inconclusive'] as Map<String, dynamic>)
            : null,
      );
}
