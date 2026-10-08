import '../../../core/utils/json_utils.dart';

abstract final class Gender {
  static const male = 'MALE';
  static const female = 'FEMALE';
  static const other = 'OTHER';

  static const all = [male, female, other];

  static String label(String? code) => switch (code) {
        male => 'Nam',
        female => 'Nữ',
        other => 'Khác',
        _ => 'Chưa cập nhật',
      };
}

/// `GET /api/me/profile`. Phone and email belong to the account and cannot be changed here.
class FarmerProfile {
  const FarmerProfile({
    required this.farmerProfileId,
    required this.fullName,
    this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.customerGroupName,
  });

  final String farmerProfileId;
  final String fullName;
  final String? phoneNumber;
  final String? email;

  /// A calendar date (UTC midnight of that date).
  final DateTime? dateOfBirth;
  final String? gender;
  final String? customerGroupName;

  factory FarmerProfile.fromJson(Map<String, dynamic> json) {
    final group = json['customerGroup'];
    return FarmerProfile(
      farmerProfileId: asString(json['farmerProfileId']),
      fullName: asString(json['fullName']),
      phoneNumber: asStringOrNull(json['phoneNumber']),
      email: asStringOrNull(json['email']),
      dateOfBirth: asDateTime(json['dateOfBirth']),
      gender: asStringOrNull(json['gender']),
      customerGroupName: group is Map<String, dynamic> ? asStringOrNull(group['name']) : null,
    );
  }
}

/// What the farmer may change about themselves.
class ProfileUpdate {
  const ProfileUpdate({required this.fullName, this.dateOfBirth, this.gender});

  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender;

  Map<String, dynamic> toJson() => {
        'fullName': fullName.trim(),
        'dateOfBirth': dateOfBirth == null ? null : _dateOnly(dateOfBirth!),
        'gender': gender,
      };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
