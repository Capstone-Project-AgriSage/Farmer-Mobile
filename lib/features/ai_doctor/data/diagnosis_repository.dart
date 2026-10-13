import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'diagnosis_models.dart';

/// Ảnh người dùng đã chọn (chưa gửi).
class PickedPhoto {
  const PickedPhoto({required this.path, required this.name, required this.sizeBytes});

  final String path;
  final String name;
  final int sizeBytes;
}

enum PhotoSource { camera, gallery }

/// Chọn ảnh từ camera/thư viện. Tách thành interface để test không cần plugin.
abstract class PhotoPicker {
  /// null = người dùng bỏ qua. Ném [PhotoPickerException] nếu không truy cập được.
  Future<PickedPhoto?> pick(PhotoSource source);
}

class PhotoPickerException implements Exception {
  const PhotoPickerException(this.message);

  final String message;
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        // Thu nhỏ để upload nhanh và không vượt 5 MB; vẫn đủ nét để nhận biết bệnh.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return null;
      return PickedPhoto(path: file.path, name: file.name, sizeBytes: await file.length());
    } catch (_) {
      throw PhotoPickerException(source == PhotoSource.camera
          ? 'Không mở được camera. Hãy cấp quyền camera cho ứng dụng.'
          : 'Không mở được thư viện ảnh. Hãy cấp quyền truy cập ảnh cho ứng dụng.');
    }
  }
}

/// Chẩn đoán bệnh lúa qua ảnh (`/api/me/diagnosis-cases`).
class DiagnosisRepository {
  DiagnosisRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;
  static const maxPhotoBytes = 5 * 1024 * 1024;
  static const maxNoteLength = 1000;
  static const _extensions = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// Kiểm tra ảnh trước khi gửi (đúng luật của backend). null = hợp lệ.
  static String? validatePhoto(PickedPhoto p) {
    if (_contentType(p.name) == null) {
      return 'Chỉ nhận ảnh JPEG, PNG hoặc WebP. Hãy chọn ảnh khác.';
    }
    if (p.sizeBytes > maxPhotoBytes) {
      return 'Ảnh quá lớn (tối đa 5 MB). Hãy chọn ảnh khác hoặc chụp lại.';
    }
    if (p.sizeBytes <= 0) return 'Ảnh bị lỗi. Hãy chọn ảnh khác.';
    return null;
  }

  static String? _contentType(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    return _extensions[name.substring(dot + 1).toLowerCase()];
  }

  /// Gửi ảnh. Server lưu ảnh, chạy AI rồi trả ca đang chờ chuyên gia (không có
  /// kết quả AI). Có thể mất vài giây nên dùng timeout dài.
  Future<DiagnosisCase> create({required PickedPhoto photo, String? note}) => apiCall(
        () async {
          final type = _contentType(photo.name)!;
          final n = note?.trim();
          final form = FormData.fromMap({
            'image': await MultipartFile.fromFile(photo.path,
                filename: photo.name, contentType: DioMediaType.parse(type)),
            if (n != null && n.isNotEmpty) 'note': n,
          });
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/diagnosis-cases',
            data: form,
            options: Options(
              sendTimeout: AppConfig.uploadTimeout,
              receiveTimeout: AppConfig.uploadTimeout,
            ),
          );
          return DiagnosisCase.fromJson(res.data!);
        },
        messages: {
          413: 'Ảnh quá lớn (tối đa 5 MB).',
          429: 'Bạn gửi ảnh quá nhanh. Vui lòng đợi một chút rồi thử lại.',
        },
        map: (e) => e.statusCode == 400
            ? e.withMessage(
                'Ảnh hoặc ghi chú chưa hợp lệ. Chỉ nhận ảnh JPEG, PNG, WebP tối đa 5 MB; ghi chú tối đa $maxNoteLength ký tự.')
            : e,
      );

  Future<PagedResult<DiagnosisSummary>> list(
          {int page = 1, String? status, int size = pageSize}) =>
      apiCall(() async {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/me/diagnosis-cases',
          queryParameters:
              cleanQuery({'page': page, 'pageSize': size, 'status': status}),
        );
        return PagedResult.fromJson(res.data!, DiagnosisSummary.fromJson);
      });

  Future<DiagnosisCase> get(String id) => apiCall(
        () async {
          final res =
              await _dio.get<Map<String, dynamic>>('/api/me/diagnosis-cases/$id');
          return DiagnosisCase.fromJson(res.data!);
        },
        messages: {404: 'Không tìm thấy ca chẩn đoán.'},
      );

  /// Huỷ khi chuyên gia chưa kết luận.
  Future<DiagnosisCase> cancel(String id, {String? reason}) => apiCall(
        () async {
          final r = reason?.trim();
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/diagnosis-cases/$id/cancel',
            data: {if (r != null && r.isNotEmpty) 'reason': r},
          );
          return DiagnosisCase.fromJson(res.data!);
        },
        messages: {
          404: 'Không tìm thấy ca chẩn đoán.',
          422: 'Chuyên gia đã có kết luận hoặc ca đã huỷ nên không thể huỷ nữa.',
        },
      );
}

final diagnosisRepositoryProvider = Provider<DiagnosisRepository>(
    (ref) => DiagnosisRepository(ref.watch(dioProvider)));

final photoPickerProvider =
    Provider<PhotoPicker>((ref) => ImagePickerPhotoPicker());
