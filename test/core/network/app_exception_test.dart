import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _bad(int status, Object? body) {
  final request = RequestOptions(path: '/api/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  group('AppException.fromDio', () {
    test('translates a known business rule (422) and keeps the status', () {
      final e = AppException.fromDio(_bad(422, {
        'title': 'Business rule violated.',
        'detail': 'The cart is empty.',
        'traceId': 'abc',
      }));
      expect(e.kind, AppErrorKind.businessRule);
      expect(e.statusCode, 422);
      expect(e.message, 'Giỏ hàng đang trống.');
      expect(e.traceId, 'abc');
    });

    test('an unknown English detail falls back to a Vietnamese sentence for the status', () {
      final e = AppException.fromDio(_bad(422, {'detail': 'Something nobody translated.'}));
      expect(e.message, 'Không thực hiện được thao tác này ở trạng thái hiện tại.');
    });

    test('a 400 reads the field errors, lower-cases the key and translates the text', () {
      final e = AppException.fromDio(_bad(400, {
        'title': 'One or more validation errors occurred.',
        'errors': {
          'Password': ["The length of 'Password' must be at least 8 characters. You entered 5 characters."],
          'FullName': ["'Full Name' must not be empty."],
        },
      }));
      expect(e.kind, AppErrorKind.validation);
      expect(e.fieldError('password'), 'Mật khẩu phải có ít nhất 8 ký tự.');
      expect(e.fieldError('fullName'), 'Họ tên không được để trống.');
      expect(e.message, 'Mật khẩu phải có ít nhất 8 ký tự.'); // the first one is the headline
    });

    test('maps the other statuses to their kind', () {
      expect(AppException.fromDio(_bad(401, {'detail': 'Invalid phone number, email or password.'})).message,
          'Số điện thoại/email hoặc mật khẩu chưa đúng.');
      expect(AppException.fromDio(_bad(403, {'detail': 'This account is not active.'})).kind, AppErrorKind.forbidden);
      expect(AppException.fromDio(_bad(404, {'detail': "Order 'x' was not found."})).message,
          'Không tìm thấy đơn hàng.');
      expect(AppException.fromDio(_bad(409, {'detail': 'Another order was created at the same time; try again.'})).kind,
          AppErrorKind.conflict);
      expect(AppException.fromDio(_bad(500, {'detail': 'An unexpected error occurred.'})).kind, AppErrorKind.server);
    });

    test('429 says "too many attempts" even when the body is not JSON', () {
      final e = AppException.fromDio(_bad(429, 'Too Many Requests'));
      expect(e.kind, AppErrorKind.rateLimited);
      expect(e.message, 'Bạn thao tác quá nhiều. Vui lòng thử lại sau 1 phút.');
    });

    test('timeouts and connection errors are retryable; a timeout leaves the outcome unknown', () {
      final request = RequestOptions(path: '/x');
      final timeout = AppException.fromDio(DioException(requestOptions: request, type: DioExceptionType.receiveTimeout));
      final offline = AppException.fromDio(DioException(requestOptions: request, type: DioExceptionType.connectionError));
      expect(timeout.isRetryable, isTrue);
      expect(timeout.outcomeUnknown, isTrue);
      expect(offline.kind, AppErrorKind.offline);
      expect(offline.outcomeUnknown, isFalse);
    });

    test('an AppException already attached by the interceptor is returned as is', () {
      const attached = AppException.sessionExpired();
      final e = AppException.fromDio(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.cancel,
        error: attached,
      ));
      expect(identical(e, attached), isTrue);
    });
  });

  test('guardApi rethrows a DioException as AppException', () async {
    await expectLater(
      guardApi<void>(() async => throw _bad(404, {'detail': "Payment 'p' was not found."})),
      throwsA(isA<AppException>().having((e) => e.message, 'message', 'Không tìm thấy giao dịch thanh toán.')),
    );
  });
}
