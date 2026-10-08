import 'package:dio/dio.dart';
import 'package:farmer_mobile/core/network/app_exception.dart';
import 'package:farmer_mobile/core/network/auth_interceptor.dart';
import 'package:farmer_mobile/core/session/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../support/fakes.dart';

const _user = SessionUser(id: 'u1', fullName: 'Hải', role: 'FARMER');

void main() {
  final now = DateTime.utc(2026, 10, 8, 3);
  late FakeClock clock;
  late InMemoryTokenStore store;
  late SessionManager session;
  late Dio dio;
  late DioAdapter adapter;
  late List<RequestOptions> sent;

  setUp(() async {
    clock = FakeClock(now);
    store = InMemoryTokenStore();
    session = SessionManager(store: store, clock: clock.call);
    await session.signIn(accessToken: 'tok-123', expiresAt: now.add(const Duration(hours: 5)), user: _user);

    dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
    adapter = DioAdapter(dio: dio);
    sent = [];
    dio.interceptors
      ..add(AuthInterceptor(session: session))
      ..add(InterceptorsWrapper(onRequest: (options, handler) {
        sent.add(options);
        handler.next(options);
      }));
  });

  Future<AppException> failure(Future<Object?> Function() call) async {
    try {
      await call();
    } on DioException catch (e) {
      return AppException.fromDio(e);
    }
    fail('the call should have failed');
  }

  test('sends the Bearer token on a protected call', () async {
    adapter.onGet('/api/me/cart', (server) => server.reply(200, {'items': []}));
    await dio.get<Object?>('/api/me/cart');
    expect(sent.single.headers['Authorization'], 'Bearer tok-123');
  });

  test('sends no token on login and register', () async {
    adapter.onPost('/api/auth/login', (server) => server.reply(200, {}), data: Matchers.any);
    await dio.post<Object?>('/api/auth/login', data: {'identifier': 'a', 'password': 'b'});
    expect(sent.single.headers.containsKey('Authorization'), isFalse);
  });

  test('an expired token ends the session without calling the server', () async {
    clock.now = now.add(const Duration(hours: 5));
    adapter.onGet('/api/me/cart', (server) => server.reply(200, {}));

    final error = await failure(() => dio.get<Object?>('/api/me/cart'));

    expect(error.kind, AppErrorKind.sessionExpired);
    expect(sent, isEmpty);
    expect(session.status, SessionStatus.signedOut);
  });

  test('a 401 on a normal call ends the session', () async {
    adapter.onGet('/api/me/orders', (server) => server.reply(401, {'detail': 'Authentication is required.'}));

    final error = await failure(() => dio.get<Object?>('/api/me/orders'));

    expect(error.kind, AppErrorKind.sessionExpired);
    expect(session.status, SessionStatus.signedOut);
    expect(store.stored, isNull);
  });

  test('a wrong current password (401 on change-password) does NOT sign the user out', () async {
    adapter.onPost(
      '/api/auth/change-password',
      (server) => server.reply(401, {'detail': 'The current password is incorrect.'}),
      data: Matchers.any,
    );

    final error = await failure(
      () => dio.post<Object?>('/api/auth/change-password', data: {'currentPassword': 'x', 'newPassword': 'y'}),
    );

    expect(session.status, SessionStatus.signedIn);
    expect(error.kind, AppErrorKind.unauthorized);
    expect(error.message, 'Mật khẩu hiện tại chưa đúng.');
  });

  test('a failed login (401) keeps its own message and does not touch the session', () async {
    adapter.onPost(
      '/api/auth/login',
      (server) => server.reply(401, {'detail': 'Invalid phone number, email or password.'}),
      data: Matchers.any,
    );

    final error = await failure(() => dio.post<Object?>('/api/auth/login', data: {'identifier': 'a', 'password': 'b'}));

    expect(error.message, 'Số điện thoại/email hoặc mật khẩu chưa đúng.');
    expect(session.status, SessionStatus.signedIn);
  });

  test('a 403 only reports the error', () async {
    adapter.onGet('/api/me/credit', (server) => server.reply(403, {'detail': 'This account has no customer profile.'}));

    final error = await failure(() => dio.get<Object?>('/api/me/credit'));

    expect(error.kind, AppErrorKind.forbidden);
    expect(session.status, SessionStatus.signedIn);
  });

  test('a 429 says to wait a minute', () async {
    adapter.onPost('/api/auth/login', (server) => server.reply(429, {'detail': 'Too many attempts. Try again later.'}),
        data: Matchers.any);

    final error = await failure(() => dio.post<Object?>('/api/auth/login', data: {'identifier': 'a', 'password': 'b'}));

    expect(error.kind, AppErrorKind.rateLimited);
    expect(error.message, 'Bạn thao tác quá nhiều. Vui lòng thử lại sau 1 phút.');
  });
}
