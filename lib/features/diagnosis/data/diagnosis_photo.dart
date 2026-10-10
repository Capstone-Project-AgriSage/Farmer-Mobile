import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// The server takes diagnosis photos up to 5 MB, as JPEG, PNG or WebP (AI_DIAGNOSIS.md section 6).
const maxDiagnosisPhotoBytes = 5 * 1024 * 1024;

/// The longest side of a photo, in pixels. A phone camera gives 4000+; the AI looks at a 224-pixel crop, so 1600 keeps
/// the lesions legible and the upload small on a field connection.
const diagnosisPhotoMaxEdge = 1600.0;
const diagnosisPhotoQuality = 85;

enum DiagnosisImageType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const DiagnosisImageType(this.mimeType, this.extension);

  final String mimeType;
  final String extension;
}

/// What a file really is, from its first bytes (a name or a header sent by a phone can be wrong). Null for anything else.
DiagnosisImageType? detectDiagnosisImageType(List<int> head) {
  bool starts(List<int> signature, {int at = 0}) {
    if (head.length < at + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (head[at + i] != signature[i]) return false;
    }
    return true;
  }

  if (starts([0xFF, 0xD8, 0xFF])) return DiagnosisImageType.jpeg;
  if (starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return DiagnosisImageType.png;
  // WebP: "RIFF" + four size bytes + "WEBP".
  if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], at: 8)) return DiagnosisImageType.webp;
  return null;
}

/// A photo ready to upload.
class DiagnosisPhotoFile {
  const DiagnosisPhotoFile({required this.path, required this.sizeBytes, required this.type});

  final String path;
  final int sizeBytes;
  final DiagnosisImageType type;
}

/// Why a photo cannot be used, in words for the farmer.
class DiagnosisPhotoException implements Exception {
  const DiagnosisPhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Takes or picks the leaf photo. An interface so the screens can be tested without a camera.
abstract class DiagnosisPhotoService {
  /// Opens the camera or the gallery. Null when the farmer backs out.
  Future<DiagnosisPhotoFile?> pick(ImageSource source);

  /// A photo taken just before Android closed the app to free memory, if there is one.
  Future<DiagnosisPhotoFile?> recoverLostPhoto();
}

class ImagePickerDiagnosisPhotoService implements DiagnosisPhotoService {
  ImagePickerDiagnosisPhotoService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<DiagnosisPhotoFile?> pick(ImageSource source) async {
    try {
      // The camera app is the system's, so no CAMERA permission is declared. The picker shrinks and re-encodes the
      // picture; the checks below are a safety net for a gallery file that is still too large or not an image.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: diagnosisPhotoMaxEdge,
        maxHeight: diagnosisPhotoMaxEdge,
        imageQuality: diagnosisPhotoQuality,
      );
      return file == null ? null : await _check(file);
    } on PlatformException {
      throw DiagnosisPhotoException(
        source == ImageSource.camera ? 'Không mở được camera. Vui lòng thử lại.' : 'Không mở được thư viện ảnh. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<DiagnosisPhotoFile?> recoverLostPhoto() async {
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty || lost.file == null) return null;
      return await _check(lost.file!);
    } on PlatformException {
      return null;
    } on DiagnosisPhotoException {
      return null;
    }
  }

  Future<DiagnosisPhotoFile> _check(XFile file) async {
    final size = await file.length();
    if (size > maxDiagnosisPhotoBytes) {
      throw const DiagnosisPhotoException('Ảnh quá lớn (tối đa 5 MB). Bác vui lòng chụp lại.');
    }
    final head = <int>[];
    await for (final chunk in file.openRead(0, 12)) {
      head.addAll(chunk);
    }
    final type = detectDiagnosisImageType(head);
    if (type == null) throw const DiagnosisPhotoException('Chỉ nhận ảnh JPEG, PNG hoặc WebP.');
    return DiagnosisPhotoFile(path: file.path, sizeBytes: size, type: type);
  }
}

final diagnosisPhotoServiceProvider = Provider<DiagnosisPhotoService>((ref) => ImagePickerDiagnosisPhotoService());
