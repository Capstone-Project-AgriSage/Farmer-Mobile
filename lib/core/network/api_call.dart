import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Chạy một lời gọi API và chuyển MỌI lỗi thành [ApiException] (thông báo tiếng
/// Việt), để màn hình chỉ cần bắt một loại lỗi và không bao giờ kẹt ở trạng thái
/// "đang tải" vì một ngoại lệ lạ (dữ liệu sai dạng, lỗi đọc file...).
///
/// - [messages]: đổi thông báo theo mã HTTP cho đúng ngữ cảnh của lời gọi.
/// - [map]: đổi lỗi theo nội dung `detail` của backend (thường là tiếng Anh).
Future<T> apiCall<T>(
  Future<T> Function() call, {
  Map<int, String> messages = const {},
  ApiException Function(ApiException e)? map,
}) async {
  try {
    return await call();
  } on ApiException {
    rethrow;
  } on DioException catch (e) {
    final error = ApiException.from(e);
    final mapped = map?.call(error) ?? error;
    final override = messages[mapped.statusCode];
    throw override == null || mapped != error ? mapped : error.withMessage(override);
  } catch (e) {
    throw ApiException.from(e);
  }
}
