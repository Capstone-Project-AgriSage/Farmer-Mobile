import 'package:farmer_mobile/features/ai_doctor/data/photo_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectPhotoType (đọc loại ảnh từ byte đầu)', () {
    test('JPEG', () {
      expect(detectPhotoType([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]), PhotoType.jpeg);
    });

    test('PNG', () {
      expect(detectPhotoType([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]), PhotoType.png);
    });

    test('WebP: RIFF + 4 byte kích thước + WEBP', () {
      final head = [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x45, 0x42, 0x50];
      expect(detectPhotoType(head), PhotoType.webp);
    });

    test('RIFF nhưng không phải WebP (vd. WAV) bị từ chối', () {
      final head = [0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4, 0x57, 0x41, 0x56, 0x45];
      expect(detectPhotoType(head), isNull);
    });

    test('GIF, PDF, HEIC, văn bản và dữ liệu quá ngắn bị từ chối', () {
      expect(detectPhotoType('GIF89a'.codeUnits), isNull);
      expect(detectPhotoType('%PDF-1.7'.codeUnits), isNull);
      expect(detectPhotoType([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]), isNull);
      expect(detectPhotoType('hello world'.codeUnits), isNull);
      expect(detectPhotoType([0xFF, 0xD8]), isNull);
      expect(detectPhotoType(const []), isNull);
    });

    test('mime type đúng', () {
      expect(PhotoType.jpeg.mimeType, 'image/jpeg');
      expect(PhotoType.png.mimeType, 'image/png');
      expect(PhotoType.webp.mimeType, 'image/webp');
    });
  });
}
