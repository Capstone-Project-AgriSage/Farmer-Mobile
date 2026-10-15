/// Loại ảnh backend nhận cho chẩn đoán (JPEG, PNG, WebP).
enum PhotoType {
  jpeg('image/jpeg'),
  png('image/png'),
  webp('image/webp');

  const PhotoType(this.mimeType);

  final String mimeType;
}

/// Loại ảnh THẬT của một file, đọc từ vài byte đầu (tên file hoặc header do điện thoại gửi có thể sai).
/// null với mọi thứ khác. (Logic của nhánh feature/mobile-diagnosis.)
PhotoType? detectPhotoType(List<int> head) {
  bool starts(List<int> signature, {int at = 0}) {
    if (head.length < at + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (head[at + i] != signature[i]) return false;
    }
    return true;
  }

  if (starts([0xFF, 0xD8, 0xFF])) return PhotoType.jpeg;
  if (starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return PhotoType.png;
  // WebP: "RIFF" + 4 byte kích thước + "WEBP".
  if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], at: 8)) {
    return PhotoType.webp;
  }
  return null;
}
