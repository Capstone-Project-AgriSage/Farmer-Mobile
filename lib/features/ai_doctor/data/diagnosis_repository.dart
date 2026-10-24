import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/json_utils.dart';
import '../../../core/network/paged_result.dart';
import 'diagnosis_models.dart';
import 'photo_type.dart';

/// Ảnh người dùng đã chọn (chưa gửi).
class PickedPhoto {
  const PickedPhoto({
    required this.path,
    required this.name,
    required this.sizeBytes,
    this.type,
    this.typeChecked = false,
  });

  final String path;
  final String name;
  final int sizeBytes;

  /// Loại ảnh THẬT đọc từ byte đầu của file; null nếu chưa kiểm (khi đó dựa vào đuôi file).
  final PhotoType? type;

  /// true khi đã đọc byte đầu của file (khi đó `type == null` nghĩa là KHÔNG phải ảnh JPEG/PNG/WebP).
  final bool typeChecked;
}

enum PhotoSource { camera, gallery }

/// Chọn ảnh từ camera/thư viện. Tách thành interface để test không cần plugin.
abstract class PhotoPicker {
  /// null = người dùng bỏ qua. Ném [PhotoPickerException] nếu không truy cập được.
  Future<PickedPhoto?> pick(PhotoSource source);

  /// Ảnh vừa chụp nhưng Android đã đóng app để lấy lại bộ nhớ trước khi trả về (camera hay làm vậy trên
  /// máy ít RAM). null nếu không có.
  Future<PickedPhoto?> recoverLost() async => null;
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
    final XFile? file;
    try {
      // Camera là app của hệ thống nên KHÔNG khai báo quyền CAMERA (khai báo sẽ buộc hỏi quyền lúc chạy).
      file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        // Thu nhỏ để upload nhanh và không vượt 5 MB; vẫn đủ nét để nhận biết bệnh.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      throw PhotoPickerException(source == PhotoSource.camera
          ? 'Không mở được camera. Vui lòng thử lại.'
          : 'Không mở được thư viện ảnh. Vui lòng thử lại.');
    }
    return file == null ? null : _describe(file);
  }

  @override
  Future<PickedPhoto?> recoverLost() async {
    try {
      final lost = await _picker.retrieveLostData();
      final file = lost.file;
      if (lost.isEmpty || file == null) return null;
      return await _describe(file);
    } catch (_) {
      return null;
    }
  }

  /// Đọc kích thước và LOẠI THẬT của ảnh (từ byte đầu), không tin tên file.
  Future<PickedPhoto> _describe(XFile file) async {
    final head = <int>[];
    await for (final chunk in file.openRead(0, 12)) {
      head.addAll(chunk);
    }
    return PickedPhoto(
      path: file.path,
      name: file.name,
      sizeBytes: await file.length(),
      type: detectPhotoType(head),
      typeChecked: true,
    );
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
    // Đã đọc byte đầu thì loại THẬT quyết định (đuôi file có thể sai); chưa đọc thì dựa vào đuôi file.
    final known = p.typeChecked ? p.type != null : _contentType(p.name) != null;
    if (!known) {
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

  /// Gửi ảnh. Server lưu ảnh, chạy AI rồi trả ca đã có kết quả (AI_COMPLETED) hoặc FAILED (thử lại sau).
  /// Có thể mất vài giây nên dùng timeout dài.
  Future<DiagnosisCase> create({required PickedPhoto photo, String? note}) => apiCall(
        () async {
          final type = photo.type?.mimeType ?? _contentType(photo.name)!;
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

  /// AI phân tích lại ảnh của một ca chưa phân tích được.
  Future<DiagnosisCase> retry(String id) => apiCall(
        () async {
          final res = await _dio.post<Map<String, dynamic>>(
            '/api/me/diagnosis-cases/$id/retry',
            options: Options(
              sendTimeout: AppConfig.uploadTimeout,
              receiveTimeout: AppConfig.uploadTimeout,
            ),
          );
          return DiagnosisCase.fromJson(res.data!);
        },
        messages: {
          404: 'Không tìm thấy ca chẩn đoán.',
          422: 'Ca này đã có kết quả hoặc đã huỷ nên không cần phân tích lại.',
          429: 'Bạn thử lại quá nhanh. Vui lòng đợi một chút.',
          503: 'Dịch vụ AI đang bận. Bạn hãy thử lại sau ít phút.',
        },
      );

  /// Huỷ khi ca chưa có kết quả.
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
          422: 'Ca đã có kết quả hoặc đã huỷ nên không thể huỷ nữa.',
        },
      );
}

final diagnosisRepositoryProvider = Provider<DiagnosisRepository>(
    (ref) => DiagnosisRepository(ref.watch(dioProvider)));

final photoPickerProvider =
    Provider<PhotoPicker>((ref) => ImagePickerPhotoPicker());
