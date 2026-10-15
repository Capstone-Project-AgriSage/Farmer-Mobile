import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_call.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

DioException httpError(int status, [Object? body]) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: status, data: body),
  );
}

void main() {
  group('apiCall', () {
    test('thành công: trả nguyên kết quả', () async {
      expect(await apiCall(() async => 42), 42);
    });

    test('ApiException có sẵn: giữ nguyên, không bọc lại', () async {
      const e = ApiException(kind: ApiErrorKind.conflict, statusCode: 409, message: 'x');
      await expectLater(apiCall<int>(() async => throw e), throwsA(same(e)));
    });

    test('lỗi HTTP: chuyển thành ApiException tiếng Việt theo mã', () async {
      await expectLater(
        apiCall<int>(() async => throw httpError(404, {'status': 404})),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });

    test('messages: đổi thông báo theo mã HTTP, giữ loại lỗi', () async {
      await expectLater(
        apiCall<int>(() async => throw httpError(404), messages: {404: 'Không thấy.'}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Không thấy.')
            .having((e) => e.kind, 'kind', ApiErrorKind.notFound)),
      );
    });

    test('map: thông báo theo nội dung detail được ưu tiên hơn messages', () async {
      await expectLater(
        apiCall<int>(
          () async => throw httpError(422, {'status': 422, 'detail': 'owes 0'}),
          messages: {422: 'chung'},
          map: (e) => (e.detail ?? '').contains('owes') ? e.withMessage('cụ thể') : e,
        ),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'cụ thể')),
      );
    });

    test('map trả lại lỗi cũ: vẫn áp dụng messages', () async {
      await expectLater(
        apiCall<int>(() async => throw httpError(503),
            messages: {503: 'gián đoạn'}, map: (e) => e),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'gián đoạn')),
      );
    });

    test('lỗi lạ (dữ liệu sai dạng, TypeError, FormatException) → ApiException chung, không lộ chi tiết kỹ thuật',
        () async {
      for (final boom in <Object>[
        const FormatException('Unexpected character'),
        StateError('boom'),
        TypeError(),
      ]) {
        await expectLater(
          apiCall<int>(() async => throw boom),
          throwsA(isA<ApiException>().having(
              (e) => e.message, 'message', allOf(isNotEmpty, isNot(contains('Unexpected'))))),
          reason: '$boom',
        );
      }
    });

    test('mất mạng (không có response) → lỗi kết nối', () async {
      final req = RequestOptions(path: '/x');
      await expectLater(
        apiCall<int>(() async =>
            throw DioException(requestOptions: req, type: DioExceptionType.connectionError)),
        throwsA(isA<ApiException>().having((e) => e.isConnectivity, 'isConnectivity', isTrue)),
      );
    });
  });
}
