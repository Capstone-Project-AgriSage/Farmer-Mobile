import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/address.dart';

class CustomerGroupRef {
  const CustomerGroupRef({required this.code, required this.name});

  final String code;
  final String name;
}

/// Hồ sơ nông dân (`GET /api/me/profile`). Số điện thoại và email thuộc tài
/// khoản nên chỉ đọc.
class FarmerProfile {
  const FarmerProfile({
    required this.fullName,
    this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.customerGroup,
  });

  final String fullName;
  final String? phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;

  /// `MALE` | `FEMALE` | `OTHER` | null.
  final String? gender;
  final CustomerGroupRef? customerGroup;

  factory FarmerProfile.fromJson(Map<String, dynamic> json) {
    final group = json['customerGroup'] as Map<String, dynamic>?;
    final dob = json['dateOfBirth'] as String?;
    return FarmerProfile(
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      // "yyyy-MM-dd" (DateOnly): giữ ngày, không đổi múi giờ.
      dateOfBirth: dob == null ? null : DateTime.parse(dob),
      gender: json['gender'] as String?,
      customerGroup: group == null
          ? null
          : CustomerGroupRef(
              code: group['code'] as String? ?? '',
              name: group['name'] as String? ?? '',
            ),
    );
  }
}

abstract class Genders {
  static const male = 'MALE';
  static const female = 'FEMALE';
  static const other = 'OTHER';
  static const all = [male, female, other];

  static String label(String g) => switch (g) {
        male => 'Nam',
        female => 'Nữ',
        _ => 'Khác',
      };
}

/// Gọi `/api/me/profile` và `/api/me/addresses`.
class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  /// Backend cho tối đa 10 địa chỉ.
  static const maxAddresses = 10;

  Future<T> _run<T>(Future<T> Function() call,
      {Map<int, String> messages = const {}}) async {
    try {
      return await call();
    } on DioException catch (e) {
      final error = ApiException.from(e);
      final override = messages[error.statusCode];
      throw override == null ? error : error.withMessage(override);
    }
  }

  Future<FarmerProfile> getProfile() => _run(() async {
        final res = await _dio.get<Map<String, dynamic>>('/api/me/profile');
        return FarmerProfile.fromJson(res.data!);
      });

  Future<FarmerProfile> updateProfile({
    required String fullName,
    DateTime? dateOfBirth,
    String? gender,
  }) =>
      _run(() async {
        final res = await _dio.put<Map<String, dynamic>>(
          '/api/me/profile',
          data: {
            'fullName': fullName.trim(),
            'dateOfBirth': dateOfBirth == null ? null : _dateOnly(dateOfBirth),
            'gender': gender,
          },
        );
        return FarmerProfile.fromJson(res.data!);
      });

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Địa chỉ mặc định đứng đầu danh sách.
  Future<List<Address>> listAddresses() => _run(() async {
        final res = await _dio.get<List<dynamic>>('/api/me/addresses');
        return [
          for (final a in res.data!) Address.fromJson(a as Map<String, dynamic>),
        ];
      });

  Future<Address> createAddress(AddressInput input) => _run(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/addresses',
            data: input.toJson(),
          );
          return Address.fromJson(res.data!);
        },
        messages: {
          422: 'Bạn chỉ lưu được tối đa $maxAddresses địa chỉ. Hãy xoá bớt địa chỉ cũ.',
        },
      );

  Future<Address> updateAddress(String id, AddressInput input) => _run(
        () async {
          final res = await _dio.put<Map<String, dynamic>>(
            '/api/me/addresses/$id',
            data: input.toJson(),
          );
          return Address.fromJson(res.data!);
        },
        messages: {404: 'Địa chỉ này không còn tồn tại.'},
      );

  Future<void> deleteAddress(String id) => _run(
        () => _dio.delete<void>('/api/me/addresses/$id'),
        messages: {404: 'Địa chỉ này không còn tồn tại.'},
      );

  Future<Address> setDefaultAddress(String id) => _run(
        () async {
          final res = await _dio
              .post<Map<String, dynamic>>('/api/me/addresses/$id/set-default');
          return Address.fromJson(res.data!);
        },
        messages: {404: 'Địa chỉ này không còn tồn tại.'},
      );
}

final profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(dioProvider)));
