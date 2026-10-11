import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/api_exception.dart';
import 'package:farmer_mobile/core/network/auth_interceptor.dart';
import 'package:farmer_mobile/core/network/dio_client.dart';
import 'package:farmer_mobile/core/network/paged_result.dart';
import 'package:farmer_mobile/core/network/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';

/// JWT giả chỉ có payload `exp` (giây epoch), đủ cho `AuthInterceptor.jwtExpiry`.
String fakeJwt(DateTime exp) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'none'})}.'
      '${enc({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  group('AuthInterceptor', () {
    late MemoryTokenStorage storage;
    late int expiredCalls;

    Dio build(FakeAdapter adapter, {DateTime Function()? now}) => createApiDio(
          baseUrl: 'http://test',
          storage: storage,
          onSessionExpired: () async => expiredCalls++,
          adapter: adapter,
          now: now,
        );

    ResponseBody refreshOk() => jsonBody(200, {
          'accessToken': 'new',
          'refreshToken': 'r2',
          'sessionId': 's1',
        });

    setUp(() {
      storage = MemoryTokenStorage(
        const AuthTokens(accessToken: 'old', refreshToken: 'r1'),
      );
      expiredCalls = 0;
    });

    test('gắn Bearer token cho route cần đăng nhập, không gắn cho catalog',
        () async {
      final adapter = FakeAdapter((o) => jsonBody(200, {'ok': true}));
      final dio = build(adapter);

      await dio.get<dynamic>('/api/me/profile');
      await dio.get<dynamic>('/api/catalog/products');

      expect(adapter.requests[0].headers['Authorization'], 'Bearer old');
      expect(adapter.requests[1].headers.containsKey('Authorization'), isFalse);
    });

    test('401 thì refresh một lần rồi gọi lại bằng token mới', () async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/api/auth/refresh') {
          expect(o.data, {'refreshToken': 'r1'});
          return refreshOk();
        }
        return o.headers['Authorization'] == 'Bearer new'
            ? jsonBody(200, {'ok': true})
            : jsonBody(401, {'title': 'x'});
      });
      final dio = build(adapter);

      final res = await dio.get<dynamic>('/api/me/profile');

      expect(res.statusCode, 200);
      expect(storage.tokens?.accessToken, 'new');
      expect(storage.tokens?.refreshToken, 'r2');
      expect(expiredCalls, 0);
    });

    test('nhiều request 401 cùng lúc chỉ refresh một lần', () async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/api/auth/refresh') return refreshOk();
        return o.headers['Authorization'] == 'Bearer new'
            ? jsonBody(200, {'ok': true})
            : jsonBody(401, {'title': 'x'});
      });
      final dio = build(adapter);

      await Future.wait([
        dio.get<dynamic>('/api/me/orders'),
        dio.get<dynamic>('/api/me/cart'),
        dio.get<dynamic>('/api/me/debt'),
      ]);

      final refreshes =
          adapter.requests.where((r) => r.path == '/api/auth/refresh').length;
      expect(refreshes, 1);
      expect(storage.tokens?.accessToken, 'new');
    });

    test('refresh bị từ chối thì xoá token và báo hết phiên', () async {
      final adapter = FakeAdapter((o) => jsonBody(401, {'title': 'x'}));
      final dio = build(adapter);

      await expectLater(
        dio.get<dynamic>('/api/me/profile'),
        throwsA(isA<DioException>()),
      );

      expect(storage.tokens, isNull);
      expect(expiredCalls, 1);
    });

    test('server lỗi khi refresh thì giữ token, không đăng xuất', () async {
      final adapter = FakeAdapter((o) {
        if (o.path == '/api/auth/refresh') return jsonBody(503, {'title': 'x'});
        return jsonBody(401, {'title': 'x'});
      });
      final dio = build(adapter);

      await expectLater(
        dio.get<dynamic>('/api/me/profile'),
        throwsA(isA<DioException>()),
      );

      expect(storage.tokens?.refreshToken, 'r1');
      expect(expiredCalls, 0);
    });

    test('401 ở login (sai mật khẩu) không kích hoạt refresh', () async {
      final adapter = FakeAdapter((o) => jsonBody(401, {'title': 'x'}));
      final dio = build(adapter);

      await expectLater(
        dio.post<dynamic>('/api/auth/login', data: {}),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests.length, 1);
      expect(expiredCalls, 0);
    });

    test('401 ở đổi mật khẩu (sai mật khẩu hiện tại) không refresh, không đăng xuất',
        () async {
      final adapter = FakeAdapter((o) => jsonBody(401, {'title': 'x'}));
      final dio = build(adapter);

      await expectLater(
        dio.post<dynamic>('/api/auth/change-password', data: {}),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests.length, 1);
      expect(storage.tokens?.accessToken, 'old');
      expect(expiredCalls, 0);
    });

    test('access token sắp hết hạn thì refresh trước khi gửi request',
        () async {
      final now = DateTime(2026, 10, 12, 10);
      storage.tokens = AuthTokens(
        accessToken: fakeJwt(now.add(const Duration(seconds: 10))),
        refreshToken: 'r1',
      );
      final adapter = FakeAdapter((o) {
        if (o.path == '/api/auth/refresh') return refreshOk();
        return jsonBody(200, {'ok': true});
      });
      final dio = build(adapter, now: () => now);

      await dio.get<dynamic>('/api/me/profile');

      expect(adapter.requests.map((r) => r.path),
          ['/api/auth/refresh', '/api/me/profile']);
      expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
    });

    test('đổi mật khẩu với token đã hết hạn: refresh trước, rồi mới gửi',
        () async {
      final now = DateTime(2026, 10, 12, 10);
      storage.tokens = AuthTokens(
        accessToken: fakeJwt(now.subtract(const Duration(minutes: 5))),
        refreshToken: 'r1',
      );
      final adapter = FakeAdapter((o) {
        if (o.path == '/api/auth/refresh') return refreshOk();
        return emptyBody(204);
      });
      final dio = build(adapter, now: () => now);

      final res = await dio.post<dynamic>('/api/auth/change-password',
          data: {'currentPassword': 'a', 'newPassword': 'b'});

      expect(res.statusCode, 204);
      expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
    });

    test('token còn hạn thì không refresh', () async {
      final now = DateTime(2026, 10, 12, 10);
      storage.tokens = AuthTokens(
        accessToken: fakeJwt(now.add(const Duration(minutes: 30))),
        refreshToken: 'r1',
      );
      final adapter = FakeAdapter((o) => jsonBody(200, {'ok': true}));
      final dio = build(adapter, now: () => now);

      await dio.get<dynamic>('/api/me/profile');

      expect(adapter.requests.length, 1);
    });

    test('Authorization do nơi gọi chỉ định không bị ghi đè bằng token đang lưu',
        () async {
      final adapter = FakeAdapter((o) => jsonBody(200, {'ok': true}));
      final dio = build(adapter);

      await dio.post<dynamic>('/api/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer vua-dang-nhap'}));

      expect(adapter.requests.single.headers['Authorization'],
          'Bearer vua-dang-nhap');
      expect(storage.tokens?.accessToken, 'old');
    });

    test('token tường minh bị 401 thì KHÔNG refresh phiên đang lưu', () async {
      final adapter = FakeAdapter((o) => jsonBody(401, {'title': 'x'}));
      final dio = build(adapter);

      await expectLater(
        dio.get<dynamic>('/api/auth/me',
            options: Options(headers: {'Authorization': 'Bearer khac'})),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests.length, 1);
      expect(storage.tokens?.accessToken, 'old');
      expect(expiredCalls, 0);
    });

    test('jwtExpiry đọc được exp, trả null với token không phải JWT', () {
      final exp = DateTime.utc(2026, 10, 12, 10);
      expect(AuthInterceptor.jwtExpiry(fakeJwt(exp))?.toUtc(), exp);
      expect(AuthInterceptor.jwtExpiry('abc'), isNull);
      expect(AuthInterceptor.jwtExpiry('a.b.c'), isNull);
    });
  });

  group('TokenStorage', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('persist=true ghi xuống storage, bản mới đọc lại được', () async {
      await TokenStorage().save(
        const AuthTokens(accessToken: 'a', refreshToken: 'r', sessionId: 's'),
        persist: true,
      );

      final fresh = await TokenStorage().read();
      expect(fresh?.accessToken, 'a');
      expect(fresh?.refreshToken, 'r');
      expect(fresh?.sessionId, 's');
    });

    test('persist=false chỉ giữ trong RAM, khởi động lại là mất', () async {
      final storage = TokenStorage();
      await storage.save(
        const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        persist: false,
      );

      expect((await storage.read())?.accessToken, 'a');
      expect(await TokenStorage().read(), isNull);
    });

    test('refresh sau đó giữ nguyên chế độ không ghi nhớ', () async {
      final storage = TokenStorage();
      await storage.save(
        const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        persist: false,
      );
      await storage.save(const AuthTokens(accessToken: 'b', refreshToken: 'r2'));

      expect((await storage.read())?.accessToken, 'b');
      expect(await TokenStorage().read(), isNull);
    });

    test('đăng nhập "ghi nhớ" sau lần không ghi nhớ thì ghi lại', () async {
      final storage = TokenStorage();
      await storage.save(
        const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        persist: false,
      );
      await storage.save(
        const AuthTokens(accessToken: 'b', refreshToken: 'r2'),
        persist: true,
      );

      expect((await TokenStorage().read())?.refreshToken, 'r2');
    });

    test('clear xoá cả cache lẫn storage', () async {
      final storage = TokenStorage();
      await storage.save(
        const AuthTokens(accessToken: 'a', refreshToken: 'r'),
        persist: true,
      );
      await storage.clear();

      expect(await storage.read(), isNull);
      expect(await TokenStorage().read(), isNull);
    });
  });

  group('ApiException.from', () {
    DioException badResponse(int status, Object? body) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: status,
            data: body,
          ),
        );

    test('422 lấy detail, errors theo dòng và traceId', () {
      final e = ApiException.from(badResponse(422, {
        'status': 422,
        'title': 'Business rule violated.',
        'detail': 'Giỏ hàng trống',
        'errors': {
          'items[0]': ['Không còn bán']
        },
        'traceId': 'abc',
      }));
      expect(e.kind, ApiErrorKind.businessRule);
      expect(e.message, 'Giỏ hàng trống');
      expect(e.fieldErrors['items[0]'], ['Không còn bán']);
      expect(e.traceId, 'abc');
    });

    test('400 validation: thông báo tiếng Việt, không lộ title tiếng Anh', () {
      final e = ApiException.from(badResponse(400, {
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'Password': ['too short']
        },
      }));
      expect(e.kind, ApiErrorKind.validation);
      expect(e.message, 'Dữ liệu không hợp lệ.');
      expect(e.fieldErrors['Password'], ['too short']);
    });

    test('401/403/404/503/500 dùng thông báo tiếng Việt, không lộ detail', () {
      expect(ApiException.from(badResponse(401, {'detail': 'Invalid'})).kind,
          ApiErrorKind.unauthorized);
      expect(ApiException.from(badResponse(403, null)).kind,
          ApiErrorKind.forbidden);
      expect(ApiException.from(badResponse(404, null)).kind,
          ApiErrorKind.notFound);
      expect(ApiException.from(badResponse(503, {'detail': 'payOS down'})).kind,
          ApiErrorKind.unavailable);
      final server = ApiException.from(badResponse(500, {'detail': 'boom'}));
      expect(server.kind, ApiErrorKind.server);
      expect(server.message, isNot(contains('boom')));
    });

    test('lỗi mạng và timeout', () {
      DioException of(DioExceptionType t) =>
          DioException(requestOptions: RequestOptions(path: '/x'), type: t);
      expect(ApiException.from(of(DioExceptionType.connectionError)).kind,
          ApiErrorKind.network);
      expect(ApiException.from(of(DioExceptionType.receiveTimeout)).kind,
          ApiErrorKind.timeout);
      expect(ApiException.from(of(DioExceptionType.transformTimeout)).kind,
          ApiErrorKind.timeout);
      expect(
          ApiException.from(of(DioExceptionType.connectionError)).isConnectivity,
          isTrue);
    });

    test('withMessage giữ nguyên loại lỗi', () {
      final e = ApiException.from(badResponse(401, null)).withMessage('Sai mật khẩu');
      expect(e.kind, ApiErrorKind.unauthorized);
      expect(e.message, 'Sai mật khẩu');
      expect(e.statusCode, 401);
    });
  });

  test('PagedResult.fromJson', () {
    final page = PagedResult<int>.fromJson(
      {
        'items': [
          {'v': 1},
          {'v': 2}
        ],
        'page': 1,
        'pageSize': 2,
        'totalCount': 5,
        'totalPages': 3,
      },
      (j) => j['v'] as int,
    );
    expect(page.items, [1, 2]);
    expect(page.hasMore, isTrue);
  });
}
