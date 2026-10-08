import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import 'profile_models.dart';

/// `/api/me/profile`.
class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<FarmerProfile> profile() => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/profile');
        return FarmerProfile.fromJson(response.data ?? const {});
      });

  Future<FarmerProfile> update(ProfileUpdate update) => guardApi(() async {
        final response = await _dio.put<Map<String, dynamic>>('/api/me/profile', data: update.toJson());
        return FarmerProfile.fromJson(response.data ?? const {});
      });
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(ref.watch(dioProvider)));
