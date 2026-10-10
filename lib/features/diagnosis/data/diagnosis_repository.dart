import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/paged.dart';
import 'diagnosis_models.dart';
import 'diagnosis_photo.dart';

/// `/api/me/diagnosis-cases`. The server shows a farmer only their own cases and only the verified result.
class DiagnosisRepository {
  DiagnosisRepository(this._dio);

  final Dio _dio;

  /// Sends the photo. The server stores it, runs the AI and answers with the case: waiting for a reviewer in every
  /// case (the AI result is never shown). The AI call can take a few seconds, so this waits longer than other calls.
  /// Never retried automatically: a request that timed out may still have created the case.
  Future<DiagnosisCase> create(DiagnosisPhotoFile photo, {String? note}) => guardApi(() async {
        final text = note?.trim();
        final form = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            photo.path,
            filename: 'leaf.${photo.type.extension}',
            contentType: DioMediaType.parse(photo.type.mimeType),
          ),
          if (text != null && text.isNotEmpty) 'note': text,
        });
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/me/diagnosis-cases',
          data: form,
          options: Options(sendTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)),
        );
        return DiagnosisCase.fromJson(response.data ?? const {});
      });

  /// The farmer's cases, newest first.
  Future<Paged<DiagnosisCaseListItem>> list({String? status, int page = 1, int pageSize = 20}) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/api/me/diagnosis-cases',
          queryParameters: {
            if (status != null && status.isNotEmpty) 'status': status,
            'page': page,
            'pageSize': pageSize,
          },
        );
        return Paged.fromJson(response.data ?? const {}, DiagnosisCaseListItem.fromJson);
      });

  Future<DiagnosisCase> get(String id) => guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/diagnosis-cases/$id');
        return DiagnosisCase.fromJson(response.data ?? const {});
      });

  /// Withdraws a case that has not been decided yet.
  Future<DiagnosisCase> cancel(String id, {String? reason}) => guardApi(() async {
        final text = reason?.trim();
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/me/diagnosis-cases/$id/cancel',
          data: {'reason': (text == null || text.isEmpty) ? null : text},
        );
        return DiagnosisCase.fromJson(response.data ?? const {});
      });
}

final diagnosisRepositoryProvider = Provider<DiagnosisRepository>((ref) => DiagnosisRepository(ref.watch(dioProvider)));
